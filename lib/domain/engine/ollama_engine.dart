import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../entities/inference_settings.dart';
import '../entities/message.dart' show ChatRole;
import 'inference_engine.dart';

/// Talks to a local (or LAN-reachable) Ollama server over its HTTP API.
class OllamaEngine implements InferenceEngine {
  OllamaEngine(this._dio);

  final Dio _dio;

  String _roleName(ChatRole role) => switch (role) {
        ChatRole.user => 'user',
        ChatRole.assistant => 'assistant',
        ChatRole.system => 'system',
      };

  String _describeDioError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the Ollama server. Is it running?';
    }
    return e.message ?? 'Network error contacting Ollama.';
  }

  @override
  Stream<ChatDelta> chatStream({
    required String baseUrl,
    required String model,
    required List<ChatTurn> messages,
    required InferenceSettings settings,
    CancelSignal? cancelSignal,
  }) {
    final controller = StreamController<ChatDelta>();
    final cancelToken = CancelToken();
    final subscription = cancelSignal?.onCancel.listen((_) => cancelToken.cancel());

    Future<void> run() async {
      try {
        final body = <String, dynamic>{
          'model': model,
          'stream': true,
          'messages': [
            if (settings.systemPrompt != null && settings.systemPrompt!.isNotEmpty)
              {'role': 'system', 'content': settings.systemPrompt},
            for (final turn in messages) {'role': _roleName(turn.role), 'content': turn.content},
          ],
          'options': {
            'temperature': settings.temperature,
            if (settings.topP != null) 'top_p': settings.topP,
            if (settings.topK != null) 'top_k': settings.topK,
            if (settings.repeatPenalty != null) 'repeat_penalty': settings.repeatPenalty,
            if (settings.maxTokens != null) 'num_predict': settings.maxTokens,
            'num_ctx': settings.contextLength,
            if (settings.seed != null) 'seed': settings.seed,
            if (settings.stopSequences.isNotEmpty) 'stop': settings.stopSequences,
          },
        };

        final response = await _dio.post<ResponseBody>(
          '$baseUrl/api/chat',
          data: jsonEncode(body),
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Content-Type': 'application/json'},
          ),
          cancelToken: cancelToken,
        );

        var buffer = '';
        await for (final chunk in response.data!.stream) {
          if (cancelSignal?.isCancelled ?? false) break;
          buffer += utf8.decode(chunk, allowMalformed: true);
          var newlineIndex = buffer.indexOf('\n');
          while (newlineIndex != -1) {
            final line = buffer.substring(0, newlineIndex).trim();
            buffer = buffer.substring(newlineIndex + 1);
            if (line.isNotEmpty) _handleLine(line, controller);
            newlineIndex = buffer.indexOf('\n');
          }
        }
        final remainder = buffer.trim();
        if (remainder.isNotEmpty) _handleLine(remainder, controller);
        if (!controller.isClosed) await controller.close();
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          if (!controller.isClosed) await controller.close();
        } else if (!controller.isClosed) {
          controller.addError(NetworkException(_describeDioError(e)));
          await controller.close();
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(EngineException(e.toString()));
          await controller.close();
        }
      } finally {
        await subscription?.cancel();
      }
    }

    unawaited(run());
    return controller.stream;
  }

  void _handleLine(String line, StreamController<ChatDelta> controller) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final done = json['done'] == true;
      final content = (json['message'] as Map<String, dynamic>?)?['content'] as String? ?? '';
      double? tokensPerSecond;
      final evalCount = json['eval_count'] as int?;
      if (done) {
        final evalDuration = json['eval_duration'] as int?;
        if (evalCount != null && evalDuration != null && evalDuration > 0) {
          tokensPerSecond = evalCount / (evalDuration / 1e9);
        }
      }
      controller.add(ChatDelta(
        contentDelta: content,
        done: done,
        evalCount: evalCount,
        tokensPerSecond: tokensPerSecond,
      ));
    } catch (_) {
      // Ignore malformed / keep-alive fragments.
    }
  }

  @override
  Future<List<EngineModelInfo>> listModels({required String baseUrl}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('$baseUrl/api/tags');
      final models = (response.data?['models'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      return [
        for (final m in models)
          EngineModelInfo(name: m['name'] as String, sizeBytes: m['size'] as int?),
      ];
    } on DioException catch (e) {
      throw NetworkException(_describeDioError(e));
    }
  }

  @override
  Future<void> pullModel({
    required String baseUrl,
    required String model,
    void Function(PullProgress progress)? onProgress,
  }) async {
    try {
      final response = await _dio.post<ResponseBody>(
        '$baseUrl/api/pull',
        data: jsonEncode({'model': model, 'stream': true}),
        options: Options(responseType: ResponseType.stream),
      );
      var buffer = '';
      await for (final chunk in response.data!.stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        var newlineIndex = buffer.indexOf('\n');
        while (newlineIndex != -1) {
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);
          if (line.isNotEmpty) {
            final json = jsonDecode(line) as Map<String, dynamic>;
            onProgress?.call(PullProgress(
              status: json['status'] as String? ?? '',
              completedBytes: json['completed'] as int?,
              totalBytes: json['total'] as int?,
            ));
          }
          newlineIndex = buffer.indexOf('\n');
        }
      }
    } on DioException catch (e) {
      throw NetworkException(_describeDioError(e));
    }
  }

  /// Registers a locally-downloaded GGUF file as an Ollama model via
  /// `/api/create`, using a minimal `FROM <path>` Modelfile. This requires
  /// the Ollama server itself to have filesystem access to [ggufPath] —
  /// true for the common case of a local Ollama install, not yet for a
  /// remote one (that needs the blob-upload variant of this API, deferred
  /// until a remote engine is wired up).
  Future<void> createModelFromGguf({
    required String baseUrl,
    required String modelName,
    required String ggufPath,
    void Function(String status)? onProgress,
  }) async {
    try {
      final response = await _dio.post<ResponseBody>(
        '$baseUrl/api/create',
        data: jsonEncode({
          'model': modelName,
          'modelfile': 'FROM $ggufPath',
          'stream': true,
        }),
        options: Options(responseType: ResponseType.stream),
      );
      var buffer = '';
      await for (final chunk in response.data!.stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        var newlineIndex = buffer.indexOf('\n');
        while (newlineIndex != -1) {
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);
          if (line.isNotEmpty) {
            final json = jsonDecode(line) as Map<String, dynamic>;
            if (json['error'] != null) {
              throw EngineException(json['error'] as String);
            }
            final status = json['status'] as String?;
            if (status != null) onProgress?.call(status);
          }
          newlineIndex = buffer.indexOf('\n');
        }
      }
    } on DioException catch (e) {
      throw NetworkException(_describeDioError(e));
    }
  }

  @override
  Future<bool> testConnection({required String baseUrl}) async {
    try {
      final response = await _dio.get<dynamic>('$baseUrl/api/version');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

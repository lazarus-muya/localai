import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

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

  /// The stock Ollama build bundled with Termux (Android) ships a
  /// `llama-quantize` binary without the "compatibility patches" upstream
  /// Ollama uses to validate newer GGUF quant types (notably the I-quants:
  /// IQ1/IQ2/IQ3/IQ4). Registering one of those files makes `/api/create`
  /// shell out to that binary to sanity-check the file, which fails with
  /// exit status 1 even though the download itself succeeded. There is no
  /// client-side retry for this — the fix is to pick a K-quant (Q4_K_M,
  /// Q5_K_M, Q6_K, Q8_0, …) build of the same model instead.
  String _friendlyCreateError(String raw) {
    if (raw.contains('llama-quantize') && raw.contains('compatibility patches')) {
      return 'This build of Ollama (on Android/Termux) can\'t validate this file\'s '
          'quantization — it likely uses an I-quant format (IQ1/IQ2/IQ3/IQ4) that '
          'needs newer llama-quantize patches than are bundled here. Try a K-quant '
          'version of the same model instead, such as Q4_K_M, Q5_K_M, or Q8_0.\n\n'
          '($raw)';
    }
    return raw;
  }

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
          // Overrides Ollama's default 5-minute idle unload, which was
          // forcing a full reload (and the "loading model" delay) on every
          // chat after a short gap. `0` keeps it loaded forever.
          'keep_alive': settings.keepAliveMinutes <= 0 ? -1 : '${settings.keepAliveMinutes}m',
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
  Future<bool> isModelLoaded({required String baseUrl, required String model}) async {
    final response = await _dio.get<Map<String, dynamic>>('$baseUrl/api/ps');
    final running = (response.data?['models'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    String stripTag(String name) => name.split(':').first;
    return running.any((m) {
      final name = (m['model'] ?? m['name']) as String?;
      if (name == null) return false;
      return name == model || stripTag(name) == stripTag(model);
    });
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

  /// Registers a locally-downloaded GGUF file as an Ollama model.
  ///
  /// The `/api/create` endpoint no longer takes a raw `modelfile` string
  /// with a `FROM <local path>` line (that only works for the `ollama`
  /// CLI, which resolves paths against its own working directory). The
  /// HTTP API instead requires the file to be content-addressed first:
  /// the blob is pushed to `/api/blobs/sha256:<digest>`, then `/api/create`
  /// is called with a `files` map from filename to that digest. This also
  /// means no path escaping is needed and works the same on Windows,
  /// macOS, and Linux, and against a non-local Ollama server.
  Future<void> createModelFromGguf({
    required String baseUrl,
    required String modelName,
    required String ggufPath,
    void Function(String status)? onProgress,
  }) async {
    final file = File(ggufPath);
    final fileName = p.basename(ggufPath);
    try {
      onProgress?.call('Hashing model file...');
      final digest = await _sha256OfFile(file);
      final digestRef = 'sha256:$digest';

      if (!await _blobExists(baseUrl, digestRef)) {
        onProgress?.call('Uploading model to Ollama...');
        await _uploadBlob(baseUrl: baseUrl, digestRef: digestRef, file: file, onProgress: onProgress);
      }

      onProgress?.call('Registering model...');
      final response = await _dio.post<ResponseBody>(
        '$baseUrl/api/create',
        data: jsonEncode({
          'model': modelName,
          'files': {fileName: digestRef},
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
              throw EngineException(_friendlyCreateError(json['error'] as String));
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

  Future<String> _sha256OfFile(File file) async {
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return sink.value.toString();
  }

  Future<bool> _blobExists(String baseUrl, String digestRef) async {
    try {
      final response = await _dio.head<void>('$baseUrl/api/blobs/$digestRef');
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      throw NetworkException(_describeDioError(e));
    }
  }

  Future<void> _uploadBlob({
    required String baseUrl,
    required String digestRef,
    required File file,
    void Function(String status)? onProgress,
  }) async {
    final length = await file.length();
    await _dio.post<void>(
      '$baseUrl/api/blobs/$digestRef',
      data: file.openRead(),
      options: Options(
        headers: {
          Headers.contentLengthHeader: length,
          'Content-Type': 'application/octet-stream',
        },
      ),
      onSendProgress: (sent, total) {
        if (total > 0) {
          final pct = (sent / total * 100).clamp(0, 100).toStringAsFixed(0);
          onProgress?.call('Uploading model to Ollama... $pct%');
        }
      },
    );
  }

  @override
  Future<void> deleteModel({required String baseUrl, required String model}) async {
    try {
      await _dio.delete<void>(
        '$baseUrl/api/delete',
        data: jsonEncode({'model': model}),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
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

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../../core/utils/cancel_signal.dart';

class DownloadProgress {
  const DownloadProgress({required this.receivedBytes, this.totalBytes});

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction => totalBytes == null || totalBytes == 0 ? null : receivedBytes / totalBytes!;
}

/// Resumable file downloader: writes to a `.part` sibling file and resumes
/// via an HTTP Range request if that partial file already exists, so an
/// interrupted multi-gigabyte GGUF download doesn't restart from zero. Falls
/// back to a full restart if the server doesn't honor the Range request.
class ModelDownloader {
  ModelDownloader(this._dio);

  final Dio _dio;

  Stream<DownloadProgress> download({
    required String url,
    required String destinationPath,
    CancelSignal? cancelSignal,
  }) {
    final controller = StreamController<DownloadProgress>();
    final cancelToken = CancelToken();
    final subscription = cancelSignal?.onCancel.listen((_) => cancelToken.cancel());

    Future<void> run() async {
      final partFile = File('$destinationPath.part');
      var existingLength = await partFile.exists() ? await partFile.length() : 0;
      RandomAccessFile? raf;

      try {
        final response = await _dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers: existingLength > 0 ? {'Range': 'bytes=$existingLength-'} : null,
          ),
          cancelToken: cancelToken,
        );

        final resumed = existingLength > 0 && response.statusCode == 206;
        if (existingLength > 0 && !resumed) {
          existingLength = 0; // server ignored the Range request; restart clean.
        }
        raf = await partFile.open(mode: resumed ? FileMode.append : FileMode.write);

        final contentLength = response.headers.value(Headers.contentLengthHeader);
        final bodyLength = contentLength != null ? int.tryParse(contentLength) : null;
        final total = bodyLength == null ? null : (resumed ? bodyLength + existingLength : bodyLength);

        var received = existingLength;
        controller.add(DownloadProgress(receivedBytes: received, totalBytes: total));

        await for (final chunk in response.data!.stream) {
          if (cancelSignal?.isCancelled ?? false) break;
          await raf.writeFrom(chunk);
          received += chunk.length;
          controller.add(DownloadProgress(receivedBytes: received, totalBytes: total));
        }

        await raf.close();
        raf = null;

        if (cancelSignal?.isCancelled ?? false) {
          if (!controller.isClosed) await controller.close();
          return;
        }

        await partFile.rename(destinationPath);
        if (!controller.isClosed) await controller.close();
      } on DioException catch (e) {
        await raf?.close();
        if (!controller.isClosed) {
          if (!CancelToken.isCancel(e)) {
            controller.addError(NetworkException(e.message ?? 'Download failed.'));
          }
          await controller.close();
        }
      } catch (e) {
        await raf?.close();
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
}

import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import 'huggingface_models.dart';

/// Hand-rolled HuggingFace Hub client (no reliable dedicated Dart package
/// exists for this): search for GGUF models, list a repo's GGUF files with
/// sizes, and build direct download URLs.
class HuggingFaceApiClient {
  HuggingFaceApiClient(this._dio);

  final Dio _dio;
  static const _baseUrl = 'https://huggingface.co';

  Future<List<HuggingFaceModelSummary>> searchGgufModels(String query, {int limit = 20}) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '$_baseUrl/api/models',
        queryParameters: {
          if (query.trim().isNotEmpty) 'search': query.trim(),
          'filter': 'gguf',
          'limit': limit,
          'sort': 'downloads',
          'direction': -1,
        },
      );
      return (response.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map(HuggingFaceModelSummary.fromJson)
          .toList();
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Failed to search HuggingFace models.');
    }
  }

  /// Lists `.gguf` files (with size, when reported) in a repo's default
  /// branch via the `tree` API, which — unlike the plain model-info
  /// endpoint — includes file sizes.
  Future<List<HuggingFaceFile>> listGgufFiles(String repoId) async {
    try {
      final response = await _dio.get<List<dynamic>>('$_baseUrl/api/models/$repoId/tree/main');
      final entries = (response.data ?? const []).cast<Map<String, dynamic>>();
      return entries
          .where((e) => e['type'] == 'file' && (e['path'] as String? ?? '').toLowerCase().endsWith('.gguf'))
          .map((e) => HuggingFaceFile(path: e['path'] as String, sizeBytes: (e['size'] as num?)?.toInt()))
          .toList();
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Failed to list files for $repoId.');
    }
  }

  String downloadUrl(String repoId, String filePath) => '$_baseUrl/$repoId/resolve/main/$filePath';
}

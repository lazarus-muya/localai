import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download/model_downloader.dart';
import '../../data/hardware/hardware_detector.dart';
import '../../data/hardware/hardware_detector_android.dart';
import '../../data/hardware/hardware_detector_windows.dart';
import '../../data/local/database/app_database.dart';
import '../../data/remote/huggingface/huggingface_api_client.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/engine/ollama_engine.dart';
import '../../domain/entities/hardware_profile.dart';
import '../../domain/repositories/chat_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(appDatabaseProvider));
});

final dioProvider = Provider<Dio>((ref) => Dio());

final ollamaEngineProvider = Provider<OllamaEngine>((ref) {
  return OllamaEngine(ref.watch(dioProvider));
});

final huggingFaceApiClientProvider = Provider<HuggingFaceApiClient>((ref) {
  return HuggingFaceApiClient(ref.watch(dioProvider));
});

final modelDownloaderProvider = Provider<ModelDownloader>((ref) {
  return ModelDownloader(ref.watch(dioProvider));
});

final hardwareDetectorProvider = Provider<HardwareDetector>((ref) {
  if (Platform.isWindows) return WindowsHardwareDetector();
  if (Platform.isAndroid) return AndroidHardwareDetector();
  return _NullHardwareDetector();
});

class _NullHardwareDetector implements HardwareDetector {
  @override
  Future<HardwareProfile> detect() async {
    return HardwareProfile(platform: AppPlatform.other, cpuCores: Platform.numberOfProcessors);
  }
}

import '../entities/hardware_profile.dart';

enum ModelFit { fits, tight, tooLarge, unknown }

/// Rule-of-thumb hardware-fit check: a GGUF model typically needs a bit more
/// RAM than its file size (weights + KV cache + runtime overhead) to run
/// well. This is intentionally coarse — a real fit calculation would need
/// per-quantization and context-length details we don't have yet.
class ModelRecommendationService {
  const ModelRecommendationService();

  static const _overheadFactor = 1.2;

  ModelFit assess({required int? modelFileSizeBytes, required HardwareProfile hardware}) {
    final totalRam = hardware.totalRamBytes;
    if (modelFileSizeBytes == null || totalRam == null) return ModelFit.unknown;
    final required = (modelFileSizeBytes * _overheadFactor).round();
    if (required <= totalRam * 0.6) return ModelFit.fits;
    if (required <= totalRam) return ModelFit.tight;
    return ModelFit.tooLarge;
  }
}

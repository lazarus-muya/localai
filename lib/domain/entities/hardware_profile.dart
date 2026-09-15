enum AppPlatform { windows, android, other }

class HardwareProfile {
  const HardwareProfile({
    required this.platform,
    required this.cpuCores,
    this.totalRamBytes,
    this.freeDiskBytes,
    this.gpuName,
    this.gpuVramBytes,
  });

  final AppPlatform platform;
  final int cpuCores;
  final int? totalRamBytes;
  final int? freeDiskBytes;
  final String? gpuName;
  final int? gpuVramBytes;
}

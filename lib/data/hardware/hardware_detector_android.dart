import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/entities/hardware_profile.dart';
import 'hardware_detector.dart';

/// Reads RAM/disk via a small native MethodChannel (see MainActivity.kt) —
/// `device_info_plus` only exposes device identity, not memory or storage.
class AndroidHardwareDetector implements HardwareDetector {
  static const _channel = MethodChannel('localai/hardware');

  @override
  Future<HardwareProfile> detect() async {
    int? totalRam;
    int? freeDisk;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getMemoryInfo');
      totalRam = (result?['totalRamBytes'] as num?)?.toInt();
      freeDisk = (result?['freeDiskBytes'] as num?)?.toInt();
    } catch (_) {
      // Native handler unavailable — leave fields null.
    }

    return HardwareProfile(
      platform: AppPlatform.android,
      cpuCores: Platform.numberOfProcessors,
      totalRamBytes: totalRam,
      freeDiskBytes: freeDisk,
    );
  }
}

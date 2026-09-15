import 'dart:convert';
import 'dart:io';

import '../../domain/entities/hardware_profile.dart';
import 'hardware_detector.dart';

/// Queries RAM/GPU/disk via PowerShell + WMI since no cross-platform Dart
/// package reports these reliably. Best-effort: any failure just leaves the
/// corresponding fields null rather than throwing.
class WindowsHardwareDetector implements HardwareDetector {
  @override
  Future<HardwareProfile> detect() async {
    int? totalRam;
    int? freeDisk;
    String? gpuName;
    int? gpuVram;

    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r'''
        $cs = Get-CimInstance Win32_ComputerSystem
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
        $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
        [PSCustomObject]@{
          TotalRam = $cs.TotalPhysicalMemory
          FreeDisk = $drive.FreeSpace
          GpuName = $gpu.Name
          GpuVram = $gpu.AdapterRAM
        } | ConvertTo-Json
        ''',
      ]).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0) {
        final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
        totalRam = _toInt(json['TotalRam']);
        freeDisk = _toInt(json['FreeDisk']);
        gpuName = json['GpuName'] as String?;
        gpuVram = _toInt(json['GpuVram']);
      }
    } catch (_) {
      // PowerShell/WMI unavailable — leave fields null.
    }

    return HardwareProfile(
      platform: AppPlatform.windows,
      cpuCores: Platform.numberOfProcessors,
      totalRamBytes: totalRam,
      freeDiskBytes: freeDisk,
      gpuName: gpuName,
      gpuVramBytes: gpuVram,
    );
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }
}

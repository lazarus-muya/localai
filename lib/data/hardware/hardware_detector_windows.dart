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
        $gpus = Get-CimInstance Win32_VideoController | Select-Object Name, AdapterRAM
        $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
        [PSCustomObject]@{
          TotalRam = $cs.TotalPhysicalMemory
          FreeDisk = $drive.FreeSpace
          Gpus = @($gpus)
        } | ConvertTo-Json
        ''',
      ]).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0) {
        final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
        totalRam = _toInt(json['TotalRam']);
        freeDisk = _toInt(json['FreeDisk']);

        // Laptops with hybrid graphics report multiple video controllers
        // (an integrated GPU alongside a discrete one), and WMI doesn't
        // guarantee enumeration order puts the discrete card first. Since
        // Ollama's CUDA backend is what actually accelerates inference,
        // prefer an NVIDIA adapter when present; otherwise fall back to
        // whichever adapter reports the most VRAM (discrete cards report
        // far more than integrated ones).
        final gpusRaw = json['Gpus'];
        final gpuList = switch (gpusRaw) {
          List<dynamic> l => l,
          Map<String, dynamic> m => [m],
          _ => const <dynamic>[],
        };
        final gpus = gpuList.cast<Map<String, dynamic>>();

        Map<String, dynamic>? best;
        for (final g in gpus) {
          final name = (g['Name'] as String?) ?? '';
          if (name.toUpperCase().contains('NVIDIA')) {
            best = g;
            break;
          }
          final vram = _toInt(g['AdapterRAM']) ?? 0;
          final bestVram = _toInt(best?['AdapterRAM']) ?? -1;
          if (best == null || vram > bestVram) best = g;
        }

        gpuName = best?['Name'] as String?;
        gpuVram = _toInt(best?['AdapterRAM']);
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../domain/entities/hardware_profile.dart';
import '../../shared/format_bytes.dart';
import '../../shared/widgets/settings_section.dart';
import '../model_library_controller.dart';
import 'add_remote_model_dialog.dart';
import 'fit_badge.dart';

class InstalledModelsTab extends ConsumerWidget {
  const InstalledModelsTab({super.key});

  Future<bool> _confirm(BuildContext context, {required String title, required String content}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(installedModelsProvider);
    final hardwareAsync = ref.watch(hardwareProfileProvider);
    final downloads = ref.watch(downloadManagerProvider);

    final palette = context.palette;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(installedModelsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          hardwareAsync.when(
            data: (hw) => _HardwareBanner(hardware: hw),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Hardware detection failed: $e'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AddRemoteModelDialog(),
              ),
              icon: const Icon(Icons.add_link),
              label: const Text('Add model from URL'),
            ),
          ),
          if (downloads.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final entry in downloads.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DownloadCard(downloadKey: entry.key, state: entry.value),
              ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Installed models',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              modelsAsync.maybeWhen(
                data: (models) => models.isEmpty
                    ? const SizedBox.shrink()
                    : TextButton.icon(
                        onPressed: () async {
                          final confirmed = await _confirm(
                            context,
                            title: 'Delete all models?',
                            content:
                                'This removes all ${models.length} installed model(s). This cannot be undone.',
                          );
                          if (!confirmed) return;
                          await ref.read(modelActionsProvider).deleteAllModels();
                        },
                        icon: Icon(Icons.delete_sweep, color: palette.danger, size: 18),
                        label: Text('Delete all', style: TextStyle(color: palette.danger)),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          modelsAsync.when(
            data: (models) {
              if (models.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No models installed yet. Get one from the HuggingFace tab.',
                    style: TextStyle(color: palette.mutedText),
                  ),
                );
              }
              return SettingsSection(
                children: [
                  for (final m in models)
                    SettingsRow(
                      title: m.name,
                      subtitle: m.sizeBytes != null ? formatBytes(m.sizeBytes!) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          hardwareAsync.maybeWhen(
                            data: (hw) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FitBadge(
                                fit: modelRecommendationService.assess(
                                  modelFileSizeBytes: m.sizeBytes,
                                  hardware: hw,
                                ),
                              ),
                            ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete model',
                            onPressed: () async {
                              final confirmed = await _confirm(
                                context,
                                title: 'Delete model?',
                                content: 'This removes "${m.name}". This cannot be undone.',
                              );
                              if (!confirmed) return;
                              await ref.read(modelActionsProvider).deleteModel(m.name);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Could not list installed models: $e'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HardwareBanner extends StatelessWidget {
  const _HardwareBanner({required this.hardware});

  final HardwareProfile hardware;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parts = <String>[
      '${hardware.cpuCores} CPU cores',
      if (hardware.totalRamBytes != null) '${formatBytes(hardware.totalRamBytes!)} RAM',
      if (hardware.gpuName != null) hardware.gpuName!,
      if (hardware.freeDiskBytes != null) '${formatBytes(hardware.freeDiskBytes!)} free disk',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.memory, size: 18, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(parts.join(' · '), style: TextStyle(color: palette.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _DownloadCard extends ConsumerWidget {
  const _DownloadCard({required this.downloadKey, required this.state});

  final String downloadKey;
  final DownloadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              if (state.done || state.error != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => ref.read(downloadManagerProvider.notifier).dismiss(downloadKey),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (state.error != null)
            Text(state.error!, style: TextStyle(color: palette.danger, fontSize: 12.5))
          else if (state.done)
            Text('Installed', style: TextStyle(color: palette.success, fontSize: 12.5))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.fraction,
                backgroundColor: palette.inputFill,
                color: palette.accent,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.totalBytes != null
                  ? '${formatBytes(state.receivedBytes)} / ${formatBytes(state.totalBytes!)}'
                  : formatBytes(state.receivedBytes),
              style: TextStyle(color: palette.mutedText, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

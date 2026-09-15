import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/hardware_profile.dart';
import '../../shared/format_bytes.dart';
import '../model_library_controller.dart';
import 'add_remote_model_dialog.dart';
import 'fit_badge.dart';

class InstalledModelsTab extends ConsumerWidget {
  const InstalledModelsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(installedModelsProvider);
    final hardwareAsync = ref.watch(hardwareProfileProvider);
    final downloads = ref.watch(downloadManagerProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(installedModelsProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          hardwareAsync.when(
            data: (hw) => _HardwareBanner(hardware: hw),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Hardware detection failed: $e'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AddRemoteModelDialog(),
            ),
            icon: const Icon(Icons.add_link),
            label: const Text('Add model from URL'),
          ),
          if (downloads.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final entry in downloads.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DownloadCard(downloadKey: entry.key, state: entry.value),
              ),
          ],
          const Divider(height: 32),
          Text('Installed models', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          modelsAsync.when(
            data: (models) {
              if (models.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No models installed yet. Pull one via the HuggingFace tab.'),
                );
              }
              return Column(
                children: [
                  for (final m in models)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.memory),
                        title: Text(m.name),
                        subtitle: m.sizeBytes != null ? Text(formatBytes(m.sizeBytes!)) : null,
                        trailing: hardwareAsync.maybeWhen(
                          data: (hw) => FitBadge(
                            fit: modelRecommendationService.assess(
                              modelFileSizeBytes: m.sizeBytes,
                              hardware: hw,
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
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
              child: Text('Could not reach Ollama: $e'),
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
    final parts = <String>[
      '${hardware.cpuCores} CPU cores',
      if (hardware.totalRamBytes != null) '${formatBytes(hardware.totalRamBytes!)} RAM',
      if (hardware.gpuName != null) hardware.gpuName!,
      if (hardware.freeDiskBytes != null) '${formatBytes(hardware.freeDiskBytes!)} free disk',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(parts.join(' · ')),
    );
  }
}

class _DownloadCard extends ConsumerWidget {
  const _DownloadCard({required this.downloadKey, required this.state});

  final String downloadKey;
  final DownloadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(state.label, overflow: TextOverflow.ellipsis)),
                if (state.done || state.error != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => ref.read(downloadManagerProvider.notifier).dismiss(downloadKey),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (state.error != null)
              Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (state.done)
              const Text('Installed')
            else ...[
              LinearProgressIndicator(value: state.fraction),
              const SizedBox(height: 4),
              Text(
                state.totalBytes != null
                    ? '${formatBytes(state.receivedBytes)} / ${formatBytes(state.totalBytes!)}'
                    : formatBytes(state.receivedBytes),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

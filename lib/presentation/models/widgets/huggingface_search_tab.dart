import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/remote/huggingface/huggingface_models.dart';
import '../../shared/format_bytes.dart';
import '../../shared/widgets/settings_section.dart';
import '../model_library_controller.dart';
import 'fit_badge.dart';

const _masterDetailBreakpoint = 760.0;

String _formatCount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class HuggingFaceSearchTab extends ConsumerStatefulWidget {
  const HuggingFaceSearchTab({super.key});

  @override
  ConsumerState<HuggingFaceSearchTab> createState() => _HuggingFaceSearchTabState();
}

class _HuggingFaceSearchTabState extends ConsumerState<HuggingFaceSearchTab> {
  final _searchController = TextEditingController(text: 'llama');
  String _query = 'llama';
  String? _selectedRepoId;
  HuggingFaceModelSummary? _selectedModel;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(huggingFaceSearchProvider(_query));
    final palette = context.palette;

    final searchBar = Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search HuggingFace GGUF models…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _query = '';
                  }),
                ),
        ),
        onSubmitted: (v) => setState(() => _query = v.trim()),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _masterDetailBreakpoint;

        final list = resultsAsync.when(
          data: (results) {
            if (results.isEmpty) {
              return const Center(child: Text('No GGUF models found.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final model = results[index];
                if (isWide) {
                  return _ResultRow(
                    model: model,
                    selected: _selectedRepoId == model.id,
                    onTap: () => setState(() {
                      _selectedRepoId = model.id;
                      _selectedModel = model;
                    }),
                  );
                }
                final expanded = _selectedRepoId == model.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      _ResultRow(
                        model: model,
                        selected: false,
                        trailingIcon: expanded ? Icons.expand_less : Icons.expand_more,
                        onTap: () => setState(() {
                          _selectedRepoId = expanded ? null : model.id;
                        }),
                      ),
                      if (expanded) ...[
                        Divider(height: 1, color: palette.divider),
                        _GgufFileList(repoId: model.id),
                      ],
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Search failed: $e')),
        );

        if (!isWide) {
          return Column(children: [searchBar, Expanded(child: list)]);
        }

        return Row(
          children: [
            SizedBox(
              width: 360,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: palette.divider)),
                ),
                child: Column(children: [searchBar, Expanded(child: list)]),
              ),
            ),
            Expanded(
              child: _selectedRepoId == null
                  ? _EmptyDetailState(palette: palette)
                  : _ModelDetailPane(
                      key: ValueKey(_selectedRepoId),
                      repoId: _selectedRepoId!,
                      summary: _selectedModel,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.model,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
  });

  final HuggingFaceModelSummary model;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? palette.accent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected ? Border.all(color: palette.accent.withValues(alpha: 0.5)) : null,
          ),
          child: Row(
            children: [
              _RepoAvatar(repoId: model.id),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatCount(model.downloads)} downloads · ${_formatCount(model.likes)} likes',
                      style: TextStyle(fontSize: 11.5, color: palette.mutedText),
                    ),
                  ],
                ),
              ),
              if (trailingIcon != null) Icon(trailingIcon, size: 20, color: palette.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepoAvatar extends StatelessWidget {
  const _RepoAvatar({required this.repoId});

  final String repoId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final letter = repoId.isEmpty ? '?' : repoId[0].toUpperCase();
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Text(
        letter,
        style: TextStyle(fontWeight: FontWeight.w700, color: palette.mutedText, fontSize: 13),
      ),
    );
  }
}

class _EmptyDetailState extends StatelessWidget {
  const _EmptyDetailState({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 40, color: palette.mutedText),
          const SizedBox(height: 12),
          Text('Select a model to see details', style: TextStyle(color: palette.mutedText)),
        ],
      ),
    );
  }
}

class _ModelDetailPane extends ConsumerWidget {
  const _ModelDetailPane({super.key, required this.repoId, this.summary});

  final String repoId;
  final HuggingFaceModelSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Text(
                repoId.isEmpty ? '?' : repoId[0].toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: palette.mutedText),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    repoId.split('/').last,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(repoId, style: TextStyle(fontSize: 12.5, color: palette.mutedText)),
                ],
              ),
            ),
          ],
        ),
        if (summary case final s?) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(icon: Icons.download_outlined, label: _formatCount(s.downloads)),
              _StatChip(icon: Icons.star_border, label: _formatCount(s.likes)),
              for (final tag in s.tags.take(4)) _StatChip(label: tag),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'DOWNLOAD OPTIONS',
          style: TextStyle(
            color: palette.groupLabel,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        SettingsSection(children: [_GgufFileList(repoId: repoId)]),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.inputFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: palette.mutedText),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(fontSize: 12, color: palette.textPrimary)),
        ],
      ),
    );
  }
}

class _GgufFileList extends ConsumerWidget {
  const _GgufFileList({required this.repoId});

  final String repoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(huggingFaceFilesProvider(repoId));
    final hardwareAsync = ref.watch(hardwareProfileProvider);
    final downloads = ref.watch(downloadManagerProvider);
    final palette = context.palette;

    return filesAsync.when(
      data: (files) {
        if (files.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No .gguf files found in this repository.'),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < files.length; i++) ...[
              if (i > 0) Divider(height: 1, color: palette.divider),
              _FileRow(repoId: repoId, file: files[i], hardwareAsync: hardwareAsync, downloads: downloads),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Could not list files: $e'),
      ),
    );
  }
}

class _FileRow extends ConsumerWidget {
  const _FileRow({
    required this.repoId,
    required this.file,
    required this.hardwareAsync,
    required this.downloads,
  });

  final String repoId;
  final HuggingFaceFile file;
  final AsyncValue hardwareAsync;
  final Map<String, DownloadState> downloads;

  static final _iQuantPattern = RegExp(r'IQ[1-4]', caseSensitive: false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = '$repoId/${file.path}';
    final warnIQuant = Platform.isAndroid && _iQuantPattern.hasMatch(file.path);
    return SettingsRow(
      title: file.path,
      subtitle: file.sizeBytes != null ? formatBytes(file.sizeBytes!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (warnIQuant)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Tooltip(
                message: 'I-quant (IQx) files often fail to install on the Android '
                    'build of Ollama — llama-quantize can\'t validate them there. '
                    'Prefer a K-quant (e.g. Q4_K_M, Q5_K_M, Q8_0) if install fails.',
                child: Icon(Icons.warning_amber_rounded, size: 18, color: context.palette.warning),
              ),
            ),
          hardwareAsync.maybeWhen(
            data: (hw) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FitBadge(
                fit: modelRecommendationService.assess(modelFileSizeBytes: file.sizeBytes, hardware: hw),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download & install',
            onPressed: downloads.containsKey(key)
                ? null
                : () {
                    final client = ref.read(huggingFaceApiClientProvider);
                    final url = client.downloadUrl(repoId, file.path);
                    final modelName = _suggestModelName(repoId, file.path);
                    ref.read(downloadManagerProvider.notifier).downloadAndRegister(
                          key: key,
                          label: file.path,
                          url: url,
                          modelName: modelName,
                        );
                  },
          ),
        ],
      ),
    );
  }
}

String _suggestModelName(String repoId, String filePath) {
  final base = filePath.toLowerCase().replaceAll('.gguf', '');
  final safe = base.replaceAll(RegExp(r'[^a-z0-9._-]'), '-');
  return safe.isEmpty ? repoId.split('/').last.toLowerCase() : safe;
}

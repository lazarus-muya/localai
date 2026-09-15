import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../shared/format_bytes.dart';
import '../model_library_controller.dart';
import 'fit_badge.dart';

class HuggingFaceSearchTab extends ConsumerStatefulWidget {
  const HuggingFaceSearchTab({super.key});

  @override
  ConsumerState<HuggingFaceSearchTab> createState() => _HuggingFaceSearchTabState();
}

class _HuggingFaceSearchTabState extends ConsumerState<HuggingFaceSearchTab> {
  final _searchController = TextEditingController(text: 'llama');
  String _query = 'llama';
  String? _expandedRepoId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(huggingFaceSearchProvider(_query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search HuggingFace GGUF models…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _query = _searchController.text.trim()),
              ),
            ),
            onSubmitted: (v) => setState(() => _query = v.trim()),
          ),
        ),
        Expanded(
          child: resultsAsync.when(
            data: (results) {
              if (results.isEmpty) {
                return const Center(child: Text('No GGUF models found.'));
              }
              return ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final model = results[index];
                  final expanded = _expandedRepoId == model.id;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(model.id, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${model.downloads} downloads · ${model.likes} likes'),
                          trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                          onTap: () => setState(() {
                            _expandedRepoId = expanded ? null : model.id;
                          }),
                        ),
                        if (expanded) _GgufFileList(repoId: model.id),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Search failed: $e')),
          ),
        ),
      ],
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
            for (final file in files)
              ListTile(
                dense: true,
                title: Text(file.path, style: const TextStyle(fontSize: 13)),
                subtitle: file.sizeBytes != null ? Text(formatBytes(file.sizeBytes!)) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    hardwareAsync.maybeWhen(
                      data: (hw) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FitBadge(
                          fit: modelRecommendationService.assess(
                            modelFileSizeBytes: file.sizeBytes,
                            hardware: hw,
                          ),
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: 'Download & install',
                      onPressed: downloads.containsKey('$repoId/${file.path}')
                          ? null
                          : () {
                              final client = ref.read(huggingFaceApiClientProvider);
                              final url = client.downloadUrl(repoId, file.path);
                              final modelName = _suggestModelName(repoId, file.path);
                              ref.read(downloadManagerProvider.notifier).downloadAndRegister(
                                    key: '$repoId/${file.path}',
                                    label: file.path,
                                    url: url,
                                    modelName: modelName,
                                  );
                            },
                    ),
                  ],
                ),
              ),
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

String _suggestModelName(String repoId, String filePath) {
  final base = filePath.toLowerCase().replaceAll('.gguf', '');
  final safe = base.replaceAll(RegExp(r'[^a-z0-9._-]'), '-');
  return safe.isEmpty ? repoId.split('/').last.toLowerCase() : safe;
}

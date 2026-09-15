import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../domain/entities/app_settings.dart';
import '../models/model_library_controller.dart';

final watchedSettingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(chatRepositoryProvider).watchSettings();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _portController = TextEditingController();
  final _modelController = TextEditingController();
  final _systemPromptController = TextEditingController();
  bool _initialized = false;
  bool _testing = false;
  String? _testResult;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _portController.dispose();
    _modelController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  void _populateIfNeeded(AppSettings settings) {
    if (_initialized) return;
    _initialized = true;
    _baseUrlController.text = settings.ollamaBaseUrl;
    _portController.text = settings.ollamaPort.toString();
    _modelController.text = settings.defaultOllamaModel ?? '';
    _systemPromptController.text = settings.globalSystemPrompt ?? '';
  }

  Future<void> _save() async {
    final repo = ref.read(chatRepositoryProvider);
    final current = await repo.getSettings();
    await repo.updateSettings(current.copyWith(
      ollamaBaseUrl: _baseUrlController.text.trim(),
      ollamaPort: int.tryParse(_portController.text.trim()) ?? current.ollamaPort,
      defaultOllamaModel: _modelController.text.trim(),
      globalSystemPrompt: _systemPromptController.text,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final engine = ref.read(ollamaEngineProvider);
    final baseUrl = '${_baseUrlController.text.trim()}:${_portController.text.trim()}';
    final ok = await engine.testConnection(baseUrl: baseUrl);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = ok ? 'Connected' : 'Could not reach Ollama at $baseUrl';
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(watchedSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        data: (settings) {
          _populateIfNeeded(settings);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Ollama connection', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(labelText: 'Base URL', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Default model (e.g. llama3.2)',
                  border: OutlineInputBorder(),
                ),
              ),
              _InstalledModelChips(
                onPicked: (name) => setState(() => _modelController.text = name),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _testing ? null : _testConnection,
                    child: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test connection'),
                  ),
                  const SizedBox(width: 12),
                  if (_testResult != null) Expanded(child: Text(_testResult!)),
                ],
              ),
              const Divider(height: 32),
              Text('Global system prompt', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _systemPromptController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Applied to every conversation unless overridden.',
                  border: OutlineInputBorder(),
                ),
              ),
              const Divider(height: 32),
              Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const _ThemeModeSelector(),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Save settings')),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load settings: $e')),
      ),
    );
  }
}

class _InstalledModelChips extends ConsumerWidget {
  const _InstalledModelChips({required this.onPicked});

  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(installedModelsProvider);
    return modelsAsync.when(
      data: (models) {
        if (models.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in models)
                ActionChip(label: Text(m.name), onPressed: () => onPicked(m.name)),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
        ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
        ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
      ],
      selected: {mode},
      onSelectionChanged: (selection) {
        ref.read(themeModeControllerProvider.notifier).setThemeMode(selection.first);
      },
    );
  }
}

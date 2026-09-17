import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../domain/entities/app_settings.dart';
import '../models/model_library_controller.dart';
import '../shared/widgets/settings_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _portController = TextEditingController();
  final _ollamaModelController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _keepAliveController = TextEditingController();
  bool _initialized = false;
  bool _testing = false;
  String? _testResult;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _portController.dispose();
    _ollamaModelController.dispose();
    _systemPromptController.dispose();
    _keepAliveController.dispose();
    super.dispose();
  }

  void _populateIfNeeded(AppSettings settings) {
    if (_initialized) return;
    _initialized = true;
    _baseUrlController.text = settings.ollamaBaseUrl;
    _portController.text = settings.ollamaPort.toString();
    _ollamaModelController.text = settings.defaultOllamaModel ?? '';
    _systemPromptController.text = settings.globalSystemPrompt ?? '';
    _keepAliveController.text = settings.modelKeepAliveMinutes.toString();
  }

  Future<void> _save() async {
    final repo = ref.read(chatRepositoryProvider);
    final current = await repo.getSettings();
    await repo.updateSettings(current.copyWith(
      ollamaBaseUrl: _baseUrlController.text.trim(),
      ollamaPort: int.tryParse(_portController.text.trim()) ?? current.ollamaPort,
      defaultOllamaModel: _ollamaModelController.text.trim(),
      globalSystemPrompt: _systemPromptController.text,
      modelKeepAliveMinutes:
          int.tryParse(_keepAliveController.text.trim()) ?? current.modelKeepAliveMinutes,
    ));
    ref.invalidate(installedModelsProvider);
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
    final settingsAsync = ref.watch(appSettingsProvider);
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        data: (settings) {
          _populateIfNeeded(settings);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              SettingsSection(
                title: 'Ollama connection',
                children: [
                  SettingsRow(
                    title: 'Server address',
                    subtitle: 'Base URL of your local Ollama server.',
                    trailing: TextField(controller: _baseUrlController, textAlign: TextAlign.end),
                    trailingWidth: 220,
                  ),
                  SettingsRow(
                    title: 'Port',
                    trailing: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                    ),
                    trailingWidth: 100,
                  ),
                  SettingsRow(
                    title: 'Default model',
                    subtitle: 'Used for new chats unless overridden.',
                    trailing: TextField(
                      controller: _ollamaModelController,
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(hintText: 'e.g. llama3.2'),
                    ),
                    trailingWidth: 220,
                  ),
                  if (_hasInstalledModels)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _InstalledModelDropdown(
                          selected: _ollamaModelController.text,
                          onPicked: (name) async {
                            setState(() => _ollamaModelController.text = name);
                            final repo = ref.read(chatRepositoryProvider);
                            final current = await repo.getSettings();
                            await repo.updateSettings(current.copyWith(defaultOllamaModel: name));
                          },
                        ),
                      ),
                    ),
                  SettingsRow(
                    title: 'Connection test',
                    subtitle: _testResult ?? 'Verify LocalAi can reach the server above.',
                    trailing: OutlinedButton(
                      onPressed: _testing ? null : _testConnection,
                      child: _testing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Test connection'),
                    ),
                  ),
                  SettingsRow(
                    title: 'Unload model after',
                    subtitle: 'Minutes of inactivity before Ollama frees the model from '
                        'memory. Use 0 to keep it loaded forever.',
                    trailing: TextField(
                      controller: _keepAliveController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(suffixText: 'min'),
                    ),
                    trailingWidth: 100,
                  ),
                ],
              ),
              SettingsSection(
                title: 'Chat',
                children: [
                  SettingsBlockRow(
                    title: 'Global system prompt',
                    subtitle: 'Applied to every conversation unless overridden.',
                    child: TextField(
                      controller: _systemPromptController,
                      maxLines: 5,
                      decoration: const InputDecoration(hintText: 'You are a helpful assistant…'),
                    ),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Appearance',
                children: [
                  SettingsRow(
                    title: 'Theme',
                    subtitle: 'Match your system, or pin light/dark.',
                    trailing: const _ThemeModeSelector(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Save settings')),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'LocalAi · offline-first',
                  style: TextStyle(color: palette.groupLabel, fontSize: 11.5),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load settings: $e')),
      ),
    );
  }

  bool get _hasInstalledModels {
    return ref.watch(installedModelsProvider).maybeWhen(
          data: (models) => models.isNotEmpty,
          orElse: () => false,
        );
  }
}

class _InstalledModelDropdown extends ConsumerStatefulWidget {
  const _InstalledModelDropdown({required this.selected, required this.onPicked});

  final String selected;
  final ValueChanged<String> onPicked;

  @override
  ConsumerState<_InstalledModelDropdown> createState() => _InstalledModelDropdownState();
}

class _InstalledModelDropdownState extends ConsumerState<_InstalledModelDropdown> {
  final _value = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(installedModelsProvider);
    return modelsAsync.maybeWhen(
      data: (models) {
        if (models.isEmpty) return const SizedBox.shrink();
        final names = [for (final m in models) m.name];
        _value.value = names.contains(widget.selected) ? widget.selected : null;
        return SizedBox(
          // width: 260,
          child: DropdownButtonHideUnderline(
            child: DropdownButton2<String>(
              isDense: true,
              isExpanded: true,
              valueListenable: _value,
              hint: const Text('Installed models', overflow: TextOverflow.ellipsis),
              items: [
                for (final name in names)
                  DropdownItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (name) {
                if (name != null) widget.onPicked(name);
              },
              buttonStyleData: const ButtonStyleData(
                padding: EdgeInsets.symmetric(horizontal: 12),
                height: 40,
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: ThemeMode.system, label: Text('System')),
        ButtonSegment(value: ThemeMode.light, label: Text('Light')),
        ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
      ],
      selected: {mode},
      onSelectionChanged: (selection) {
        ref.read(themeModeControllerProvider.notifier).setThemeMode(selection.first);
      },
    );
  }
}

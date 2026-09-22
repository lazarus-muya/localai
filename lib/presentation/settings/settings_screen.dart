import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adaptive/breakpoints.dart';
import '../../core/di/providers.dart';
import '../../core/speech/text_to_speech.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../domain/entities/app_settings.dart';
import '../models/model_library_controller.dart';
import '../shared/widgets/settings_section.dart';

/// Prefix used to tag read-aloud preview utterances so the Settings screen can
/// tell (and stop) its own preview vs. something else speaking. Each voice
/// gets its own suffixed key so the bottom sheet only highlights the tile
/// that's actually playing.
const _voicePreviewKey = '__voice_preview__';

/// Per-voice preview key: distinct for every voice so the picker's tiles can
/// tell which one is currently speaking.
String _voicePreviewKeyFor(Map<String, String> voice) {
  final key = _voiceKey(voice);
  return key == null ? '$_voicePreviewKey|system' : '$_voicePreviewKey|$key';
}

/// Read aloud to preview a voice before applying it as the default.
const _voiceSampleParagraph =
    'Hello! This is how my voice will sound when I read your messages aloud. '
    'Pick a voice, give it a listen, then save your settings to make it the '
    'default.';

/// 'name|locale' key used to identify a voice entry across the picker UI.
String? _voiceKey(Map<String, String> voice) {
  if (voice.isEmpty) return null;
  return '${voice['name']}|${voice['locale']}';
}

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

  /// Voice chosen in the picker but not yet saved. Empty means "system
  /// default" (explicitly clear any previously saved voice on save).
  Map<String, String> _pendingTtsVoice = const {};

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
    _pendingTtsVoice = settings.ttsVoice ?? const {};
  }

  String get _pendingVoiceLabel {
    final name = _pendingTtsVoice['name'];
    final locale = _pendingTtsVoice['locale'];
    if (name == null || name.isEmpty) return 'System default';
    return locale == null || locale.isEmpty ? name : '$name ($locale)';
  }

  Future<void> _save() async {
    final repo = ref.read(chatRepositoryProvider);
    final current = await repo.getSettings();
    final updated = AppSettings(
      ollamaBaseUrl: _baseUrlController.text.trim(),
      ollamaPort:
          int.tryParse(_portController.text.trim()) ?? current.ollamaPort,
      globalSystemPrompt: _systemPromptController.text,
      defaultOllamaModel: _ollamaModelController.text.trim(),
      modelKeepAliveMinutes:
          int.tryParse(_keepAliveController.text.trim()) ??
          current.modelKeepAliveMinutes,
      ttsVoice: _pendingTtsVoice.isEmpty ? null : _pendingTtsVoice,
    );
    await repo.updateSettings(updated);
    ref.invalidate(installedModelsProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final engine = ref.read(ollamaEngineProvider);
    final baseUrl =
        '${_baseUrlController.text.trim()}:${_portController.text.trim()}';
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
                    stackOnNarrow: true,
                    trailing: TextField(
                      controller: _baseUrlController,
                      textAlign: TextAlign.end,
                    ),
                    trailingWidth: 220,
                  ),
                  SettingsRow(
                    title: 'Port',
                    stackOnNarrow: true,
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
                    stackOnNarrow: true,
                    trailing: TextField(
                      controller: _ollamaModelController,
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(
                        hintText: 'e.g. llama3.2',
                      ),
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
                            await repo.updateSettings(
                              current.copyWith(defaultOllamaModel: name),
                            );
                          },
                        ),
                      ),
                    ),
                  SettingsRow(
                    title: 'Connection test',
                    subtitle:
                        _testResult ??
                        'Verify LocalAi can reach the server above.',
                    isForSuccess: _testResult == 'Connected',
                    stackOnNarrow: true,
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
                    subtitle:
                        'Minutes of inactivity before Ollama frees the model from '
                        'memory. Use 0 to keep it loaded forever.',
                    stackOnNarrow: true,
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
                    subtitle:
                        'Applied to every conversation unless overridden.',
                    child: TextField(
                      controller: _systemPromptController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'You are a helpful assistant…',
                      ),
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
                    stackOnNarrow: true,
                    trailing: const _ThemeModeSelector(),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Voice settings',
                children: [
                  SettingsRow(
                    title: 'Default voice',
                    subtitle:
                        'Selected: $_pendingVoiceLabel. Pick a voice below to '
                        'preview it, then save to apply.',
                    stackOnNarrow: true,
                    trailing: _VoiceDropdown(
                      selectedVoice: _pendingTtsVoice,
                      onChanged: (voice) =>
                          setState(() => _pendingTtsVoice = voice ?? const {}),
                    ),
                    trailingWidth: 240,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final isDesktop =
                      MediaQuery.sizeOf(context).width >=
                      AppBreakpoints.desktop;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: isDesktop ? null : double.infinity,
                      height: 45,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 200.0),
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Save settings'),
                        ),
                      ),
                    ),
                  );
                },
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
    return ref
        .watch(installedModelsProvider)
        .maybeWhen(data: (models) => models.isNotEmpty, orElse: () => false);
  }
}

class _InstalledModelDropdown extends ConsumerStatefulWidget {
  const _InstalledModelDropdown({
    required this.selected,
    required this.onPicked,
  });

  final String selected;
  final ValueChanged<String> onPicked;

  @override
  ConsumerState<_InstalledModelDropdown> createState() =>
      _InstalledModelDropdownState();
}

class _InstalledModelDropdownState
    extends ConsumerState<_InstalledModelDropdown> {
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
              hint: const Text(
                'Installed models',
                overflow: TextOverflow.ellipsis,
              ),
              items: [
                for (final name in names)
                  DropdownItem(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
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
        ref
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(selection.first);
      },
    );
  }
}

class _VoiceDropdown extends ConsumerStatefulWidget {
  const _VoiceDropdown({required this.selectedVoice, required this.onChanged});

  final Map<String, String> selectedVoice;
  final ValueChanged<Map<String, String>?> onChanged;

  @override
  ConsumerState<_VoiceDropdown> createState() => _VoiceDropdownState();
}

class _VoiceDropdownState extends ConsumerState<_VoiceDropdown> {
  /// 'system' selects the platform default; 'name|locale' selects a voice.
  final _selectedKey = ValueNotifier<String?>('system');

  @override
  void dispose() {
    _selectedKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voicesAsync = ref.watch(ttsVoicesProvider);
    return voicesAsync.maybeWhen(
      data: (voices) {
        _selectedKey.value = _voiceKey(widget.selectedVoice) ?? 'system';
        if (MediaQuery.sizeOf(context).width < AppBreakpoints.desktop) {
          return _MobileVoicePicker(
            voices: voices,
            selectedVoice: widget.selectedVoice,
            onChanged: widget.onChanged,
          );
        }
        return DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            isDense: true,
            isExpanded: true,
            valueListenable: _selectedKey,
            hint: const Text(
              'System default',
              overflow: TextOverflow.ellipsis,
            ),
            items: [
              DropdownItem(
                value: 'system',
                child: const Text('System default', overflow: TextOverflow.ellipsis),
              ),
              for (final voice in voices)
                DropdownItem(
                  value: _voiceKey(voice) ?? '${voice.hashCode}',
                  child: Text(
                    (voice['name'] ?? 'Unknown voice').isNotEmpty
                        ? '${voice['name']} (${voice['locale'] ?? ''})'
                        : 'Unknown voice',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (key) {
              if (key == null) return;
              if (key == 'system') {
                widget.onChanged(null);
                return;
              }
              final picked = voices.firstWhere(
                (voice) => _voiceKey(voice) == key,
                orElse: () => const {},
              );
              if (picked.isNotEmpty) widget.onChanged(picked);
            },
            buttonStyleData: const ButtonStyleData(
              padding: EdgeInsets.symmetric(horizontal: 12),
              height: 40,
            ),
            dropdownStyleData: DropdownStyleData(
              maxHeight: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      },
      loading: () => const Text(
        'Loading voices…',
        style: TextStyle(fontSize: 12.5),
      ),
      orElse: () => const Text(
        'No selectable voices on this device.',
        style: TextStyle(fontSize: 12.5),
      ),
    );
  }
}

/// Mobile-optimized voice field: a tappable row that opens a modal bottom
/// sheet listing every voice with a per-voice preview button on the leading
/// edge and a "set as selected" control on the trailing edge. Wide layouts
/// keep the plain [DropdownButton2] instead.
class _MobileVoicePicker extends ConsumerWidget {
  const _MobileVoicePicker({
    required this.voices,
    required this.selectedVoice,
    required this.onChanged,
  });

  final List<Map<String, String>> voices;
  final Map<String, String> selectedVoice;
  final ValueChanged<Map<String, String>?> onChanged;

  String get _label {
    final name = selectedVoice['name'];
    final locale = selectedVoice['locale'];
    if (name == null || name.isEmpty) return 'System default';
    return locale == null || locale.isEmpty ? name : '$name ($locale)';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Material(
      color: palette.inputFill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          backgroundColor: palette.cardBackground,
          builder: (_) => _VoicePickerSheet(
            voices: voices,
            selectedVoice: selectedVoice,
            onChanged: onChanged,
          ),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: palette.cardBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary, fontSize: 13.5),
                ),
              ),
              Icon(Icons.expand_more, size: 18, color: palette.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoicePickerSheet extends ConsumerStatefulWidget {
  const _VoicePickerSheet({
    required this.voices,
    required this.selectedVoice,
    required this.onChanged,
  });

  final List<Map<String, String>> voices;
  final Map<String, String> selectedVoice;
  final ValueChanged<Map<String, String>?> onChanged;

  @override
  ConsumerState<_VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _VoicePickerSheetState extends ConsumerState<_VoicePickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static bool _voiceMatches(Map<String, String> voice, String query) {
    final name = (voice['name'] ?? '').toLowerCase();
    final locale = (voice['locale'] ?? '').toLowerCase();
    return name.contains(query) || locale.contains(query);
  }

  List<Map<String, String>> get _filteredVoices {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.voices;
    return [
      for (final voice in widget.voices)
        if (_voiceMatches(voice, query)) voice,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filtered = _filteredVoices;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Text(
                'Choose a voice',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Tap the speaker to preview a voice, then use the check on the '
                'right to set it as the default.',
                style: TextStyle(color: palette.mutedText, fontSize: 12.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search voices',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  Divider(height: 1, color: palette.divider),
                  _VoiceSheetTile(
                    voice: const {},
                    previewKey: _voicePreviewKeyFor(const {}),
                    isSystem: true,
                    selected: widget.selectedVoice.isEmpty,
                    onSelect: () => widget.onChanged(null),
                  ),
                  if (filtered.isNotEmpty) ...[
                    Divider(height: 1, color: palette.divider),
                    for (var i = 0; i < filtered.length; i++) ...[
                      _VoiceSheetTile(
                        voice: filtered[i],
                        previewKey: _voicePreviewKeyFor(filtered[i]),
                        isSystem: false,
                        selected: _voiceKey(widget.selectedVoice) ==
                            _voiceKey(filtered[i]),
                        onSelect: () => widget.onChanged(filtered[i]),
                      ),
                      if (i < filtered.length - 1)
                        Divider(height: 1, color: palette.divider),
                    ],
                  ] else if (widget.voices.isNotEmpty) ...[
                    Divider(height: 1, color: palette.divider),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Text(
                        'No voices match “${_searchController.text.trim()}”.',
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceSheetTile extends ConsumerWidget {
  const _VoiceSheetTile({
    required this.voice,
    required this.previewKey,
    required this.isSystem,
    required this.selected,
    required this.onSelect,
  });

  final Map<String, String> voice;
  final String previewKey;
  final bool isSystem;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final speech = ref.watch(speechControllerProvider);
    final locale = voice['locale']?.trim() ?? '';
    final previewing = speech.isSpeaking && speech.speakingKey == previewKey;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: IconButton(
        onPressed: previewing
            ? () => ref.read(speechControllerProvider.notifier).stop()
            : () => ref
                  .read(speechControllerProvider.notifier)
                  .speak(_voiceSampleParagraph, key: previewKey, voice: voice),
        icon: Icon(previewing ? Icons.stop : Icons.volume_up, size: 20),
        color: previewing ? palette.accent : palette.mutedText,
        tooltip: previewing ? 'Stop preview' : 'Test voice',
      ),
      title: Text(
        isSystem ? 'System default' : (voice['name'] ?? 'Unknown voice'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: isSystem
          ? const Text('Let the device pick the voice')
          : (locale.isEmpty ? null : Text(locale)),
      trailing: IconButton(
        onPressed: () {
          onSelect();
          Navigator.of(context).pop();
        },
        icon: Icon(
          selected ? Icons.check_circle : Icons.check_circle_outline,
          size: 22,
        ),
        color: selected ? palette.accent : palette.mutedText,
        tooltip: selected ? 'Currently selected' : 'Set as selected voice',
      ),
    );
  }
}

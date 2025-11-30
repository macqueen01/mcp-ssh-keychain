import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';

/// Dialog for configuring application settings
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  String? _selectedEditorId;
  bool _autoOpen = true;
  String? _customPath;
  String? _customName;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _selectedEditorId = settings.defaultEditorId;
    _autoOpen = settings.autoOpenAfterDownload;
    _customPath = settings.customEditorPath;
    _customName = settings.customEditorName;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return AlertDialog(
            title: const Text('Settings'),
            content: const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return AlertDialog(
          title: Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedSettings02, size: 24, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Settings'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Default Editor Section
                  _buildSectionHeader('Default Editor'),
                  const SizedBox(height: 8),
                  _buildEditorSelector(provider),

                  const SizedBox(height: 24),

                  // Auto-open Section
                  _buildSectionHeader('Behavior'),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Auto-open after download'),
                    subtitle: const Text(
                      'Automatically open files in editor after downloading',
                    ),
                    value: _autoOpen,
                    onChanged: (value) {
                      setState(() => _autoOpen = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 16),

                  // Download Path Section
                  _buildSectionHeader('Download Location'),
                  const SizedBox(height: 8),
                  Text(
                    provider.settings.tempDownloadPath,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _saveSettings(provider),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildEditorSelector(SettingsProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final installedEditors = provider.installedEditors;

    // Build list of editor options
    final List<DropdownMenuItem<String>> items = [];

    // Add installed editors
    for (final editor in installedEditors) {
      items.add(DropdownMenuItem(
        value: editor.id,
        child: Row(
          children: [
            _getEditorIcon(editor.id),
            const SizedBox(width: 8),
            Text(editor.name),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Installed',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ));
    }

    // Add not installed editors (greyed out info)
    for (final entry in KnownEditors.all.entries) {
      if (!installedEditors.any((e) => e.id == entry.key)) {
        items.add(DropdownMenuItem(
          value: entry.key,
          child: Row(
            children: [
              _getEditorIcon(entry.key),
              const SizedBox(width: 8),
              Text(
                entry.value.name,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ));
      }
    }

    // Add custom option
    items.add(DropdownMenuItem(
      value: 'custom',
      child: Row(
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedAppStore, size: 20, color: colorScheme.onSurface),
          const SizedBox(width: 8),
          const Text('Custom...'),
        ],
      ),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedEditorId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: items,
          onChanged: (value) {
            setState(() => _selectedEditorId = value);
            if (value == 'custom') {
              _pickCustomEditor();
            }
          },
        ),
        if (_selectedEditorId == 'custom' && _customPath != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customName ?? 'Custom Editor',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _customPath!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit01, size: 20, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: _pickCustomEditor,
                  tooltip: 'Change',
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _getEditorIcon(String editorId) {
    List<List<dynamic>> icon;
    Color? color;

    switch (editorId) {
      case 'vscode':
        icon = HugeIcons.strokeRoundedSourceCode;
        color = Colors.blue;
        break;
      case 'cursor':
        icon = HugeIcons.strokeRoundedCommandLine;
        color = Colors.purple;
        break;
      case 'sublime':
        icon = HugeIcons.strokeRoundedPencilEdit01;
        color = Colors.orange;
        break;
      case 'atom':
        icon = HugeIcons.strokeRoundedAtom01;
        color = Colors.green;
        break;
      case 'zed':
        icon = HugeIcons.strokeRoundedFlashOff;
        color = Colors.amber;
        break;
      case 'nova':
        icon = HugeIcons.strokeRoundedStar;
        color = Colors.cyan;
        break;
      default:
        icon = HugeIcons.strokeRoundedFile01;
        color = null;
    }

    return HugeIcon(icon: icon, size: 20, color: color ?? Theme.of(context).colorScheme.onSurface);
  }

  Future<void> _pickCustomEditor() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['app'],
      dialogTitle: 'Select Editor Application',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = path.split('/').last.replaceAll('.app', '');

      setState(() {
        _customPath = path;
        _customName = name;
        _selectedEditorId = 'custom';
      });
    }
  }

  Future<void> _saveSettings(SettingsProvider provider) async {
    try {
      if (_selectedEditorId == 'custom' && _customPath != null) {
        await provider.setCustomEditor(_customPath!, _customName ?? 'Custom');
      } else if (_selectedEditorId != null) {
        await provider.setDefaultEditor(_selectedEditorId!);
      }

      await provider.setAutoOpenAfterDownload(_autoOpen);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

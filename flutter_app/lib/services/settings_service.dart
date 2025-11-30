import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Service for loading and saving application settings
class SettingsService {
  static const String _keyDefaultEditor = 'default_editor_id';
  static const String _keyCustomEditorPath = 'custom_editor_path';
  static const String _keyCustomEditorName = 'custom_editor_name';
  static const String _keyTempDownloadPath = 'temp_download_path';
  static const String _keyAutoOpen = 'auto_open_after_download';
  static const String _keyEditorsByExtension = 'editors_by_extension';

  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Load settings from persistent storage
  Future<AppSettings> load() async {
    if (_prefs == null) {
      await init();
    }

    final defaultEditorId =
        _prefs!.getString(_keyDefaultEditor) ?? 'vscode';
    final customEditorPath = _prefs!.getString(_keyCustomEditorPath);
    final customEditorName = _prefs!.getString(_keyCustomEditorName);
    final tempDownloadPath = _prefs!.getString(_keyTempDownloadPath) ?? '';
    final autoOpen = _prefs!.getBool(_keyAutoOpen) ?? true;

    Map<String, String> editorsByExtension = {};
    final extensionsJson = _prefs!.getString(_keyEditorsByExtension);
    if (extensionsJson != null) {
      final decoded = jsonDecode(extensionsJson) as Map<String, dynamic>;
      editorsByExtension =
          decoded.map((key, value) => MapEntry(key, value as String));
    }

    return AppSettings(
      defaultEditorId: defaultEditorId,
      customEditorPath: customEditorPath,
      customEditorName: customEditorName,
      tempDownloadPath: tempDownloadPath,
      autoOpenAfterDownload: autoOpen,
      editorsByExtension: editorsByExtension,
    );
  }

  /// Save settings to persistent storage
  Future<void> save(AppSettings settings) async {
    if (_prefs == null) {
      await init();
    }

    await _prefs!.setString(_keyDefaultEditor, settings.defaultEditorId);

    if (settings.customEditorPath != null) {
      await _prefs!.setString(_keyCustomEditorPath, settings.customEditorPath!);
    } else {
      await _prefs!.remove(_keyCustomEditorPath);
    }

    if (settings.customEditorName != null) {
      await _prefs!.setString(_keyCustomEditorName, settings.customEditorName!);
    } else {
      await _prefs!.remove(_keyCustomEditorName);
    }

    await _prefs!.setString(_keyTempDownloadPath, settings.tempDownloadPath);
    await _prefs!.setBool(_keyAutoOpen, settings.autoOpenAfterDownload);

    if (settings.editorsByExtension.isNotEmpty) {
      await _prefs!.setString(
          _keyEditorsByExtension, jsonEncode(settings.editorsByExtension));
    } else {
      await _prefs!.remove(_keyEditorsByExtension);
    }
  }

  /// Detect which known editors are installed on the system
  Future<List<EditorInfo>> detectInstalledEditors() async {
    final installed = <EditorInfo>[];

    for (final editor in KnownEditors.all.values) {
      if (await _isEditorInstalled(editor)) {
        installed.add(editor);
      }
    }

    return installed;
  }

  /// Check if a specific editor is installed
  Future<bool> _isEditorInstalled(EditorInfo editor) async {
    if (Platform.isMacOS) {
      // Check if the app exists
      final appDir = Directory(editor.macPath);
      if (await appDir.exists()) {
        return true;
      }

      // Check if the command is available
      try {
        final result = await Process.run('which', [editor.macCommand.split(' ').first]);
        return result.exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    return false;
  }

  /// Get the default temp download path
  Future<String> getDefaultTempPath() async {
    final tempDir = await getTemporaryDirectory();
    final mcpDir = Directory('${tempDir.path}/mcp_file_manager');
    if (!await mcpDir.exists()) {
      await mcpDir.create(recursive: true);
    }
    return mcpDir.path;
  }

  /// Validate that an editor path exists and is executable
  Future<bool> validateEditorPath(String path) async {
    if (Platform.isMacOS) {
      // If it's an .app bundle
      if (path.endsWith('.app')) {
        return await Directory(path).exists();
      }

      // If it's a direct executable
      final file = File(path);
      if (await file.exists()) {
        return true;
      }

      // Check if it's a command in PATH
      try {
        final result = await Process.run('which', [path]);
        return result.exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    return false;
  }
}

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';

/// Provider for application settings
class SettingsProvider extends ChangeNotifier {
  final SettingsService _service = SettingsService();

  AppSettings _settings = const AppSettings();
  List<EditorInfo> _installedEditors = [];
  bool _isLoading = true;
  String? _error;

  AppSettings get settings => _settings;
  List<EditorInfo> get installedEditors => _installedEditors;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Current editor info
  EditorInfo? get currentEditor => _settings.currentEditor;

  /// Initialize the provider
  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.init();
      _settings = await _service.load();

      // Set default temp path if not configured
      if (_settings.tempDownloadPath.isEmpty) {
        final defaultPath = await _service.getDefaultTempPath();
        _settings = _settings.copyWith(tempDownloadPath: defaultPath);
        await _service.save(_settings);
      }

      // Detect installed editors
      _installedEditors = await _service.detectInstalledEditors();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update the default editor
  Future<void> setDefaultEditor(String editorId) async {
    _settings = _settings.copyWith(defaultEditorId: editorId);
    await _service.save(_settings);
    notifyListeners();
  }

  /// Set a custom editor path
  Future<void> setCustomEditor(String path, String name) async {
    final isValid = await _service.validateEditorPath(path);
    if (!isValid) {
      throw Exception('Invalid editor path: $path');
    }

    _settings = _settings.copyWith(
      defaultEditorId: 'custom',
      customEditorPath: path,
      customEditorName: name,
    );
    await _service.save(_settings);
    notifyListeners();
  }

  /// Update temp download path
  Future<void> setTempDownloadPath(String path) async {
    _settings = _settings.copyWith(tempDownloadPath: path);
    await _service.save(_settings);
    notifyListeners();
  }

  /// Toggle auto-open setting
  Future<void> setAutoOpenAfterDownload(bool value) async {
    _settings = _settings.copyWith(autoOpenAfterDownload: value);
    await _service.save(_settings);
    notifyListeners();
  }

  /// Set editor for a specific extension
  Future<void> setEditorForExtension(String extension, String editorId) async {
    final newMap = Map<String, String>.from(_settings.editorsByExtension);
    newMap[extension.toLowerCase()] = editorId;
    _settings = _settings.copyWith(editorsByExtension: newMap);
    await _service.save(_settings);
    notifyListeners();
  }

  /// Remove extension-specific editor
  Future<void> removeEditorForExtension(String extension) async {
    final newMap = Map<String, String>.from(_settings.editorsByExtension);
    newMap.remove(extension.toLowerCase());
    _settings = _settings.copyWith(editorsByExtension: newMap);
    await _service.save(_settings);
    notifyListeners();
  }

  /// Get editor for a file (checks extension overrides)
  EditorInfo? getEditorForFile(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : '';

    if (ext.isNotEmpty) {
      return _settings.getEditorForExtension(ext);
    }

    return currentEditor;
  }

  /// Refresh installed editors list
  Future<void> refreshInstalledEditors() async {
    _installedEditors = await _service.detectInstalledEditors();
    notifyListeners();
  }
}

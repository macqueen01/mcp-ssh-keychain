/// Represents an editor application that can open files
class EditorInfo {
  final String id;
  final String name;
  final String macCommand;
  final String macPath;

  const EditorInfo({
    required this.id,
    required this.name,
    required this.macCommand,
    required this.macPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'macCommand': macCommand,
        'macPath': macPath,
      };

  factory EditorInfo.fromJson(Map<String, dynamic> json) => EditorInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        macCommand: json['macCommand'] as String,
        macPath: json['macPath'] as String,
      );
}

/// Known editors with their configurations
class KnownEditors {
  static const Map<String, EditorInfo> all = {
    'vscode': EditorInfo(
      id: 'vscode',
      name: 'Visual Studio Code',
      macCommand: 'code',
      macPath: '/Applications/Visual Studio Code.app',
    ),
    'cursor': EditorInfo(
      id: 'cursor',
      name: 'Cursor',
      macCommand: 'cursor',
      macPath: '/Applications/Cursor.app',
    ),
    'sublime': EditorInfo(
      id: 'sublime',
      name: 'Sublime Text',
      macCommand: 'subl',
      macPath: '/Applications/Sublime Text.app',
    ),
    'atom': EditorInfo(
      id: 'atom',
      name: 'Atom',
      macCommand: 'atom',
      macPath: '/Applications/Atom.app',
    ),
    'textmate': EditorInfo(
      id: 'textmate',
      name: 'TextMate',
      macCommand: 'mate',
      macPath: '/Applications/TextMate.app',
    ),
    'bbedit': EditorInfo(
      id: 'bbedit',
      name: 'BBEdit',
      macCommand: 'bbedit',
      macPath: '/Applications/BBEdit.app',
    ),
    'nova': EditorInfo(
      id: 'nova',
      name: 'Nova',
      macCommand: 'nova',
      macPath: '/Applications/Nova.app',
    ),
    'zed': EditorInfo(
      id: 'zed',
      name: 'Zed',
      macCommand: 'zed',
      macPath: '/Applications/Zed.app',
    ),
    'textedit': EditorInfo(
      id: 'textedit',
      name: 'TextEdit',
      macCommand: 'open -a TextEdit',
      macPath: '/System/Applications/TextEdit.app',
    ),
  };
}

/// Application settings model
class AppSettings {
  /// Default editor ID (e.g., "vscode", "cursor", "sublime")
  final String defaultEditorId;

  /// Custom editor path if not using a known editor
  final String? customEditorPath;

  /// Custom editor name for display
  final String? customEditorName;

  /// Where to download files temporarily
  final String tempDownloadPath;

  /// Auto-open file after download or ask user
  final bool autoOpenAfterDownload;

  /// Per-extension editor overrides (extension -> editorId)
  final Map<String, String> editorsByExtension;

  const AppSettings({
    this.defaultEditorId = 'vscode',
    this.customEditorPath,
    this.customEditorName,
    this.tempDownloadPath = '',
    this.autoOpenAfterDownload = true,
    this.editorsByExtension = const {},
  });

  AppSettings copyWith({
    String? defaultEditorId,
    String? customEditorPath,
    String? customEditorName,
    String? tempDownloadPath,
    bool? autoOpenAfterDownload,
    Map<String, String>? editorsByExtension,
  }) {
    return AppSettings(
      defaultEditorId: defaultEditorId ?? this.defaultEditorId,
      customEditorPath: customEditorPath ?? this.customEditorPath,
      customEditorName: customEditorName ?? this.customEditorName,
      tempDownloadPath: tempDownloadPath ?? this.tempDownloadPath,
      autoOpenAfterDownload:
          autoOpenAfterDownload ?? this.autoOpenAfterDownload,
      editorsByExtension: editorsByExtension ?? this.editorsByExtension,
    );
  }

  /// Get the editor info for the current settings
  EditorInfo? get currentEditor {
    if (defaultEditorId == 'custom' && customEditorPath != null) {
      return EditorInfo(
        id: 'custom',
        name: customEditorName ?? 'Custom Editor',
        macCommand: customEditorPath!,
        macPath: customEditorPath!,
      );
    }
    return KnownEditors.all[defaultEditorId];
  }

  /// Get the editor for a specific file extension
  EditorInfo? getEditorForExtension(String extension) {
    final editorId = editorsByExtension[extension.toLowerCase()];
    if (editorId != null) {
      return KnownEditors.all[editorId];
    }
    return currentEditor;
  }
}

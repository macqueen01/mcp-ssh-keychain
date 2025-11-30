# Plan: Settings with Default Editor for File Opening

## Overview

Add a Settings screen to configure default applications for opening remote files. When double-clicking a file, the app will download it to a temp folder and open it with the configured editor.

## Current State

- Double-click on files triggers `FileBrowserProvider.open()`
- Files (non-directories) have a TODO at line 184: `// TODO: Handle file opening`
- `path_provider` and `file_picker` dependencies already present
- Pattern: Providers with ChangeNotifier, dialogs for user input

## Implementation Plan

### Phase 1: Settings Provider & Model

**1.1 Create `lib/models/app_settings.dart`**
```dart
class AppSettings {
  String defaultEditor;           // e.g., "code", "cursor", "subl"
  String defaultEditorPath;       // Full path to executable
  Map<String, String> editorsByExtension; // Extension overrides
  String tempDownloadPath;        // Where to download files
  bool autoOpenAfterDownload;     // Auto-open or ask
}
```

**1.2 Create `lib/services/settings_service.dart`**
- Load/save settings using `shared_preferences`
- Default editors detection (VS Code, Cursor, Sublime, etc.)
- Methods: `load()`, `save()`, `getEditorForFile(filename)`

**1.3 Create `lib/providers/settings_provider.dart`**
- Wrap SettingsService with ChangeNotifier
- Expose settings to UI
- Handle persistence

### Phase 2: Settings UI

**2.1 Create `lib/screens/settings_screen.dart`**
- General settings section
- Default editor dropdown with "Browse..." option
- Extension mappings table (optional, v2)
- Download path configuration

**2.2 Create `lib/widgets/settings_dialog.dart`**
- Modal dialog version for quick access
- Shows only essential settings

**2.3 Update `lib/screens/home_screen.dart`**
- Add Settings icon button in toolbar
- Navigate to SettingsScreen or show SettingsDialog

### Phase 3: File Opening Logic

**3.1 Create `lib/services/file_opener_service.dart`**
```dart
class FileOpenerService {
  Future<void> openRemoteFile({
    required McpClient client,
    required String server,
    required String remotePath,
    required String localTempPath,
    required String editorCommand,
  });
}
```
- Download file via MCP `ssh_download`
- Launch editor with `Process.run()` or `url_launcher`
- Handle errors gracefully

**3.2 Update `lib/providers/file_browser_provider.dart`**
- Inject SettingsProvider or FileOpenerService
- Replace TODO with actual file opening logic
- Show download progress (optional)

### Phase 4: Platform Integration

**4.1 macOS specific**
- Use `open -a "Visual Studio Code" file.txt` pattern
- Or direct path: `/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code`

**4.2 Editor detection**
```dart
Map<String, EditorInfo> knownEditors = {
  'vscode': EditorInfo(
    name: 'Visual Studio Code',
    macCommand: 'code',
    macPath: '/Applications/Visual Studio Code.app',
  ),
  'cursor': EditorInfo(
    name: 'Cursor',
    macCommand: 'cursor',
    macPath: '/Applications/Cursor.app',
  ),
  'sublime': EditorInfo(
    name: 'Sublime Text',
    macCommand: 'subl',
    macPath: '/Applications/Sublime Text.app',
  ),
  // ...
};
```

## Files to Create

1. `lib/models/app_settings.dart`
2. `lib/services/settings_service.dart`
3. `lib/services/file_opener_service.dart`
4. `lib/providers/settings_provider.dart`
5. `lib/screens/settings_screen.dart`
6. `lib/widgets/settings_dialog.dart`

## Files to Modify

1. `lib/main.dart` - Add SettingsProvider
2. `lib/screens/home_screen.dart` - Add settings button
3. `lib/providers/file_browser_provider.dart` - Implement file opening
4. `pubspec.yaml` - Add `shared_preferences`, `url_launcher`

## Dependencies to Add

```yaml
dependencies:
  shared_preferences: ^2.2.2
  url_launcher: ^6.2.1
```

## Implementation Order

1. Add dependencies to pubspec.yaml
2. Create models/app_settings.dart
3. Create services/settings_service.dart
4. Create providers/settings_provider.dart
5. Create widgets/settings_dialog.dart
6. Update main.dart with SettingsProvider
7. Update home_screen.dart with settings button
8. Create services/file_opener_service.dart
9. Update file_browser_provider.dart with file opening
10. Test end-to-end flow

## Testing Checklist

- [ ] Settings persist after app restart
- [ ] Can select different editors
- [ ] File downloads correctly from remote
- [ ] Editor opens with downloaded file
- [ ] Error handling for network issues
- [ ] Error handling for missing editor

## Future Enhancements (v2)

- Per-extension editor mapping
- Recent editors history
- Inline file preview for text files
- Auto-sync modified files back to server

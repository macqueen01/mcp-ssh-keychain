import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_file_manager/models/app_settings.dart';

void main() {
  group('EditorInfo', () {
    test('should create EditorInfo with required fields', () {
      const editor = EditorInfo(
        id: 'vscode',
        name: 'Visual Studio Code',
        macCommand: 'code',
        macPath: '/Applications/Visual Studio Code.app',
      );

      expect(editor.id, 'vscode');
      expect(editor.name, 'Visual Studio Code');
      expect(editor.macCommand, 'code');
      expect(editor.macPath, '/Applications/Visual Studio Code.app');
    });

    test('should serialize to JSON correctly', () {
      const editor = EditorInfo(
        id: 'cursor',
        name: 'Cursor',
        macCommand: 'cursor',
        macPath: '/Applications/Cursor.app',
      );

      final json = editor.toJson();

      expect(json['id'], 'cursor');
      expect(json['name'], 'Cursor');
      expect(json['macCommand'], 'cursor');
      expect(json['macPath'], '/Applications/Cursor.app');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'sublime',
        'name': 'Sublime Text',
        'macCommand': 'subl',
        'macPath': '/Applications/Sublime Text.app',
      };

      final editor = EditorInfo.fromJson(json);

      expect(editor.id, 'sublime');
      expect(editor.name, 'Sublime Text');
      expect(editor.macCommand, 'subl');
      expect(editor.macPath, '/Applications/Sublime Text.app');
    });
  });

  group('KnownEditors', () {
    test('should contain vscode editor', () {
      expect(KnownEditors.all.containsKey('vscode'), isTrue);
      expect(KnownEditors.all['vscode']!.name, 'Visual Studio Code');
    });

    test('should contain cursor editor', () {
      expect(KnownEditors.all.containsKey('cursor'), isTrue);
      expect(KnownEditors.all['cursor']!.name, 'Cursor');
    });

    test('should contain all expected editors', () {
      final expectedEditors = [
        'vscode',
        'cursor',
        'sublime',
        'atom',
        'textmate',
        'bbedit',
        'nova',
        'zed',
        'textedit',
      ];

      for (final editorId in expectedEditors) {
        expect(
          KnownEditors.all.containsKey(editorId),
          isTrue,
          reason: 'Should contain editor: $editorId',
        );
      }
    });

    test('should have valid paths for all editors', () {
      for (final entry in KnownEditors.all.entries) {
        expect(
          entry.value.macPath.isNotEmpty,
          isTrue,
          reason: '${entry.key} should have a valid macPath',
        );
        expect(
          entry.value.macCommand.isNotEmpty,
          isTrue,
          reason: '${entry.key} should have a valid macCommand',
        );
      }
    });
  });

  group('AppSettings', () {
    test('should create with default values', () {
      const settings = AppSettings();

      expect(settings.defaultEditorId, 'vscode');
      expect(settings.customEditorPath, isNull);
      expect(settings.customEditorName, isNull);
      expect(settings.tempDownloadPath, '');
      expect(settings.autoOpenAfterDownload, isTrue);
      expect(settings.editorsByExtension, isEmpty);
    });

    test('should create with custom values', () {
      const settings = AppSettings(
        defaultEditorId: 'cursor',
        customEditorPath: '/custom/path',
        customEditorName: 'Custom Editor',
        tempDownloadPath: '/tmp/downloads',
        autoOpenAfterDownload: false,
        editorsByExtension: {'md': 'typora'},
      );

      expect(settings.defaultEditorId, 'cursor');
      expect(settings.customEditorPath, '/custom/path');
      expect(settings.customEditorName, 'Custom Editor');
      expect(settings.tempDownloadPath, '/tmp/downloads');
      expect(settings.autoOpenAfterDownload, isFalse);
      expect(settings.editorsByExtension['md'], 'typora');
    });

    group('copyWith', () {
      test('should copy with new defaultEditorId', () {
        const original = AppSettings(defaultEditorId: 'vscode');
        final copied = original.copyWith(defaultEditorId: 'cursor');

        expect(copied.defaultEditorId, 'cursor');
        expect(copied.autoOpenAfterDownload, original.autoOpenAfterDownload);
      });

      test('should copy with new autoOpenAfterDownload', () {
        const original = AppSettings(autoOpenAfterDownload: true);
        final copied = original.copyWith(autoOpenAfterDownload: false);

        expect(copied.autoOpenAfterDownload, isFalse);
        expect(copied.defaultEditorId, original.defaultEditorId);
      });

      test('should preserve original values when not specified', () {
        const original = AppSettings(
          defaultEditorId: 'sublime',
          tempDownloadPath: '/custom/path',
          autoOpenAfterDownload: false,
        );
        final copied = original.copyWith(defaultEditorId: 'atom');

        expect(copied.defaultEditorId, 'atom');
        expect(copied.tempDownloadPath, '/custom/path');
        expect(copied.autoOpenAfterDownload, isFalse);
      });
    });

    group('currentEditor', () {
      test('should return known editor when using known editorId', () {
        const settings = AppSettings(defaultEditorId: 'vscode');

        final editor = settings.currentEditor;

        expect(editor, isNotNull);
        expect(editor!.id, 'vscode');
        expect(editor.name, 'Visual Studio Code');
      });

      test('should return custom editor when using custom editorId', () {
        const settings = AppSettings(
          defaultEditorId: 'custom',
          customEditorPath: '/Applications/MyEditor.app',
          customEditorName: 'My Editor',
        );

        final editor = settings.currentEditor;

        expect(editor, isNotNull);
        expect(editor!.id, 'custom');
        expect(editor.name, 'My Editor');
        expect(editor.macPath, '/Applications/MyEditor.app');
      });

      test('should return null when custom without path', () {
        const settings = AppSettings(
          defaultEditorId: 'custom',
          customEditorPath: null,
        );

        final editor = settings.currentEditor;

        expect(editor, isNull);
      });

      test('should return null for unknown editorId', () {
        const settings = AppSettings(defaultEditorId: 'unknown_editor');

        final editor = settings.currentEditor;

        expect(editor, isNull);
      });
    });

    group('getEditorForExtension', () {
      test('should return extension-specific editor when configured', () {
        const settings = AppSettings(
          defaultEditorId: 'vscode',
          editorsByExtension: {'md': 'sublime'},
        );

        final editor = settings.getEditorForExtension('md');

        expect(editor, isNotNull);
        expect(editor!.id, 'sublime');
      });

      test('should return default editor when extension not configured', () {
        const settings = AppSettings(
          defaultEditorId: 'cursor',
          editorsByExtension: {'md': 'sublime'},
        );

        final editor = settings.getEditorForExtension('txt');

        expect(editor, isNotNull);
        expect(editor!.id, 'cursor');
      });

      test('should be case-insensitive for extension lookup', () {
        const settings = AppSettings(
          defaultEditorId: 'vscode',
          editorsByExtension: {'md': 'sublime'},
        );

        // Lowercase matches the configured extension
        final editorLower = settings.getEditorForExtension('md');
        expect(editorLower!.id, 'sublime');

        // Uppercase also matches - implementation converts to lowercase
        final editorUpper = settings.getEditorForExtension('MD');
        expect(editorUpper!.id, 'sublime');
      });
    });
  });
}

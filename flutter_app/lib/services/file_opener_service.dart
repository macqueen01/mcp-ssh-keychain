import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../mcp/mcp_client.dart';
import '../models/app_settings.dart';

/// Result of a file download and open operation
class FileOpenResult {
  final bool success;
  final String? localPath;
  final String? error;

  const FileOpenResult({
    required this.success,
    this.localPath,
    this.error,
  });
}

/// Service for downloading remote files and opening them with an editor
class FileOpenerService {
  /// Download a remote file to local temp directory
  Future<FileOpenResult> downloadFile({
    required McpClient client,
    required String server,
    required String remotePath,
    required String tempDir,
  }) async {
    try {
      // Create temp directory if it doesn't exist
      final dir = Directory(tempDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Generate local path
      final fileName = path.basename(remotePath);
      final localPath = path.join(tempDir, server, fileName);

      // Create server subdirectory
      final serverDir = Directory(path.dirname(localPath));
      if (!await serverDir.exists()) {
        await serverDir.create(recursive: true);
      }

      // Download the file
      final result = await client.downloadFile(
        server: server,
        remotePath: remotePath,
        localPath: localPath,
      );

      if (result['success'] == true) {
        return FileOpenResult(
          success: true,
          localPath: localPath,
        );
      } else {
        return FileOpenResult(
          success: false,
          error: result['error']?.toString() ?? 'Download failed',
        );
      }
    } catch (e) {
      return FileOpenResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Open a local file with the specified editor
  Future<bool> openWithEditor({
    required String filePath,
    required EditorInfo editor,
  }) async {
    try {
      if (Platform.isMacOS) {
        return await _openOnMac(filePath, editor);
      }
      // Add Linux/Windows support here if needed
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _openOnMac(String filePath, EditorInfo editor) async {
    try {
      // First try using the command if available
      if (editor.macCommand.isNotEmpty) {
        final cmdParts = editor.macCommand.split(' ');

        if (cmdParts.length == 1) {
          // Simple command like 'code' or 'cursor'
          final result = await Process.run(cmdParts[0], [filePath]);
          if (result.exitCode == 0) {
            return true;
          }
        } else {
          // Complex command like 'open -a TextEdit'
          final args = [...cmdParts.skip(1), filePath];
          final result = await Process.run(cmdParts[0], args);
          if (result.exitCode == 0) {
            return true;
          }
        }
      }

      // Fallback: use 'open -a' with the app path
      if (editor.macPath.isNotEmpty) {
        final appName = path.basenameWithoutExtension(editor.macPath);
        final result = await Process.run('open', ['-a', appName, filePath]);
        if (result.exitCode == 0) {
          return true;
        }
      }

      // Last resort: just use 'open' to open with default app
      final result = await Process.run('open', [filePath]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Download and open a remote file
  Future<FileOpenResult> downloadAndOpen({
    required McpClient client,
    required String server,
    required String remotePath,
    required String tempDir,
    required EditorInfo editor,
  }) async {
    // Download the file
    final downloadResult = await downloadFile(
      client: client,
      server: server,
      remotePath: remotePath,
      tempDir: tempDir,
    );

    if (!downloadResult.success) {
      return downloadResult;
    }

    // Open with editor
    final opened = await openWithEditor(
      filePath: downloadResult.localPath!,
      editor: editor,
    );

    if (opened) {
      return downloadResult;
    } else {
      return FileOpenResult(
        success: false,
        localPath: downloadResult.localPath,
        error: 'Failed to open file with ${editor.name}',
      );
    }
  }

  /// Get default temp directory for downloads
  Future<String> getDefaultTempDir() async {
    final tempDir = await getTemporaryDirectory();
    return path.join(tempDir.path, 'mcp_file_manager', 'downloads');
  }
}

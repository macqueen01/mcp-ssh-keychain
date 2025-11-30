import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mcp_file_manager/mcp/mcp_client.dart';
import 'package:mcp_file_manager/providers/connection_provider.dart';
import 'package:mcp_file_manager/providers/settings_provider.dart';
import 'package:mcp_file_manager/providers/transfer_provider.dart';

// Re-export for convenience
export 'package:mcp_file_manager/providers/transfer_provider.dart' show TransferStatus, TransferItem;

import '../mocks/mock_mcp_client.dart';

/// Helper to pump a widget with all required providers
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  MockMcpClient? mockClient,
  ConnectionProvider? connectionProvider,
  SettingsProvider? settingsProvider,
  TransferProvider? transferProvider,
}) async {
  final client = mockClient ?? MockMcpClient();

  await tester.pumpWidget(
    MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionProvider>(
            create: (_) => connectionProvider ?? ConnectionProvider(),
          ),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => settingsProvider ?? SettingsProvider(),
          ),
          ChangeNotifierProvider<TransferProvider>(
            create: (_) => transferProvider ?? TransferProvider(client: client),
          ),
        ],
        child: child,
      ),
    ),
  );
}

/// Helper to pump a widget with minimal dependencies
Future<void> pumpWidget(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

/// Create a mock SshServer for testing
SshServer createMockServer({
  String name = 'test_server',
  String host = 'test.example.com',
  String user = 'testuser',
  int port = 22,
  String? defaultDir,
}) {
  return SshServer(
    name: name,
    host: host,
    user: user,
    port: port,
    defaultDir: defaultDir,
  );
}

/// Create a mock RemoteFile for testing
RemoteFile createMockFile({
  String name = 'test.txt',
  bool isDirectory = false,
  bool isLink = false,
  String permissions = '-rw-r--r--',
  int size = 1024,
  String modified = '2024-01-01 12:00:00',
}) {
  return RemoteFile(
    name: name,
    isDirectory: isDirectory,
    isLink: isLink,
    permissions: permissions,
    size: size,
    modified: modified,
  );
}

/// Create a list of mock files for testing
List<RemoteFile> createMockFileList({
  int fileCount = 5,
  int dirCount = 2,
  bool includeHidden = false,
}) {
  final files = <RemoteFile>[];

  // Add directories
  for (var i = 0; i < dirCount; i++) {
    files.add(createMockFile(
      name: 'dir_$i',
      isDirectory: true,
      permissions: 'drwxr-xr-x',
    ));
  }

  // Add files
  for (var i = 0; i < fileCount; i++) {
    files.add(createMockFile(
      name: 'file_$i.txt',
      size: 1024 * (i + 1),
    ));
  }

  // Add hidden files if requested
  if (includeHidden) {
    files.add(createMockFile(name: '.hidden_file'));
    files.add(createMockFile(
      name: '.hidden_dir',
      isDirectory: true,
      permissions: 'drwxr-xr-x',
    ));
  }

  return files;
}

/// Create a FileListResult for testing
FileListResult createMockFileListResult({
  String path = '/home/user',
  List<RemoteFile>? files,
}) {
  return FileListResult(
    path: path,
    files: files ?? createMockFileList(),
  );
}

/// Extension to find widgets by key
extension WidgetTesterExtensions on WidgetTester {
  /// Find a widget by its key
  Finder findByKey(String key) => find.byKey(Key(key));

  /// Tap a widget by its key
  Future<void> tapByKey(String key) async {
    await tap(findByKey(key));
    await pumpAndSettle();
  }

  /// Enter text in a field by its key
  Future<void> enterTextByKey(String key, String text) async {
    await enterText(findByKey(key), text);
    await pumpAndSettle();
  }
}

/// Matcher for checking if a widget is visible
Matcher isVisible = isA<Widget>();

/// Matcher for checking TransferStatus
Matcher hasTransferStatus(TransferStatus status) {
  return predicate<TransferItem>(
    (item) => item.status == status,
    'has status $status',
  );
}

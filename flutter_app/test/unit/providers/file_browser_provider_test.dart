import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_file_manager/mcp/mcp_client.dart';
import 'package:mcp_file_manager/providers/file_browser_provider.dart';

import '../../mocks/mock_mcp_client.dart';
import '../../helpers/test_helpers.dart';

void main() {
  late MockMcpClient mockClient;
  late FileBrowserProvider provider;

  setUp(() {
    mockClient = MockMcpClient();
    mockClient.mockFileListResult = createMockFileListResult();
  });

  tearDown(() {
    provider.dispose();
    mockClient.dispose();
  });

  group('FileBrowserProvider', () {
    group('initialization', () {
      test('should initialize with default values', () {
        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );

        expect(provider.currentPath, '~');
        expect(provider.serverName, 'test_server');
        expect(provider.isLoading, isTrue); // starts loading
        expect(provider.showHidden, isFalse);
        expect(provider.selectedFiles, isEmpty);
      });

      test('should initialize with custom initial path', () {
        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
          initialPath: '/var/www',
        );

        expect(provider.currentPath, '/var/www');
      });

      test('should call listFiles on initialization', () async {
        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );

        // Wait for async initialization
        await Future.delayed(const Duration(milliseconds: 100));

        expect(mockClient.verifyCall('listFiles'), isTrue);
      });
    });

    group('refresh', () {
      test('should update files from server', () async {
        final files = [
          createMockFile(name: 'new_file.txt'),
        ];
        mockClient.mockFileListResult = FileListResult(
          path: '/home/user',
          files: files,
        );

        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(provider.files.length, 1);
        expect(provider.files[0].name, 'new_file.txt');
      });

      test('should set error on failure', () async {
        mockClient.mockFileListResult = null;

        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );

        // Force an error by calling refresh without proper mock
        try {
          await provider.refresh();
        } catch (_) {}

        // Provider should handle error gracefully
        expect(provider.isLoading, isFalse);
      });
    });

    group('navigation', () {
      setUp(() {
        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );
      });

      test('should navigate to new path', () async {
        mockClient.mockFileListResult = FileListResult(
          path: '/new/path',
          files: [],
        );

        await provider.navigateTo('/new/path');

        expect(provider.currentPath, '/new/path');
        expect(provider.selectedFiles, isEmpty);
      });

      test('should go up one directory', () async {
        mockClient.mockFileListResult = FileListResult(
          path: '/home/user/docs',
          files: [],
        );
        await provider.navigateTo('/home/user/docs');

        mockClient.mockFileListResult = FileListResult(
          path: '/home/user',
          files: [],
        );
        await provider.goUp();

        expect(provider.currentPath, '/home/user');
      });

      test('should not go up from root', () async {
        mockClient.mockFileListResult = FileListResult(
          path: '/',
          files: [],
        );
        await provider.navigateTo('/');

        final pathBefore = provider.currentPath;
        await provider.goUp();

        expect(provider.currentPath, pathBefore);
      });

      test('should open directory', () async {
        final dir = createMockFile(name: 'docs', isDirectory: true);
        mockClient.mockFileListResult = FileListResult(
          path: '~/docs',
          files: [],
        );

        await provider.open(dir);

        expect(mockClient.verifyCall('listFiles'), isTrue);
      });
    });

    group('history navigation', () {
      setUp(() async {
        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });

      test('canGoBack should be false initially', () {
        expect(provider.canGoBack, isFalse);
      });

      test('canGoForward should be false initially', () {
        expect(provider.canGoForward, isFalse);
      });

      test('should track navigation history', () async {
        mockClient.mockFileListResult = FileListResult(path: '/path1', files: []);
        await provider.navigateTo('/path1');

        mockClient.mockFileListResult = FileListResult(path: '/path2', files: []);
        await provider.navigateTo('/path2');

        expect(provider.canGoBack, isTrue);
      });

      test('should go back in history', () async {
        mockClient.mockFileListResult = FileListResult(path: '/path1', files: []);
        await provider.navigateTo('/path1');

        mockClient.mockFileListResult = FileListResult(path: '/path2', files: []);
        await provider.navigateTo('/path2');

        mockClient.mockFileListResult = FileListResult(path: '/path1', files: []);
        await provider.goBack();

        expect(provider.currentPath, '/path1');
        expect(provider.canGoForward, isTrue);
      });
    });

    group('selection', () {
      setUp(() async {
        mockClient.mockFileListResult = createMockFileListResult();
        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });

      test('should toggle file selection', () {
        provider.toggleSelection('file_0.txt');

        expect(provider.selectedFiles.contains('file_0.txt'), isTrue);

        provider.toggleSelection('file_0.txt');

        expect(provider.selectedFiles.contains('file_0.txt'), isFalse);
      });

      test('should select all files', () {
        provider.selectAll();

        expect(provider.selectedFiles.length, provider.files.length);
      });

      test('should clear selection', () {
        provider.selectAll();
        provider.clearSelection();

        expect(provider.selectedFiles, isEmpty);
      });
    });

    group('hidden files', () {
      setUp(() {
        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );
      });

      test('should toggle hidden files visibility', () async {
        expect(provider.showHidden, isFalse);

        provider.toggleHidden();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.showHidden, isTrue);

        // Should have called listFiles with showHidden: true
        final calls = mockClient.getCallsTo('listFiles');
        final lastCall = calls.last;
        expect(lastCall.arguments['showHidden'], isTrue);
      });
    });

    group('sorting', () {
      setUp(() async {
        mockClient.mockFileListResult = FileListResult(
          path: '/home',
          files: [
            createMockFile(name: 'z_file.txt', size: 100),
            createMockFile(name: 'a_file.txt', size: 500),
            createMockFile(name: 'm_file.txt', size: 200),
            createMockFile(name: 'dir_a', isDirectory: true),
            createMockFile(name: 'dir_z', isDirectory: true),
          ],
        );
        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });

      test('should sort by name by default', () {
        expect(provider.sortField, FileSortField.name);
        expect(provider.sortAscending, isTrue);
      });

      test('should put directories first', () {
        // Directories should come before files
        expect(provider.files[0].isDirectory, isTrue);
        expect(provider.files[1].isDirectory, isTrue);
      });

      test('should toggle sort direction when same field selected', () {
        provider.setSortField(FileSortField.name);

        expect(provider.sortAscending, isFalse);

        provider.setSortField(FileSortField.name);

        expect(provider.sortAscending, isTrue);
      });

      test('should reset to ascending when changing sort field', () {
        provider.setSortField(FileSortField.name);
        expect(provider.sortAscending, isFalse);

        provider.setSortField(FileSortField.size);
        expect(provider.sortAscending, isTrue);
      });
    });

    group('file operations', () {
      setUp(() async {
        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });

      test('should create directory', () async {
        mockClient.mockOperationResult = OperationResult(
          success: true,
          message: 'Created',
        );

        final result = await provider.createDirectory('new_folder');

        expect(result, isTrue);
        expect(mockClient.verifyCall('mkdir'), isTrue);
      });

      test('should delete selected files', () async {
        provider.toggleSelection('file_0.txt');
        mockClient.mockOperationResult = OperationResult(
          success: true,
          message: 'Deleted',
        );

        final result = await provider.deleteSelected();

        expect(result, isTrue);
        expect(mockClient.verifyCall('delete'), isTrue);
        expect(provider.selectedFiles, isEmpty);
      });

      test('should rename file', () async {
        mockClient.mockOperationResult = OperationResult(
          success: true,
          message: 'Renamed',
        );

        final result = await provider.rename('old.txt', 'new.txt');

        expect(result, isTrue);
        expect(mockClient.verifyCall('rename'), isTrue);
      });

      test('should return false when no files selected for delete', () async {
        final result = await provider.deleteSelected();

        expect(result, isFalse);
      });
    });

    group('getFullPath', () {
      setUp(() {
        provider = FileBrowserProvider(
          client: mockClient,
          serverName: 'test_server',
        );
      });

      test('should build correct path from root', () async {
        mockClient.mockFileListResult = FileListResult(path: '/', files: []);
        await provider.navigateTo('/');

        expect(provider.getFullPath('test.txt'), '/test.txt');
      });

      test('should build correct path from subdirectory', () async {
        mockClient.mockFileListResult = FileListResult(
          path: '/home/user',
          files: [],
        );
        await provider.navigateTo('/home/user');

        expect(provider.getFullPath('test.txt'), '/home/user/test.txt');
      });
    });
  });
}

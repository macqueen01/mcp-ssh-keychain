import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_file_manager/mcp/mcp_client.dart';

void main() {
  group('SshServer', () {
    test('should create with required fields', () {
      final server = SshServer(
        name: 'production',
        host: 'prod.example.com',
        user: 'deploy',
      );

      expect(server.name, 'production');
      expect(server.host, 'prod.example.com');
      expect(server.user, 'deploy');
      expect(server.port, 22); // default
      expect(server.defaultDir, isNull);
    });

    test('should create with all fields', () {
      final server = SshServer(
        name: 'staging',
        host: 'staging.example.com',
        user: 'admin',
        port: 2222,
        defaultDir: '/var/www/app',
      );

      expect(server.name, 'staging');
      expect(server.host, 'staging.example.com');
      expect(server.user, 'admin');
      expect(server.port, 2222);
      expect(server.defaultDir, '/var/www/app');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'name': 'test_server',
        'host': 'test.local',
        'user': 'tester',
        'port': 22,
        'defaultDir': '/home/tester',
      };

      final server = SshServer.fromJson(json);

      expect(server.name, 'test_server');
      expect(server.host, 'test.local');
      expect(server.user, 'tester');
      expect(server.port, 22);
      expect(server.defaultDir, '/home/tester');
    });

    test('should handle missing optional fields in JSON', () {
      final json = {
        'name': 'minimal',
      };

      final server = SshServer.fromJson(json);

      expect(server.name, 'minimal');
      expect(server.host, '');
      expect(server.user, '');
      expect(server.port, 22);
      expect(server.defaultDir, isNull);
    });
  });

  group('RemoteFile', () {
    test('should create file with all fields', () {
      final file = RemoteFile(
        name: 'test.txt',
        isDirectory: false,
        isLink: false,
        permissions: '-rw-r--r--',
        size: 1024,
        modified: '2024-01-01 12:00:00',
      );

      expect(file.name, 'test.txt');
      expect(file.isDirectory, isFalse);
      expect(file.isLink, isFalse);
      expect(file.permissions, '-rw-r--r--');
      expect(file.size, 1024);
      expect(file.modified, '2024-01-01 12:00:00');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'name': 'document.pdf',
        'isDirectory': false,
        'isLink': false,
        'permissions': '-rw-r--r--',
        'size': 2048,
        'modified': '2024-01-15 09:30:00',
      };

      final file = RemoteFile.fromJson(json);

      expect(file.name, 'document.pdf');
      expect(file.isDirectory, isFalse);
      expect(file.size, 2048);
    });

    test('should handle missing fields with defaults', () {
      final json = <String, dynamic>{};

      final file = RemoteFile.fromJson(json);

      expect(file.name, '');
      expect(file.isDirectory, isFalse);
      expect(file.isLink, isFalse);
      expect(file.permissions, '');
      expect(file.size, 0);
      expect(file.modified, '');
    });

    group('icon', () {
      test('should return folder for directories', () {
        final file = RemoteFile(
          name: 'docs',
          isDirectory: true,
          permissions: 'drwxr-xr-x',
          size: 4096,
          modified: '',
        );

        expect(file.icon, 'folder');
      });

      test('should return link for symlinks', () {
        final file = RemoteFile(
          name: 'link_file',
          isDirectory: false,
          isLink: true,
          permissions: 'lrwxrwxrwx',
          size: 0,
          modified: '',
        );

        expect(file.icon, 'link');
      });

      test('should return text for text files', () {
        for (final ext in ['txt', 'md', 'log']) {
          final file = RemoteFile(
            name: 'file.$ext',
            isDirectory: false,
            permissions: '-rw-r--r--',
            size: 100,
            modified: '',
          );
          expect(file.icon, 'text', reason: 'Extension .$ext should be text');
        }
      });

      test('should return code for code files', () {
        for (final ext in ['js', 'ts', 'py', 'dart', 'java', 'c', 'cpp', 'rs', 'go']) {
          final file = RemoteFile(
            name: 'file.$ext',
            isDirectory: false,
            permissions: '-rw-r--r--',
            size: 100,
            modified: '',
          );
          expect(file.icon, 'code', reason: 'Extension .$ext should be code');
        }
      });

      test('should return config for config files', () {
        for (final ext in ['json', 'xml', 'yaml', 'yml', 'toml']) {
          final file = RemoteFile(
            name: 'file.$ext',
            isDirectory: false,
            permissions: '-rw-r--r--',
            size: 100,
            modified: '',
          );
          expect(file.icon, 'config', reason: 'Extension .$ext should be config');
        }
      });

      test('should return image for image files', () {
        for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'svg', 'webp']) {
          final file = RemoteFile(
            name: 'file.$ext',
            isDirectory: false,
            permissions: '-rw-r--r--',
            size: 100,
            modified: '',
          );
          expect(file.icon, 'image', reason: 'Extension .$ext should be image');
        }
      });

      test('should return archive for archive files', () {
        for (final ext in ['zip', 'tar', 'gz', 'rar', '7z']) {
          final file = RemoteFile(
            name: 'file.$ext',
            isDirectory: false,
            permissions: '-rw-r--r--',
            size: 100,
            modified: '',
          );
          expect(file.icon, 'archive', reason: 'Extension .$ext should be archive');
        }
      });

      test('should return file for unknown extensions', () {
        final file = RemoteFile(
          name: 'file.unknown',
          isDirectory: false,
          permissions: '-rw-r--r--',
          size: 100,
          modified: '',
        );

        expect(file.icon, 'file');
      });
    });

    group('formattedSize', () {
      test('should return dash for directories', () {
        final file = RemoteFile(
          name: 'dir',
          isDirectory: true,
          permissions: 'drwxr-xr-x',
          size: 4096,
          modified: '',
        );

        expect(file.formattedSize, '-');
      });

      test('should format bytes correctly', () {
        final file = RemoteFile(
          name: 'tiny.txt',
          isDirectory: false,
          permissions: '-rw-r--r--',
          size: 512,
          modified: '',
        );

        expect(file.formattedSize, '512 B');
      });

      test('should format kilobytes correctly', () {
        final file = RemoteFile(
          name: 'small.txt',
          isDirectory: false,
          permissions: '-rw-r--r--',
          size: 2048,
          modified: '',
        );

        expect(file.formattedSize, '2.0 KB');
      });

      test('should format megabytes correctly', () {
        final file = RemoteFile(
          name: 'medium.txt',
          isDirectory: false,
          permissions: '-rw-r--r--',
          size: 5242880, // 5 MB
          modified: '',
        );

        expect(file.formattedSize, '5.0 MB');
      });

      test('should format gigabytes correctly', () {
        final file = RemoteFile(
          name: 'large.txt',
          isDirectory: false,
          permissions: '-rw-r--r--',
          size: 2147483648, // 2 GB
          modified: '',
        );

        expect(file.formattedSize, '2.0 GB');
      });
    });
  });

  group('FileListResult', () {
    test('should create with path and files', () {
      final result = FileListResult(
        path: '/home/user',
        files: [
          RemoteFile(
            name: 'test.txt',
            isDirectory: false,
            permissions: '-rw-r--r--',
            size: 100,
            modified: '',
          ),
        ],
      );

      expect(result.path, '/home/user');
      expect(result.files.length, 1);
      expect(result.files[0].name, 'test.txt');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'path': '/var/www',
        'files': [
          {
            'name': 'index.html',
            'isDirectory': false,
            'permissions': '-rw-r--r--',
            'size': 1024,
            'modified': '2024-01-01',
          },
          {
            'name': 'assets',
            'isDirectory': true,
            'permissions': 'drwxr-xr-x',
            'size': 4096,
            'modified': '2024-01-01',
          },
        ],
      };

      final result = FileListResult.fromJson(json);

      expect(result.path, '/var/www');
      expect(result.files.length, 2);
      expect(result.files[0].name, 'index.html');
      expect(result.files[1].name, 'assets');
      expect(result.files[1].isDirectory, isTrue);
    });

    test('should handle empty files list', () {
      final json = {
        'path': '/empty',
        'files': <Map<String, dynamic>>[],
      };

      final result = FileListResult.fromJson(json);

      expect(result.path, '/empty');
      expect(result.files, isEmpty);
    });
  });

  group('CommandResult', () {
    test('should create with all fields', () {
      final result = CommandResult(
        stdout: 'Hello, World!',
        stderr: '',
        code: 0,
      );

      expect(result.stdout, 'Hello, World!');
      expect(result.stderr, '');
      expect(result.code, 0);
      expect(result.isSuccess, isTrue);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'stdout': 'output',
        'stderr': 'error',
        'code': 1,
      };

      final result = CommandResult.fromJson(json);

      expect(result.stdout, 'output');
      expect(result.stderr, 'error');
      expect(result.code, 1);
      expect(result.isSuccess, isFalse);
    });

    test('isSuccess should return true for code 0', () {
      final result = CommandResult(stdout: '', stderr: '', code: 0);
      expect(result.isSuccess, isTrue);
    });

    test('isSuccess should return false for non-zero code', () {
      final result = CommandResult(stdout: '', stderr: 'Error', code: 1);
      expect(result.isSuccess, isFalse);
    });
  });

  group('OperationResult', () {
    test('should create with success true', () {
      final result = OperationResult(
        success: true,
        message: 'Operation completed',
      );

      expect(result.success, isTrue);
      expect(result.message, 'Operation completed');
    });

    test('should create with success false', () {
      final result = OperationResult(
        success: false,
        message: 'Operation failed',
      );

      expect(result.success, isFalse);
      expect(result.message, 'Operation failed');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'success': true,
        'message': 'Done',
      };

      final result = OperationResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.message, 'Done');
    });
  });

  group('McpTool', () {
    test('should create with all fields', () {
      final tool = McpTool(
        name: 'ssh_execute',
        description: 'Execute command on server',
        inputSchema: {
          'type': 'object',
          'properties': {
            'server': {'type': 'string'},
            'command': {'type': 'string'},
          },
        },
      );

      expect(tool.name, 'ssh_execute');
      expect(tool.description, 'Execute command on server');
      expect(tool.inputSchema['type'], 'object');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'name': 'ssh_list_servers',
        'description': 'List all servers',
        'inputSchema': {'type': 'object'},
      };

      final tool = McpTool.fromJson(json);

      expect(tool.name, 'ssh_list_servers');
      expect(tool.description, 'List all servers');
    });
  });

  group('McpToolResult', () {
    test('should create with content', () {
      final result = McpToolResult(
        content: [
          McpContent(type: 'text', text: 'Hello'),
        ],
      );

      expect(result.content.length, 1);
      expect(result.textContent, 'Hello');
    });

    test('should concatenate multiple text contents', () {
      final result = McpToolResult(
        content: [
          McpContent(type: 'text', text: 'Line 1'),
          McpContent(type: 'text', text: 'Line 2'),
        ],
      );

      expect(result.textContent, 'Line 1\nLine 2');
    });

    test('should filter non-text content', () {
      final result = McpToolResult(
        content: [
          McpContent(type: 'text', text: 'Text'),
          McpContent(type: 'image', text: 'base64data'),
        ],
      );

      expect(result.textContent, 'Text');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'content': [
          {'type': 'text', 'text': 'Result'},
        ],
      };

      final result = McpToolResult.fromJson(json);

      expect(result.textContent, 'Result');
    });
  });

  group('McpError', () {
    test('should create with code and message', () {
      final error = McpError(code: -32600, message: 'Invalid Request');

      expect(error.code, -32600);
      expect(error.message, 'Invalid Request');
    });

    test('should have proper toString', () {
      final error = McpError(code: -32601, message: 'Method not found');

      expect(error.toString(), 'McpError(-32601): Method not found');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'code': -32602,
        'message': 'Invalid params',
      };

      final error = McpError.fromJson(json);

      expect(error.code, -32602);
      expect(error.message, 'Invalid params');
    });
  });

  group('McpEvent', () {
    test('should create connected event', () {
      final event = McpEvent.connected();

      expect(event.type, McpEventType.connected);
      expect(event.data, isNull);
      expect(event.error, isNull);
    });

    test('should create disconnected event', () {
      final event = McpEvent.disconnected();

      expect(event.type, McpEventType.disconnected);
    });

    test('should create initialized event with data', () {
      final event = McpEvent.initialized({'version': '1.0'});

      expect(event.type, McpEventType.initialized);
      expect(event.data['version'], '1.0');
    });

    test('should create notification event', () {
      final event = McpEvent.notification('test/method', {'key': 'value'});

      expect(event.type, McpEventType.notification);
      expect(event.data['method'], 'test/method');
      expect(event.data['params']['key'], 'value');
    });

    test('should create error event', () {
      final event = McpEvent.error('Connection failed');

      expect(event.type, McpEventType.error);
      expect(event.error, 'Connection failed');
    });
  });
}

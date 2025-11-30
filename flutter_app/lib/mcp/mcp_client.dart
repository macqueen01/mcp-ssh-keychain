import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// MCP Client for communicating with the MCP SSH Manager server
class McpClient {
  WebSocketChannel? _channel;
  int _requestId = 0;
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  final StreamController<McpEvent> _eventController =
      StreamController<McpEvent>.broadcast();

  String? _serverUrl;
  bool _isConnected = false;
  bool _isInitialized = false;

  /// Stream of MCP events
  Stream<McpEvent> get events => _eventController.stream;

  /// Whether the client is connected
  bool get isConnected => _isConnected;

  /// Whether the client is initialized
  bool get isInitialized => _isInitialized;

  /// Connect to the MCP server
  Future<void> connect(String url) async {
    if (_isConnected) {
      await disconnect();
    }

    _serverUrl = url;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _eventController.add(McpEvent.connected());

      // Initialize the connection
      await initialize();
    } catch (e) {
      _isConnected = false;
      _eventController.add(McpEvent.error('Connection failed: $e'));
      rethrow;
    }
  }

  /// Initialize the MCP session
  Future<Map<String, dynamic>> initialize() async {
    final result = await _sendRequest('initialize', {
      'protocolVersion': '2024-11-05',
      'capabilities': {},
      'clientInfo': {
        'name': 'mcp-file-manager',
        'version': '1.0.0',
      },
    });

    // Send initialized notification
    _sendNotification('notifications/initialized', {});

    _isInitialized = true;
    _eventController.add(McpEvent.initialized(result));

    return result;
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    _isConnected = false;
    _isInitialized = false;

    // Cancel all pending requests
    for (final completer in _pendingRequests.values) {
      completer.completeError('Disconnected');
    }
    _pendingRequests.clear();

    await _channel?.sink.close();
    _channel = null;

    _eventController.add(McpEvent.disconnected());
  }

  /// List available tools
  Future<List<McpTool>> listTools() async {
    final result = await _sendRequest('tools/list', {});
    final tools = (result['tools'] as List)
        .map((t) => McpTool.fromJson(t as Map<String, dynamic>))
        .toList();
    return tools;
  }

  /// Call an MCP tool
  Future<McpToolResult> callTool(String name,
      [Map<String, dynamic>? arguments]) async {
    final result = await _sendRequest('tools/call', {
      'name': name,
      'arguments': arguments ?? {},
    });
    return McpToolResult.fromJson(result);
  }

  // Convenience methods for SSH operations

  /// List all configured servers
  Future<List<SshServer>> listServers() async {
    final result = await callTool('ssh_list_servers');
    final data = jsonDecode(result.textContent);
    if (data is List) {
      return data.map((s) => SshServer.fromJson(s)).toList();
    }
    return [];
  }

  /// List files in a directory
  Future<FileListResult> listFiles(String server,
      {String path = '~', bool showHidden = false}) async {
    final result = await callTool('ssh_list_files', {
      'server': server,
      'path': path,
      'showHidden': showHidden,
    });
    final data = jsonDecode(result.textContent);
    return FileListResult.fromJson(data);
  }

  /// Execute a command on the server
  Future<CommandResult> execute(String server, String command,
      {String? cwd, int timeout = 30000}) async {
    final result = await callTool('ssh_execute', {
      'server': server,
      'command': command,
      if (cwd != null) 'cwd': cwd,
      'timeout': timeout,
    });
    final data = jsonDecode(result.textContent);
    return CommandResult.fromJson(data);
  }

  /// Create a directory
  Future<OperationResult> mkdir(String server, String path,
      {bool recursive = true}) async {
    final result = await callTool('ssh_mkdir', {
      'server': server,
      'path': path,
      'recursive': recursive,
    });
    final data = jsonDecode(result.textContent);
    return OperationResult.fromJson(data);
  }

  /// Delete a file or directory
  Future<OperationResult> delete(String server, String path,
      {bool recursive = false}) async {
    final result = await callTool('ssh_delete', {
      'server': server,
      'path': path,
      'recursive': recursive,
    });
    final data = jsonDecode(result.textContent);
    return OperationResult.fromJson(data);
  }

  /// Rename/move a file
  Future<OperationResult> rename(
      String server, String oldPath, String newPath) async {
    final result = await callTool('ssh_rename', {
      'server': server,
      'oldPath': oldPath,
      'newPath': newPath,
    });
    final data = jsonDecode(result.textContent);
    return OperationResult.fromJson(data);
  }

  /// Read file contents
  Future<String> readFile(String server, String path) async {
    final result = await callTool('ssh_read_file', {
      'server': server,
      'path': path,
    });
    return result.textContent;
  }

  /// Get file info
  Future<String> fileInfo(String server, String path) async {
    final result = await callTool('ssh_file_info', {
      'server': server,
      'path': path,
    });
    return result.textContent;
  }

  /// Download a file from remote server
  Future<Map<String, dynamic>> downloadFile({
    required String server,
    required String remotePath,
    required String localPath,
  }) async {
    final result = await callTool('ssh_download', {
      'server': server,
      'remotePath': remotePath,
      'localPath': localPath,
    });
    return jsonDecode(result.textContent);
  }

  /// Upload a file to remote server
  Future<Map<String, dynamic>> uploadFile({
    required String server,
    required String localPath,
    required String remotePath,
  }) async {
    final result = await callTool('ssh_upload', {
      'server': server,
      'localPath': localPath,
      'remotePath': remotePath,
    });
    return jsonDecode(result.textContent);
  }

  // Private methods

  Future<Map<String, dynamic>> _sendRequest(
      String method, Map<String, dynamic> params) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to MCP server');
    }

    final id = ++_requestId;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    final message = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });

    _channel!.sink.add(message);

    // Add timeout
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('Request timed out: $method');
      },
    );
  }

  void _sendNotification(String method, Map<String, dynamic> params) {
    if (!_isConnected || _channel == null) return;

    final message = jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });

    _channel!.sink.add(message);
  }

  void _handleMessage(dynamic message) {
    try {
      print('[MCP Client] Received message: ${(message as String).substring(0, (message.length > 200 ? 200 : message.length))}...');
      final data = jsonDecode(message) as Map<String, dynamic>;

      // Check if it's a response to a request
      if (data.containsKey('id') && data['id'] != null) {
        final id = data['id'] as int;
        print('[MCP Client] Response for id=$id, pending requests: ${_pendingRequests.keys.toList()}');
        final completer = _pendingRequests.remove(id);

        if (completer != null) {
          if (data.containsKey('error')) {
            print('[MCP Client] Completing with error: ${data['error']}');
            completer.completeError(McpError.fromJson(data['error']));
          } else {
            print('[MCP Client] Completing successfully');
            completer.complete(data['result'] ?? {});
          }
        } else {
          print('[MCP Client] No pending request found for id=$id');
        }
      }
      // Check if it's a notification
      else if (data.containsKey('method')) {
        _eventController.add(McpEvent.notification(
          data['method'] as String,
          data['params'] as Map<String, dynamic>?,
        ));
      }
    } catch (e) {
      print('[MCP Client] Error parsing message: $e');
      _eventController.add(McpEvent.error('Failed to parse message: $e'));
    }
  }

  void _handleError(dynamic error) {
    _eventController.add(McpEvent.error('WebSocket error: $error'));
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isInitialized = false;
    _eventController.add(McpEvent.disconnected());
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}

/// MCP Event types
enum McpEventType { connected, disconnected, initialized, notification, error }

/// MCP Event
class McpEvent {
  final McpEventType type;
  final dynamic data;
  final String? error;

  McpEvent._(this.type, {this.data, this.error});

  factory McpEvent.connected() => McpEvent._(McpEventType.connected);
  factory McpEvent.disconnected() => McpEvent._(McpEventType.disconnected);
  factory McpEvent.initialized(Map<String, dynamic> data) =>
      McpEvent._(McpEventType.initialized, data: data);
  factory McpEvent.notification(String method, Map<String, dynamic>? params) =>
      McpEvent._(McpEventType.notification, data: {'method': method, 'params': params});
  factory McpEvent.error(String message) =>
      McpEvent._(McpEventType.error, error: message);
}

/// MCP Tool definition
class McpTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  factory McpTool.fromJson(Map<String, dynamic> json) {
    return McpTool(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      inputSchema: json['inputSchema'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// MCP Tool result
class McpToolResult {
  final List<McpContent> content;

  McpToolResult({required this.content});

  factory McpToolResult.fromJson(Map<String, dynamic> json) {
    final contentList = json['content'] as List? ?? [];
    return McpToolResult(
      content: contentList
          .map((c) => McpContent.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  String get textContent {
    return content
        .where((c) => c.type == 'text')
        .map((c) => c.text)
        .join('\n');
  }
}

/// MCP Content item
class McpContent {
  final String type;
  final String text;

  McpContent({required this.type, required this.text});

  factory McpContent.fromJson(Map<String, dynamic> json) {
    return McpContent(
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String? ?? '',
    );
  }
}

/// MCP Error
class McpError implements Exception {
  final int code;
  final String message;

  McpError({required this.code, required this.message});

  factory McpError.fromJson(Map<String, dynamic> json) {
    return McpError(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String? ?? 'Unknown error',
    );
  }

  @override
  String toString() => 'McpError($code): $message';
}

/// SSH Server info
class SshServer {
  final String name;
  final String host;
  final String user;
  final int port;
  final String? defaultDir;

  SshServer({
    required this.name,
    required this.host,
    required this.user,
    this.port = 22,
    this.defaultDir,
  });

  factory SshServer.fromJson(Map<String, dynamic> json) {
    return SshServer(
      name: json['name'] as String,
      host: json['host'] as String? ?? '',
      user: json['user'] as String? ?? '',
      port: json['port'] as int? ?? 22,
      defaultDir: json['defaultDir'] as String?,
    );
  }
}

/// File list result
class FileListResult {
  final String path;
  final List<RemoteFile> files;

  FileListResult({required this.path, required this.files});

  factory FileListResult.fromJson(Map<String, dynamic> json) {
    final fileList = json['files'] as List? ?? [];
    return FileListResult(
      path: json['path'] as String? ?? '',
      files: fileList
          .map((f) => RemoteFile.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Remote file info
class RemoteFile {
  final String name;
  final bool isDirectory;
  final bool isLink;
  final String permissions;
  final int size;
  final String modified;

  RemoteFile({
    required this.name,
    required this.isDirectory,
    this.isLink = false,
    required this.permissions,
    required this.size,
    required this.modified,
  });

  factory RemoteFile.fromJson(Map<String, dynamic> json) {
    return RemoteFile(
      name: json['name'] as String? ?? '',
      isDirectory: json['isDirectory'] as bool? ?? false,
      isLink: json['isLink'] as bool? ?? false,
      permissions: json['permissions'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      modified: json['modified'] as String? ?? '',
    );
  }

  String get icon {
    if (isDirectory) return 'folder';
    if (isLink) return 'link';

    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'txt':
      case 'md':
      case 'log':
        return 'text';
      case 'js':
      case 'ts':
      case 'py':
      case 'dart':
      case 'java':
      case 'c':
      case 'cpp':
      case 'h':
      case 'rs':
      case 'go':
        return 'code';
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
      case 'toml':
        return 'config';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'svg':
      case 'webp':
        return 'image';
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'ogg':
        return 'audio';
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return 'video';
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
      case '7z':
        return 'archive';
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'word';
      case 'xls':
      case 'xlsx':
        return 'excel';
      default:
        return 'file';
    }
  }

  String get formattedSize {
    if (isDirectory) return '-';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Command execution result
class CommandResult {
  final String stdout;
  final String stderr;
  final int code;

  CommandResult({
    required this.stdout,
    required this.stderr,
    required this.code,
  });

  factory CommandResult.fromJson(Map<String, dynamic> json) {
    return CommandResult(
      stdout: json['stdout'] as String? ?? '',
      stderr: json['stderr'] as String? ?? '',
      code: json['code'] as int? ?? 0,
    );
  }

  bool get isSuccess => code == 0;
}

/// Generic operation result
class OperationResult {
  final bool success;
  final String message;

  OperationResult({required this.success, required this.message});

  factory OperationResult.fromJson(Map<String, dynamic> json) {
    return OperationResult(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

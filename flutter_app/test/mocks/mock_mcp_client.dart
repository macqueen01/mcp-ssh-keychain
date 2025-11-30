import 'dart:async';
import 'package:mcp_file_manager/mcp/mcp_client.dart';

/// Mock implementation of McpClient for testing
class MockMcpClient implements McpClient {
  bool _isConnected = false;
  bool _isInitialized = false;
  final StreamController<McpEvent> _eventController =
      StreamController<McpEvent>.broadcast();

  // Configurable responses for testing
  List<SshServer> mockServers = [];
  FileListResult? mockFileListResult;
  CommandResult? mockCommandResult;
  OperationResult? mockOperationResult;
  String? mockFileContent;
  Map<String, dynamic>? mockTransferResult;
  List<McpTool> mockTools = [];
  McpToolResult? mockToolResult;

  // Track method calls for verification
  final List<MethodCall> methodCalls = [];

  @override
  Stream<McpEvent> get events => _eventController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> connect(String url) async {
    methodCalls.add(MethodCall('connect', {'url': url}));
    _isConnected = true;
    _eventController.add(McpEvent.connected());
  }

  @override
  Future<Map<String, dynamic>> initialize() async {
    methodCalls.add(MethodCall('initialize', {}));
    _isInitialized = true;
    final result = {'protocolVersion': '2024-11-05'};
    _eventController.add(McpEvent.initialized(result));
    return result;
  }

  @override
  Future<void> disconnect() async {
    methodCalls.add(MethodCall('disconnect', {}));
    _isConnected = false;
    _isInitialized = false;
    _eventController.add(McpEvent.disconnected());
  }

  @override
  Future<List<McpTool>> listTools() async {
    methodCalls.add(MethodCall('listTools', {}));
    return mockTools;
  }

  @override
  Future<McpToolResult> callTool(String name,
      [Map<String, dynamic>? arguments]) async {
    methodCalls.add(MethodCall('callTool', {'name': name, 'arguments': arguments}));
    if (mockToolResult != null) {
      return mockToolResult!;
    }
    return McpToolResult(content: [McpContent(type: 'text', text: '{}')]);
  }

  @override
  Future<List<SshServer>> listServers() async {
    methodCalls.add(MethodCall('listServers', {}));
    return mockServers;
  }

  @override
  Future<FileListResult> listFiles(String server,
      {String path = '~', bool showHidden = false}) async {
    methodCalls.add(MethodCall('listFiles', {
      'server': server,
      'path': path,
      'showHidden': showHidden,
    }));
    return mockFileListResult ??
        FileListResult(path: path, files: []);
  }

  @override
  Future<CommandResult> execute(String server, String command,
      {String? cwd, int timeout = 30000}) async {
    methodCalls.add(MethodCall('execute', {
      'server': server,
      'command': command,
      'cwd': cwd,
      'timeout': timeout,
    }));
    return mockCommandResult ??
        CommandResult(stdout: '', stderr: '', code: 0);
  }

  @override
  Future<OperationResult> mkdir(String server, String path,
      {bool recursive = true}) async {
    methodCalls.add(MethodCall('mkdir', {
      'server': server,
      'path': path,
      'recursive': recursive,
    }));
    return mockOperationResult ??
        OperationResult(success: true, message: 'Directory created');
  }

  @override
  Future<OperationResult> delete(String server, String path,
      {bool recursive = false}) async {
    methodCalls.add(MethodCall('delete', {
      'server': server,
      'path': path,
      'recursive': recursive,
    }));
    return mockOperationResult ??
        OperationResult(success: true, message: 'Deleted');
  }

  @override
  Future<OperationResult> rename(
      String server, String oldPath, String newPath) async {
    methodCalls.add(MethodCall('rename', {
      'server': server,
      'oldPath': oldPath,
      'newPath': newPath,
    }));
    return mockOperationResult ??
        OperationResult(success: true, message: 'Renamed');
  }

  @override
  Future<String> readFile(String server, String path) async {
    methodCalls.add(MethodCall('readFile', {
      'server': server,
      'path': path,
    }));
    return mockFileContent ?? '';
  }

  @override
  Future<String> fileInfo(String server, String path) async {
    methodCalls.add(MethodCall('fileInfo', {
      'server': server,
      'path': path,
    }));
    return '{}';
  }

  @override
  Future<Map<String, dynamic>> downloadFile({
    required String server,
    required String remotePath,
    required String localPath,
  }) async {
    methodCalls.add(MethodCall('downloadFile', {
      'server': server,
      'remotePath': remotePath,
      'localPath': localPath,
    }));
    return mockTransferResult ?? {'success': true};
  }

  @override
  Future<Map<String, dynamic>> uploadFile({
    required String server,
    required String localPath,
    required String remotePath,
  }) async {
    methodCalls.add(MethodCall('uploadFile', {
      'server': server,
      'localPath': localPath,
      'remotePath': remotePath,
    }));
    return mockTransferResult ?? {'success': true};
  }

  @override
  void dispose() {
    methodCalls.add(MethodCall('dispose', {}));
    _eventController.close();
  }

  // Helper methods for testing

  /// Emit an error event
  void emitError(String message) {
    _eventController.add(McpEvent.error(message));
  }

  /// Emit a notification event
  void emitNotification(String method, Map<String, dynamic>? params) {
    _eventController.add(McpEvent.notification(method, params));
  }

  /// Reset all mock data and method calls
  void reset() {
    methodCalls.clear();
    mockServers = [];
    mockFileListResult = null;
    mockCommandResult = null;
    mockOperationResult = null;
    mockFileContent = null;
    mockTransferResult = null;
    mockTools = [];
    mockToolResult = null;
  }

  /// Verify a method was called with specific arguments
  bool verifyCall(String method, [Map<String, dynamic>? arguments]) {
    return methodCalls.any((call) {
      if (call.method != method) return false;
      if (arguments == null) return true;
      return _mapEquals(call.arguments, arguments);
    });
  }

  /// Get all calls to a specific method
  List<MethodCall> getCallsTo(String method) {
    return methodCalls.where((call) => call.method == method).toList();
  }

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Represents a method call for verification
class MethodCall {
  final String method;
  final Map<String, dynamic> arguments;

  MethodCall(this.method, this.arguments);

  @override
  String toString() => 'MethodCall($method, $arguments)';
}

import 'package:flutter/foundation.dart';
import '../mcp/mcp_client.dart';

/// Provider for managing MCP connection state
class ConnectionProvider extends ChangeNotifier {
  final McpClient _client = McpClient();

  String _serverUrl = 'ws://localhost:3000/mcp';
  bool _isConnecting = false;
  String? _error;
  List<SshServer> _servers = [];
  SshServer? _selectedServer;

  // Getters
  McpClient get client => _client;
  String get serverUrl => _serverUrl;
  bool get isConnected => _client.isConnected;
  bool get isInitialized => _client.isInitialized;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  List<SshServer> get servers => _servers;
  SshServer? get selectedServer => _selectedServer;

  ConnectionProvider() {
    // Listen to client events
    _client.events.listen((event) {
      switch (event.type) {
        case McpEventType.connected:
          _error = null;
          notifyListeners();
          break;
        case McpEventType.disconnected:
          _error = null;
          _servers = [];
          _selectedServer = null;
          notifyListeners();
          break;
        case McpEventType.error:
          _error = event.error;
          notifyListeners();
          break;
        case McpEventType.initialized:
          _loadServers();
          break;
        case McpEventType.notification:
          // Handle notifications if needed
          break;
      }
    });
  }

  /// Set the server URL
  void setServerUrl(String url) {
    _serverUrl = url;
    notifyListeners();
  }

  /// Connect to the MCP server
  Future<void> connect([String? url]) async {
    if (_isConnecting) return;

    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      await _client.connect(url ?? _serverUrl);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    await _client.disconnect();
    _servers = [];
    _selectedServer = null;
    notifyListeners();
  }

  /// Load available SSH servers
  Future<void> _loadServers() async {
    try {
      _servers = await _client.listServers();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load servers: $e';
      notifyListeners();
    }
  }

  /// Refresh server list
  Future<void> refreshServers() async {
    await _loadServers();
  }

  /// Select a server
  void selectServer(SshServer? server) {
    _selectedServer = server;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
}

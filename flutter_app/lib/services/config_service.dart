import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Model for SSH server configuration
class ServerConfig {
  final String name;
  final String host;
  final String user;
  final int port;
  final String? password;
  final String? keyPath;
  final String? defaultDir;
  final String? sudoPassword;

  ServerConfig({
    required this.name,
    required this.host,
    required this.user,
    this.port = 22,
    this.password,
    this.keyPath,
    this.defaultDir,
    this.sudoPassword,
  });

  Map<String, dynamic> toToml() {
    final map = <String, dynamic>{
      'host': host,
      'user': user,
      'port': port,
    };
    if (password != null && password!.isNotEmpty) map['password'] = password;
    if (keyPath != null && keyPath!.isNotEmpty) map['key_path'] = keyPath;
    if (defaultDir != null && defaultDir!.isNotEmpty) map['default_dir'] = defaultDir;
    if (sudoPassword != null && sudoPassword!.isNotEmpty) map['sudo_password'] = sudoPassword;
    return map;
  }

  ServerConfig copyWith({
    String? name,
    String? host,
    String? user,
    int? port,
    String? password,
    String? keyPath,
    String? defaultDir,
    String? sudoPassword,
  }) {
    return ServerConfig(
      name: name ?? this.name,
      host: host ?? this.host,
      user: user ?? this.user,
      port: port ?? this.port,
      password: password ?? this.password,
      keyPath: keyPath ?? this.keyPath,
      defaultDir: defaultDir ?? this.defaultDir,
      sudoPassword: sudoPassword ?? this.sudoPassword,
    );
  }
}

/// Model for tool group configuration
class ToolGroupConfig {
  final String name;
  final String displayName;
  final String description;
  final int toolCount;
  final bool enabled;

  ToolGroupConfig({
    required this.name,
    required this.displayName,
    required this.description,
    required this.toolCount,
    required this.enabled,
  });

  ToolGroupConfig copyWith({bool? enabled}) {
    return ToolGroupConfig(
      name: name,
      displayName: displayName,
      description: description,
      toolCount: toolCount,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Model for tools configuration
class ToolsConfig {
  final String mode; // 'all', 'minimal', 'custom'
  final List<String> enabledGroups;
  final List<String> disabledTools;

  ToolsConfig({
    required this.mode,
    required this.enabledGroups,
    required this.disabledTools,
  });

  factory ToolsConfig.defaultConfig() {
    return ToolsConfig(
      mode: 'all',
      enabledGroups: ['core', 'sessions', 'monitoring', 'backup', 'database', 'advanced'],
      disabledTools: [],
    );
  }

  factory ToolsConfig.fromJson(Map<String, dynamic> json) {
    return ToolsConfig(
      mode: json['mode'] as String? ?? 'all',
      enabledGroups: (json['enabled_groups'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['core', 'sessions', 'monitoring', 'backup', 'database', 'advanced'],
      disabledTools: (json['disabled_tools'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'enabled_groups': enabledGroups,
      'disabled_tools': disabledTools,
    };
  }
}

/// Model for Claude Code integration status
class ClaudeCodeStatus {
  final bool isConfigured;
  final bool hasSshManager;
  final String? configPath;
  final String? errorMessage;
  final Map<String, dynamic>? mcpConfig;

  ClaudeCodeStatus({
    required this.isConfigured,
    required this.hasSshManager,
    this.configPath,
    this.errorMessage,
    this.mcpConfig,
  });
}

/// Service for managing SSH and MCP configuration files
class ConfigService {
  static final List<ToolGroupConfig> defaultToolGroups = [
    ToolGroupConfig(
      name: 'core',
      displayName: 'Core',
      description: 'Essential SSH operations: list servers, execute commands, upload/download',
      toolCount: 5,
      enabled: true,
    ),
    ToolGroupConfig(
      name: 'sessions',
      displayName: 'Sessions',
      description: 'Persistent SSH sessions and tunnels',
      toolCount: 4,
      enabled: true,
    ),
    ToolGroupConfig(
      name: 'monitoring',
      displayName: 'Monitoring',
      description: 'Health checks, service status, process management, alerts',
      toolCount: 6,
      enabled: true,
    ),
    ToolGroupConfig(
      name: 'backup',
      displayName: 'Backup',
      description: 'Create, list, restore and schedule backups',
      toolCount: 4,
      enabled: true,
    ),
    ToolGroupConfig(
      name: 'database',
      displayName: 'Database',
      description: 'Database dumps, imports, queries (MySQL, PostgreSQL, MongoDB)',
      toolCount: 4,
      enabled: true,
    ),
    ToolGroupConfig(
      name: 'advanced',
      displayName: 'Advanced',
      description: 'Deployment, rsync, sudo, aliases, groups, hooks, profiles',
      toolCount: 14,
      enabled: true,
    ),
  ];

  /// Get home directory path
  String get _homePath => Platform.environment['HOME'] ?? '';

  /// Get TOML config path
  String get _tomlConfigPath => path.join(_homePath, '.codex', 'ssh-config.toml');

  /// Get tools config path
  String get _toolsConfigPath => path.join(_homePath, '.ssh-manager', 'tools-config.json');

  /// Get Claude Code config path
  String get _claudeCodeConfigPath =>
      path.join(_homePath, '.config', 'claude-code', 'claude_code_config.json');

  /// Load servers from TOML config
  Future<List<ServerConfig>> loadServers() async {
    final file = File(_tomlConfigPath);
    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      return _parseTomlServers(content);
    } catch (e) {
      print('[ConfigService] Error loading servers: $e');
      return [];
    }
  }

  /// Parse TOML server configuration
  List<ServerConfig> _parseTomlServers(String content) {
    final servers = <ServerConfig>[];
    final lines = content.split('\n');

    String? currentServer;
    final serverData = <String, String>{};

    for (final line in lines) {
      final trimmed = line.trim();

      // Check for server section header
      final sectionMatch = RegExp(r'\[ssh_servers\.(\w+)\]').firstMatch(trimmed);
      if (sectionMatch != null) {
        // Save previous server if exists
        if (currentServer != null && serverData.isNotEmpty) {
          servers.add(_createServerFromData(currentServer, serverData));
          serverData.clear();
        }
        currentServer = sectionMatch.group(1);
        continue;
      }

      // Parse key-value pairs
      if (currentServer != null && trimmed.contains('=')) {
        final parts = trimmed.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          var value = parts.sublist(1).join('=').trim();
          // Remove quotes
          if (value.startsWith('"') && value.endsWith('"')) {
            value = value.substring(1, value.length - 1);
          }
          serverData[key] = value;
        }
      }
    }

    // Don't forget the last server
    if (currentServer != null && serverData.isNotEmpty) {
      servers.add(_createServerFromData(currentServer, serverData));
    }

    return servers;
  }

  ServerConfig _createServerFromData(String name, Map<String, String> data) {
    return ServerConfig(
      name: name,
      host: data['host'] ?? '',
      user: data['user'] ?? '',
      port: int.tryParse(data['port'] ?? '22') ?? 22,
      password: data['password'],
      keyPath: data['key_path'],
      defaultDir: data['default_dir'],
      sudoPassword: data['sudo_password'],
    );
  }

  /// Save servers to TOML config
  Future<void> saveServers(List<ServerConfig> servers) async {
    final file = File(_tomlConfigPath);
    await file.parent.create(recursive: true);

    final buffer = StringBuffer();
    buffer.writeln('# SSH Server Configuration');
    buffer.writeln('# Generated by MCP File Manager');
    buffer.writeln();

    for (final server in servers) {
      buffer.writeln('[ssh_servers.${server.name}]');
      buffer.writeln('host = "${server.host}"');
      buffer.writeln('user = "${server.user}"');
      buffer.writeln('port = ${server.port}');
      if (server.password != null && server.password!.isNotEmpty) {
        buffer.writeln('password = "${server.password}"');
      }
      if (server.keyPath != null && server.keyPath!.isNotEmpty) {
        buffer.writeln('key_path = "${server.keyPath}"');
      }
      if (server.defaultDir != null && server.defaultDir!.isNotEmpty) {
        buffer.writeln('default_dir = "${server.defaultDir}"');
      }
      if (server.sudoPassword != null && server.sudoPassword!.isNotEmpty) {
        buffer.writeln('sudo_password = "${server.sudoPassword}"');
      }
      buffer.writeln();
    }

    await file.writeAsString(buffer.toString());
  }

  /// Add a new server
  Future<void> addServer(ServerConfig server) async {
    final servers = await loadServers();
    servers.add(server);
    await saveServers(servers);
  }

  /// Update an existing server
  Future<void> updateServer(String originalName, ServerConfig server) async {
    final servers = await loadServers();
    final index = servers.indexWhere((s) => s.name == originalName);
    if (index >= 0) {
      servers[index] = server;
      await saveServers(servers);
    }
  }

  /// Delete a server
  Future<void> deleteServer(String name) async {
    final servers = await loadServers();
    servers.removeWhere((s) => s.name == name);
    await saveServers(servers);
  }

  /// Load tools configuration
  Future<ToolsConfig> loadToolsConfig() async {
    final file = File(_toolsConfigPath);
    if (!await file.exists()) {
      return ToolsConfig.defaultConfig();
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ToolsConfig.fromJson(json);
    } catch (e) {
      print('[ConfigService] Error loading tools config: $e');
      return ToolsConfig.defaultConfig();
    }
  }

  /// Save tools configuration
  Future<void> saveToolsConfig(ToolsConfig config) async {
    final file = File(_toolsConfigPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  /// Get tool groups with current enabled status
  Future<List<ToolGroupConfig>> getToolGroups() async {
    final config = await loadToolsConfig();
    return defaultToolGroups.map((group) {
      return group.copyWith(
        enabled: config.enabledGroups.contains(group.name),
      );
    }).toList();
  }

  /// Set tool group enabled status
  Future<void> setToolGroupEnabled(String groupName, bool enabled) async {
    final config = await loadToolsConfig();
    final enabledGroups = List<String>.from(config.enabledGroups);

    if (enabled && !enabledGroups.contains(groupName)) {
      enabledGroups.add(groupName);
    } else if (!enabled && enabledGroups.contains(groupName)) {
      enabledGroups.remove(groupName);
    }

    final newConfig = ToolsConfig(
      mode: 'custom',
      enabledGroups: enabledGroups,
      disabledTools: config.disabledTools,
    );
    await saveToolsConfig(newConfig);
  }

  /// Check Claude Code integration status
  Future<ClaudeCodeStatus> checkClaudeCodeStatus() async {
    final configFile = File(_claudeCodeConfigPath);

    if (!await configFile.exists()) {
      return ClaudeCodeStatus(
        isConfigured: false,
        hasSshManager: false,
        configPath: _claudeCodeConfigPath,
        errorMessage: 'Claude Code config file not found',
      );
    }

    try {
      final content = await configFile.readAsString();
      final config = jsonDecode(content) as Map<String, dynamic>;

      // Check for MCP servers configuration
      final mcpServers = config['mcpServers'] as Map<String, dynamic>?;
      if (mcpServers == null) {
        return ClaudeCodeStatus(
          isConfigured: true,
          hasSshManager: false,
          configPath: _claudeCodeConfigPath,
          errorMessage: 'No MCP servers configured',
          mcpConfig: config,
        );
      }

      // Check if ssh-manager is configured
      final hasSshManager = mcpServers.containsKey('ssh-manager');

      return ClaudeCodeStatus(
        isConfigured: true,
        hasSshManager: hasSshManager,
        configPath: _claudeCodeConfigPath,
        mcpConfig: config,
      );
    } catch (e) {
      return ClaudeCodeStatus(
        isConfigured: false,
        hasSshManager: false,
        configPath: _claudeCodeConfigPath,
        errorMessage: 'Error reading config: $e',
      );
    }
  }

  /// Get installation command for Claude Code
  String getClaudeCodeInstallCommand() {
    return 'claude mcp add ssh-manager node /path/to/mcp-ssh-manager/src/index.js';
  }
}

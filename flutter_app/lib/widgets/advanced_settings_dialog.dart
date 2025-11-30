import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/config_service.dart';

/// Advanced settings dialog with tabs for servers, tools, and Claude Code integration
class AdvancedSettingsDialog extends StatefulWidget {
  const AdvancedSettingsDialog({super.key});

  @override
  State<AdvancedSettingsDialog> createState() => _AdvancedSettingsDialogState();
}

class _AdvancedSettingsDialogState extends State<AdvancedSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ConfigService _configService = ConfigService();

  // Servers tab state
  List<ServerConfig> _servers = [];
  bool _loadingServers = true;

  // Tools tab state
  List<ToolGroupConfig> _toolGroups = [];
  bool _loadingTools = true;

  // Claude Code tab state
  ClaudeCodeStatus? _claudeCodeStatus;
  bool _loadingClaudeCode = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadServers(),
      _loadToolGroups(),
      _loadClaudeCodeStatus(),
    ]);
  }

  Future<void> _loadServers() async {
    setState(() => _loadingServers = true);
    try {
      final servers = await _configService.loadServers();
      setState(() {
        _servers = servers;
        _loadingServers = false;
      });
    } catch (e) {
      setState(() => _loadingServers = false);
      _showError('Failed to load servers: $e');
    }
  }

  Future<void> _loadToolGroups() async {
    setState(() => _loadingTools = true);
    try {
      final groups = await _configService.getToolGroups();
      setState(() {
        _toolGroups = groups;
        _loadingTools = false;
      });
    } catch (e) {
      setState(() => _loadingTools = false);
      _showError('Failed to load tools config: $e');
    }
  }

  Future<void> _loadClaudeCodeStatus() async {
    setState(() => _loadingClaudeCode = true);
    try {
      final status = await _configService.checkClaudeCodeStatus();
      setState(() {
        _claudeCodeStatus = status;
        _loadingClaudeCode = false;
      });
    } catch (e) {
      setState(() => _loadingClaudeCode = false);
      _showError('Failed to check Claude Code status: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedSettings01, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Advanced Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: HugeIcon(icon: HugeIcons.strokeRoundedServerStack01), text: 'SSH Servers'),
                Tab(icon: HugeIcon(icon: HugeIcons.strokeRoundedTools), text: 'MCP Tools'),
                Tab(icon: HugeIcon(icon: HugeIcons.strokeRoundedPlug01), text: 'Claude Code'),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildServersTab(),
                  _buildToolsTab(),
                  _buildClaudeCodeTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SERVERS TAB ====================

  Widget _buildServersTab() {
    if (_loadingServers) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with add button
          Row(
            children: [
              Text(
                'Configured Servers',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showServerDialog(),
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 18),
                label: const Text('Add Server'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Server list
          Expanded(
            child: _servers.isEmpty
                ? _buildEmptyServerState()
                : ListView.builder(
                    itemCount: _servers.length,
                    itemBuilder: (context, index) {
                      final server = _servers[index];
                      return _buildServerCard(server);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyServerState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedServerStack01,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No servers configured',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first SSH server to get started',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard(ServerConfig server) {
    final colorScheme = Theme.of(context).colorScheme;
    final authMethod = server.keyPath != null ? 'SSH Key' : 'Password';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: HugeIcon(icon: HugeIcons.strokeRoundedServerStack01, color: colorScheme.primary, size: 20),
        ),
        title: Text(
          server.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${server.user}@${server.host}:${server.port} ($authMethod)',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'JetBrainsMono',
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit01, size: 20),
              tooltip: 'Edit',
              onPressed: () => _showServerDialog(server: server),
            ),
            IconButton(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 20, color: colorScheme.error),
              tooltip: 'Delete',
              onPressed: () => _confirmDeleteServer(server),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showServerDialog({ServerConfig? server}) async {
    final result = await showDialog<ServerConfig>(
      context: context,
      builder: (context) => ServerEditDialog(server: server),
    );

    if (result != null) {
      try {
        if (server != null) {
          await _configService.updateServer(server.name, result);
        } else {
          await _configService.addServer(result);
        }
        await _loadServers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(server != null ? 'Server updated' : 'Server added'),
            ),
          );
        }
      } catch (e) {
        _showError('Failed to save server: $e');
      }
    }
  }

  Future<void> _confirmDeleteServer(ServerConfig server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Server'),
        content: Text('Are you sure you want to delete "${server.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _configService.deleteServer(server.name);
        await _loadServers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server deleted')),
          );
        }
      } catch (e) {
        _showError('Failed to delete server: $e');
      }
    }
  }

  // ==================== TOOLS TAB ====================

  Widget _buildToolsTab() {
    if (_loadingTools) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;
    final enabledCount = _toolGroups.where((g) => g.enabled).length;
    final totalTools = _toolGroups.where((g) => g.enabled).fold<int>(0, (sum, g) => sum + g.toolCount);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$enabledCount groups enabled ($totalTools tools available)',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ),
                TextButton(
                  onPressed: _enableAllGroups,
                  child: const Text('Enable All'),
                ),
                TextButton(
                  onPressed: _disableNonCore,
                  child: const Text('Minimal'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tool groups list
          Expanded(
            child: ListView.builder(
              itemCount: _toolGroups.length,
              itemBuilder: (context, index) {
                final group = _toolGroups[index];
                return _buildToolGroupCard(group);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolGroupCard(ToolGroupConfig group) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: CircleAvatar(
          backgroundColor: group.enabled
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          child: HugeIcon(
            icon: _getToolGroupIcon(group.name),
            color: group.enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              group.displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${group.toolCount} tools',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          group.description,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        value: group.enabled,
        onChanged: (value) => _toggleToolGroup(group.name, value),
      ),
    );
  }

  List<List<dynamic>> _getToolGroupIcon(String groupName) {
    switch (groupName) {
      case 'core':
        return HugeIcons.strokeRoundedStar;
      case 'sessions':
        return HugeIcons.strokeRoundedCommandLine;
      case 'monitoring':
        return HugeIcons.strokeRoundedActivity01;
      case 'backup':
        return HugeIcons.strokeRoundedArchive01;
      case 'database':
        return HugeIcons.strokeRoundedDatabase01;
      case 'advanced':
        return HugeIcons.strokeRoundedRocket01;
      default:
        return HugeIcons.strokeRoundedPuzzle;
    }
  }

  Future<void> _toggleToolGroup(String groupName, bool enabled) async {
    try {
      await _configService.setToolGroupEnabled(groupName, enabled);
      await _loadToolGroups();
    } catch (e) {
      _showError('Failed to update tool group: $e');
    }
  }

  Future<void> _enableAllGroups() async {
    for (final group in _toolGroups) {
      if (!group.enabled) {
        await _configService.setToolGroupEnabled(group.name, true);
      }
    }
    await _loadToolGroups();
  }

  Future<void> _disableNonCore() async {
    for (final group in _toolGroups) {
      await _configService.setToolGroupEnabled(group.name, group.name == 'core');
    }
    await _loadToolGroups();
  }

  // ==================== CLAUDE CODE TAB ====================

  Widget _buildClaudeCodeTab() {
    if (_loadingClaudeCode) {
      return const Center(child: CircularProgressIndicator());
    }

    final status = _claudeCodeStatus;
    if (status == null) {
      return const Center(child: Text('Failed to load status'));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          _buildStatusCard(status, colorScheme),
          const SizedBox(height: 24),

          // Config path
          Text(
            'Configuration Path',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    status.configPath ?? 'Unknown',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedCopy01, size: 18),
                  tooltip: 'Copy path',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: status.configPath ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Path copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Installation instructions if not configured
          if (!status.hasSshManager) ...[
            Text(
              'Installation',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To enable SSH Manager in Claude Code, run:',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _configService.getClaudeCodeInstallCommand(),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedCopy01, size: 18),
                    tooltip: 'Copy command',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: _configService.getClaudeCodeInstallCommand(),
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Command copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          // Refresh button
          const SizedBox(height: 24),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadClaudeCodeStatus,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('Refresh Status'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ClaudeCodeStatus status, ColorScheme colorScheme) {
    final isOk = status.isConfigured && status.hasSshManager;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOk
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOk ? Colors.green : Colors.orange,
        ),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: isOk ? HugeIcons.strokeRoundedCheckmarkCircle02 : HugeIcons.strokeRoundedAlert02,
            color: isOk ? Colors.green : Colors.orange,
            size: 48,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOk ? 'Claude Code Integration Active' : 'Configuration Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isOk ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOk
                      ? 'SSH Manager is properly configured in Claude Code'
                      : status.errorMessage ?? 'SSH Manager not found in Claude Code config',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== SERVER EDIT DIALOG ====================

class ServerEditDialog extends StatefulWidget {
  final ServerConfig? server;

  const ServerEditDialog({super.key, this.server});

  @override
  State<ServerEditDialog> createState() => _ServerEditDialogState();
}

class _ServerEditDialogState extends State<ServerEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _userController;
  late TextEditingController _portController;
  late TextEditingController _passwordController;
  late TextEditingController _keyPathController;
  late TextEditingController _defaultDirController;
  late TextEditingController _sudoPasswordController;

  bool _useKeyAuth = false;
  bool _showPassword = false;
  bool _showSudoPassword = false;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    _nameController = TextEditingController(text: server?.name ?? '');
    _hostController = TextEditingController(text: server?.host ?? '');
    _userController = TextEditingController(text: server?.user ?? '');
    _portController = TextEditingController(text: (server?.port ?? 22).toString());
    _passwordController = TextEditingController(text: server?.password ?? '');
    _keyPathController = TextEditingController(text: server?.keyPath ?? '');
    _defaultDirController = TextEditingController(text: server?.defaultDir ?? '');
    _sudoPasswordController = TextEditingController(text: server?.sudoPassword ?? '');
    _useKeyAuth = server?.keyPath != null && server!.keyPath!.isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _userController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    _keyPathController.dispose();
    _defaultDirController.dispose();
    _sudoPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.server != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Server' : 'Add Server'),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Server name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Server Name',
                    hintText: 'e.g., production, staging',
                    prefixIcon: HugeIcon(icon: HugeIcons.strokeRoundedTag01),
                  ),
                  enabled: !isEditing,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Server name is required';
                    }
                    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(value)) {
                      return 'Use letters, numbers, underscores only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Host
                TextFormField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: 'e.g., server.example.com',
                    prefixIcon: HugeIcon(icon: HugeIcons.strokeRoundedServerStack01),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Host is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // User and Port
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _userController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: HugeIcon(icon: HugeIcons.strokeRoundedUser),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Username is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final port = int.tryParse(value);
                          if (port == null || port < 1 || port > 65535) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Auth method toggle
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Password'),
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedKey01),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('SSH Key'),
                      icon: HugeIcon(icon: HugeIcons.strokeRoundedKey01),
                    ),
                  ],
                  selected: {_useKeyAuth},
                  onSelectionChanged: (value) {
                    setState(() => _useKeyAuth = value.first);
                  },
                ),
                const SizedBox(height: 16),

                // Password or Key Path
                if (_useKeyAuth)
                  TextFormField(
                    controller: _keyPathController,
                    decoration: const InputDecoration(
                      labelText: 'SSH Key Path',
                      hintText: '~/.ssh/id_rsa',
                      prefixIcon: HugeIcon(icon: HugeIcons.strokeRoundedKey01),
                    ),
                    validator: (value) {
                      if (_useKeyAuth && (value == null || value.isEmpty)) {
                        return 'Key path is required';
                      }
                      return null;
                    },
                  )
                else
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedKey01),
                      suffixIcon: IconButton(
                        icon: HugeIcon(icon: _showPassword ? HugeIcons.strokeRoundedViewOffSlash : HugeIcons.strokeRoundedView),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    obscureText: !_showPassword,
                    validator: (value) {
                      if (!_useKeyAuth && (value == null || value.isEmpty)) {
                        return 'Password is required';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),

                // Optional fields
                ExpansionTile(
                  title: const Text('Advanced Options'),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    TextFormField(
                      controller: _defaultDirController,
                      decoration: const InputDecoration(
                        labelText: 'Default Directory (optional)',
                        hintText: '/var/www/myapp',
                        prefixIcon: HugeIcon(icon: HugeIcons.strokeRoundedFolder01),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sudoPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Sudo Password (optional)',
                        prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedShieldUser),
                        suffixIcon: IconButton(
                          icon: HugeIcon(icon: _showSudoPassword ? HugeIcons.strokeRoundedViewOffSlash : HugeIcons.strokeRoundedView),
                          onPressed: () => setState(() => _showSudoPassword = !_showSudoPassword),
                        ),
                      ),
                      obscureText: !_showSudoPassword,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final server = ServerConfig(
        name: _nameController.text.trim(),
        host: _hostController.text.trim(),
        user: _userController.text.trim(),
        port: int.parse(_portController.text.trim()),
        password: _useKeyAuth ? null : _passwordController.text,
        keyPath: _useKeyAuth ? _keyPathController.text.trim() : null,
        defaultDir: _defaultDirController.text.trim().isEmpty
            ? null
            : _defaultDirController.text.trim(),
        sudoPassword: _sudoPasswordController.text.isEmpty
            ? null
            : _sudoPasswordController.text,
      );
      Navigator.of(context).pop(server);
    }
  }
}

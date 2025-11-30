import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../mcp/mcp_client.dart';
import 'server_selector.dart';

/// Remote file browser widget with server selector - Finder-like design
class RemoteFileBrowser extends StatefulWidget {
  final McpClient client;
  final List<SshServer> servers;
  final Function(RemoteFile, SshServer)? onFileSelected;
  final Function(List<RemoteFile>, SshServer)? onFilesSelected;

  const RemoteFileBrowser({
    super.key,
    required this.client,
    required this.servers,
    this.onFileSelected,
    this.onFilesSelected,
  });

  @override
  State<RemoteFileBrowser> createState() => _RemoteFileBrowserState();
}

class _RemoteFileBrowserState extends State<RemoteFileBrowser> {
  SshServer? _selectedServer;
  String _currentPath = '~';
  List<RemoteFile> _files = [];
  Set<String> _selectedFiles = {};
  bool _isLoading = false;
  String? _error;
  bool _showHidden = false;

  // Convert SshServer list to ServerInfo list for the selector
  List<ServerInfo> get _serverInfos {
    return widget.servers.map((s) => ServerInfo(
      name: s.name,
      host: s.host,
      user: s.user,
      defaultDir: s.defaultDir,
    )).toList();
  }

  Future<void> _loadFiles() async {
    if (_selectedServer == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.client.listFiles(
        _selectedServer!.name,
        path: _currentPath,
        showHidden: _showHidden,
      );

      setState(() {
        _files = result.files;
        _currentPath = result.path;
        _isLoading = false;
        _selectedFiles.clear();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateTo(String newPath) {
    setState(() {
      _currentPath = newPath;
    });
    _loadFiles();
  }

  void _navigateUp() {
    if (_currentPath == '/' || _currentPath == '~' || _currentPath == '\$HOME') return;
    final parts = _currentPath.split('/');
    if (parts.length > 1) {
      parts.removeLast();
      final parent = parts.isEmpty ? '/' : parts.join('/');
      _navigateTo(parent);
    }
  }

  void _openItem(RemoteFile file) {
    if (file.isDirectory) {
      final newPath = _currentPath.endsWith('/')
          ? '$_currentPath${file.name}'
          : '$_currentPath/${file.name}';
      _navigateTo(newPath);
    } else {
      widget.onFileSelected?.call(file, _selectedServer!);
    }
  }

  void _toggleSelection(RemoteFile file) {
    setState(() {
      final key = '$_currentPath/${file.name}';
      if (_selectedFiles.contains(key)) {
        _selectedFiles.remove(key);
      } else {
        _selectedFiles.add(key);
      }
    });

    // Notify parent of selection change
    final selectedRemoteFiles = _files
        .where((f) => _selectedFiles.contains('$_currentPath/${f.name}'))
        .toList();
    widget.onFilesSelected?.call(selectedRemoteFiles, _selectedServer!);
  }

  void _selectServer(ServerInfo serverInfo) {
    // Find the matching SshServer
    final server = widget.servers.firstWhere(
      (s) => s.name == serverInfo.name,
      orElse: () => widget.servers.first,
    );

    setState(() {
      _selectedServer = server;
      _currentPath = server.defaultDir ?? '~';
      _files = [];
      _selectedFiles.clear();
    });
    _loadFiles();
  }

  void _disconnectServer() {
    setState(() {
      _selectedServer = null;
      _currentPath = '~';
      _files = [];
      _selectedFiles.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Show server selector if no server is selected
    if (_selectedServer == null) {
      return ServerSelector(
        servers: _serverInfos,
        onServerSelected: _selectServer,
        isLoading: false,
      );
    }

    // Show file browser when server is selected
    return Column(
      children: [
        // Connected server header with disconnect button
        _buildConnectedServerHeader(colorScheme),

        // Header with path breadcrumb
        _buildHeader(colorScheme),

        // Column headers
        _buildColumnHeaders(colorScheme),

        // File list
        Expanded(
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : _error != null
                  ? _buildErrorView(colorScheme)
                  : _buildFileList(colorScheme),
        ),

        // Status bar
        _buildStatusBar(colorScheme),
      ],
    );
  }

  Widget _buildConnectedServerHeader(ColorScheme colorScheme) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.checkmark_circle_fill, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_selectedServer!.name} (${_selectedServer!.user}@${_selectedServer!.host})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Disconnect button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minSize: 28,
            onPressed: _disconnectServer,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.xmark_circle, size: 14, color: colorScheme.error),
                const SizedBox(width: 4),
                Text(
                  'Disconnect',
                  style: TextStyle(fontSize: 11, color: colorScheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    final pathParts = _currentPath.split('/').where((p) => p.isNotEmpty && p != '\$HOME').toList();
    final isHome = _currentPath == '~' || _currentPath == '\$HOME' || _currentPath.isEmpty;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Navigation buttons
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 16),
            onPressed: _navigateUp,
            tooltip: 'Go up',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.home, size: 16),
            onPressed: () => _navigateTo('~'),
            tooltip: 'Home',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            onPressed: _loadFiles,
            tooltip: 'Refresh',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          // Default directory button if available
          if (_selectedServer?.defaultDir != null)
            IconButton(
              icon: const Icon(Icons.folder_special, size: 16),
              onPressed: () => _navigateTo(_selectedServer!.defaultDir!),
              tooltip: 'Default directory',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          const SizedBox(width: 8),

          // Breadcrumb path
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Root/Home
                  InkWell(
                    onTap: () => _navigateTo(isHome ? '/' : '~'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        isHome ? Icons.home : Icons.storage,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  // Path parts
                  if (!isHome)
                    for (var i = 0; i < pathParts.length; i++) ...[
                      Icon(Icons.chevron_right, size: 14, color: colorScheme.onSurfaceVariant),
                      InkWell(
                        onTap: () {
                          final newPath = '/${pathParts.sublist(0, i + 1).join('/')}';
                          _navigateTo(newPath);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            pathParts[i],
                            style: TextStyle(
                              fontSize: 12,
                              color: i == pathParts.length - 1
                                  ? colorScheme.onSurface
                                  : colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ),

          // Show hidden toggle
          IconButton(
            icon: Icon(
              _showHidden ? Icons.visibility : Icons.visibility_off,
              size: 16,
              color: _showHidden ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              setState(() => _showHidden = !_showHidden);
              _loadFiles();
            },
            tooltip: _showHidden ? 'Hide hidden files' : 'Show hidden files',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(ColorScheme colorScheme) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            flex: 3,
            child: Text('Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant)),
          ),
          SizedBox(
            width: 100,
            child: Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant)),
          ),
          SizedBox(
            width: 70,
            child: Text('Size', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(ColorScheme colorScheme) {
    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text('Empty folder', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final key = '$_currentPath/${file.name}';
        final isSelected = _selectedFiles.contains(key);

        return _buildFileRow(file, isSelected, colorScheme);
      },
    );
  }

  Widget _buildFileRow(RemoteFile file, bool isSelected, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _toggleSelection(file),
      onDoubleTap: () => _openItem(file),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer.withOpacity(0.5) : null,
        ),
        child: Row(
          children: [
            // Icon
            SizedBox(
              width: 24,
              child: Icon(
                _getFileIcon(file),
                size: 16,
                color: _getFileIconColor(file, colorScheme),
              ),
            ),
            // Name
            Expanded(
              flex: 3,
              child: Text(
                file.name,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Date
            SizedBox(
              width: 100,
              child: Text(
                _formatDate(file.modified),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            // Size
            SizedBox(
              width: 70,
              child: Text(
                file.formattedSize,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String modified) {
    try {
      final date = DateTime.parse(modified);
      return DateFormat('dd.MM.yy HH:mm').format(date);
    } catch (e) {
      return modified;
    }
  }

  IconData _getFileIcon(RemoteFile file) {
    if (file.isDirectory) return Icons.folder;
    if (file.isLink) return Icons.link;

    final ext = file.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'svg':
      case 'webp':
        return Icons.image;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
        return Icons.folder_zip;
      case 'js':
      case 'ts':
      case 'py':
      case 'dart':
      case 'java':
      case 'c':
      case 'cpp':
      case 'rs':
      case 'go':
        return Icons.code;
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
      case 'toml':
        return Icons.data_object;
      case 'css':
        return Icons.css;
      case 'html':
        return Icons.html;
      case 'md':
      case 'txt':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(RemoteFile file, ColorScheme colorScheme) {
    if (file.isDirectory) return Colors.blue;
    if (file.isLink) return Colors.teal;

    final ext = file.name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'svg':
        return Colors.purple;
      case 'mp3':
      case 'wav':
        return Colors.orange;
      case 'mp4':
      case 'mkv':
        return Colors.pink;
      case 'zip':
      case 'tar':
      case 'gz':
        return Colors.brown;
      case 'js':
      case 'ts':
        return Colors.amber;
      case 'py':
        return Colors.blue;
      case 'dart':
        return Colors.cyan;
      case 'css':
        return Colors.blue;
      case 'html':
        return Colors.orange;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 8),
          Text(
            'Cannot access folder',
            style: TextStyle(color: colorScheme.error),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              _error ?? '',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _navigateUp,
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ColorScheme colorScheme) {
    final totalItems = _files.length;
    final selectedCount = _selectedFiles.length;
    final selectedSize = _files
        .where((f) => _selectedFiles.contains('$_currentPath/${f.name}'))
        .fold<int>(0, (sum, f) => sum + f.size);

    String statusText;
    if (selectedCount > 0) {
      final sizeStr = _formatSize(selectedSize);
      statusText = '$selectedCount selected ($sizeStr)';
    } else {
      statusText = '$totalItems items';
    }

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            statusText,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            _selectedServer!.name,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

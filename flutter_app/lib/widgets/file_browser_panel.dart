import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../mcp/mcp_client.dart';
import '../providers/file_browser_provider.dart';
import '../providers/transfer_provider.dart';
import 'file_list_view.dart';
import 'new_folder_dialog.dart';
import 'rename_dialog.dart';

class FileBrowserPanel extends StatefulWidget {
  final McpClient client;
  final SshServer server;

  const FileBrowserPanel({
    super.key,
    required this.client,
    required this.server,
  });

  @override
  State<FileBrowserPanel> createState() => _FileBrowserPanelState();
}

class _FileBrowserPanelState extends State<FileBrowserPanel> {
  late FileBrowserProvider _provider;
  late TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _provider = FileBrowserProvider(
      client: widget.client,
      serverName: widget.server.name,
      initialPath: widget.server.defaultDir ?? '~',
    );
    _pathController = TextEditingController(text: _provider.currentPath);

    _provider.addListener(_updatePathController);
  }

  void _updatePathController() {
    if (_pathController.text != _provider.currentPath) {
      _pathController.text = _provider.currentPath;
    }
  }

  @override
  void didUpdateWidget(FileBrowserPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.server.name != widget.server.name) {
      _provider.removeListener(_updatePathController);
      _provider = FileBrowserProvider(
        client: widget.client,
        serverName: widget.server.name,
        initialPath: widget.server.defaultDir ?? '~',
      );
      _pathController.text = _provider.currentPath;
      _provider.addListener(_updatePathController);
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_updatePathController);
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<FileBrowserProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Navigation bar
              _buildNavigationBar(context, provider),

              // Toolbar
              _buildToolbar(context, provider),

              // File list
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.error != null
                        ? _buildError(context, provider)
                        : FileListView(
                            files: provider.files,
                            selectedFiles: provider.selectedFiles,
                            sortField: provider.sortField,
                            sortAscending: provider.sortAscending,
                            onFileDoubleTap: provider.open,
                            onFileSelect: provider.toggleSelection,
                            onSortChanged: provider.setSortField,
                            onContextMenu: (file, offset) =>
                                _showContextMenu(context, provider, file, offset),
                          ),
              ),

              // Status bar
              _buildStatusBar(context, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context, FileBrowserProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Navigation buttons
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: provider.canGoBack ? provider.goBack : null,
            tooltip: 'Back',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 20),
            onPressed: provider.canGoForward ? provider.goForward : null,
            tooltip: 'Forward',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 20),
            onPressed: provider.goUp,
            tooltip: 'Go Up',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),

          // Path input
          Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: TextField(
                controller: _pathController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.folder,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  hintText: 'Path',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
                onSubmitted: (value) {
                  provider.navigateTo(value.trim());
                },
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: provider.refresh,
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, FileBrowserProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = provider.selectedFiles.isNotEmpty;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // New folder
          _ToolbarButton(
            icon: Icons.create_new_folder_outlined,
            label: 'New Folder',
            onPressed: () => _showNewFolderDialog(context, provider),
          ),
          const SizedBox(width: 4),

          // Delete
          _ToolbarButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            onPressed: hasSelection
                ? () => _confirmDelete(context, provider)
                : null,
          ),
          const SizedBox(width: 4),

          // Rename
          _ToolbarButton(
            icon: Icons.drive_file_rename_outline,
            label: 'Rename',
            onPressed: provider.selectedFiles.length == 1
                ? () => _showRenameDialog(context, provider)
                : null,
          ),

          const Spacer(),

          // Hidden files toggle
          _ToolbarButton(
            icon: provider.showHidden
                ? Icons.visibility
                : Icons.visibility_off_outlined,
            label: provider.showHidden ? 'Hide Hidden' : 'Show Hidden',
            onPressed: provider.toggleHidden,
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, FileBrowserProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load directory',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.error ?? 'Unknown error',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: provider.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context, FileBrowserProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileCount = provider.files.length;
    final selectedCount = provider.selectedFiles.length;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.computer,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            widget.server.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$fileCount items',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (selectedCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$selectedCount selected',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, FileBrowserProvider provider,
      RemoteFile file, Offset offset) {
    final colorScheme = Theme.of(context).colorScheme;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + 1,
        offset.dy + 1,
      ),
      items: [
        if (file.isDirectory)
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.folder_open, size: 20),
                SizedBox(width: 12),
                Text('Open'),
              ],
            ),
            onTap: () => provider.open(file),
          ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.drive_file_rename_outline, size: 20),
              SizedBox(width: 12),
              Text('Rename'),
            ],
          ),
          onTap: () {
            // Need to delay to allow menu to close
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                provider.clearSelection();
                provider.toggleSelection(file.name);
                _showRenameDialog(context, provider);
              }
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
              const SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: colorScheme.error)),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (context.mounted) {
                provider.clearSelection();
                provider.toggleSelection(file.name);
                _confirmDelete(context, provider);
              }
            });
          },
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 12),
              Text('Properties'),
            ],
          ),
          onTap: () => _showFileProperties(context, provider, file),
        ),
      ],
    );
  }

  void _showNewFolderDialog(
      BuildContext context, FileBrowserProvider provider) {
    showDialog(
      context: context,
      builder: (context) => NewFolderDialog(
        onSubmit: (name) async {
          final success = await provider.createDirectory(name);
          return success;
        },
      ),
    );
  }

  void _showRenameDialog(BuildContext context, FileBrowserProvider provider) {
    if (provider.selectedFiles.isEmpty) return;

    final fileName = provider.selectedFiles.first;
    showDialog(
      context: context,
      builder: (context) => RenameDialog(
        currentName: fileName,
        onSubmit: (newName) async {
          final success = await provider.rename(fileName, newName);
          return success;
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, FileBrowserProvider provider) async {
    final count = provider.selectedFiles.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          count == 1
              ? 'Are you sure you want to delete "${provider.selectedFiles.first}"?'
              : 'Are you sure you want to delete $count items?',
        ),
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
      await provider.deleteSelected();
    }
  }

  void _showFileProperties(
      BuildContext context, FileBrowserProvider provider, RemoteFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              file.isDirectory ? Icons.folder : Icons.insert_drive_file,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                file.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PropertyRow(label: 'Type', value: file.isDirectory ? 'Directory' : 'File'),
            _PropertyRow(label: 'Size', value: file.formattedSize),
            _PropertyRow(label: 'Modified', value: file.modified),
            _PropertyRow(label: 'Permissions', value: file.permissions),
            _PropertyRow(
              label: 'Path',
              value: provider.getFullPath(file.name),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: onPressed != null
            ? colorScheme.onSurface
            : colorScheme.onSurface.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  final String label;
  final String value;

  const _PropertyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:hugeicons/hugeicons.dart';

import '../mcp/mcp_client.dart';
import '../providers/file_browser_provider.dart';

class FileListView extends StatelessWidget {
  final List<RemoteFile> files;
  final Set<String> selectedFiles;
  final FileSortField sortField;
  final bool sortAscending;
  final ValueChanged<RemoteFile> onFileDoubleTap;
  final ValueChanged<String> onFileSelect;
  final ValueChanged<FileSortField> onSortChanged;
  final void Function(RemoteFile file, Offset offset) onContextMenu;

  const FileListView({
    super.key,
    required this.files,
    required this.selectedFiles,
    required this.sortField,
    required this.sortAscending,
    required this.onFileDoubleTap,
    required this.onFileSelect,
    required this.onSortChanged,
    required this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedFolderOpen,
              size: 64,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Empty directory',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        _buildHeader(context),

        // File list
        Expanded(
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final isSelected = selectedFiles.contains(file.name);

              return _FileListItem(
                file: file,
                isSelected: isSelected,
                onTap: () => onFileSelect(file.name),
                onDoubleTap: () => onFileDoubleTap(file),
                onContextMenu: (offset) => onContextMenu(file, offset),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Name column
          Expanded(
            flex: 4,
            child: _HeaderCell(
              label: 'Name',
              sortField: FileSortField.name,
              currentSortField: sortField,
              sortAscending: sortAscending,
              onTap: () => onSortChanged(FileSortField.name),
            ),
          ),

          // Size column
          SizedBox(
            width: 100,
            child: _HeaderCell(
              label: 'Size',
              sortField: FileSortField.size,
              currentSortField: sortField,
              sortAscending: sortAscending,
              onTap: () => onSortChanged(FileSortField.size),
              alignment: Alignment.centerRight,
            ),
          ),

          // Modified column
          SizedBox(
            width: 150,
            child: _HeaderCell(
              label: 'Modified',
              sortField: FileSortField.modified,
              currentSortField: sortField,
              sortAscending: sortAscending,
              onTap: () => onSortChanged(FileSortField.modified),
            ),
          ),

          // Permissions column
          SizedBox(
            width: 100,
            child: _HeaderCell(
              label: 'Permissions',
              sortField: FileSortField.type,
              currentSortField: sortField,
              sortAscending: sortAscending,
              onTap: () => onSortChanged(FileSortField.type),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final FileSortField sortField;
  final FileSortField currentSortField;
  final bool sortAscending;
  final VoidCallback onTap;
  final Alignment alignment;

  const _HeaderCell({
    required this.label,
    required this.sortField,
    required this.currentSortField,
    required this.sortAscending,
    required this.onTap,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = sortField == currentSortField;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              HugeIcon(
                icon: sortAscending ? HugeIcons.strokeRoundedArrowUp01 : HugeIcons.strokeRoundedArrowDown01,
                size: 14,
                color: colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final RemoteFile file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(Offset offset) onContextMenu;

  const _FileListItem({
    required this.file,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onSecondaryTapDown: (details) {
        onContextMenu(details.globalPosition);
      },
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                // Icon + Name
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      _getFileIcon(colorScheme),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Size
                SizedBox(
                  width: 100,
                  child: Text(
                    file.formattedSize,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                // Modified
                SizedBox(
                  width: 150,
                  child: Text(
                    file.modified,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                // Permissions
                SizedBox(
                  width: 100,
                  child: Text(
                    file.permissions,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getFileIcon(ColorScheme colorScheme) {
    if (file.isDirectory) {
      return HugeIcon(
        icon: HugeIcons.strokeRoundedFolder01,
        size: 20,
        color: Colors.amber.shade700,
      );
    }

    if (file.isLink) {
      return HugeIcon(
        icon: HugeIcons.strokeRoundedLink01,
        size: 20,
        color: colorScheme.primary,
      );
    }

    final iconData = _getIconForFileType(file.icon);
    return HugeIcon(
      icon: iconData,
      size: 20,
      color: colorScheme.onSurfaceVariant,
    );
  }

  IconData _getIconForFileType(String type) {
    switch (type) {
      case 'text':
        return HugeIcons.strokeRoundedFileScript;
      case 'code':
        return HugeIcons.strokeRoundedSourceCode;
      case 'config':
        return HugeIcons.strokeRoundedSettings02;
      case 'image':
        return HugeIcons.strokeRoundedImage01;
      case 'audio':
        return HugeIcons.strokeRoundedMusicNote01;
      case 'video':
        return HugeIcons.strokeRoundedVideo01;
      case 'archive':
        return HugeIcons.strokeRoundedFolderZip;
      case 'pdf':
        return HugeIcons.strokeRoundedPdf01;
      case 'word':
        return HugeIcons.strokeRoundedTxt01;
      case 'excel':
        return HugeIcons.strokeRoundedXls01;
      default:
        return HugeIcons.strokeRoundedFile01;
    }
  }
}

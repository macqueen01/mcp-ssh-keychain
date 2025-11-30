import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/transfer_provider.dart';

class TransferPanel extends StatefulWidget {
  const TransferPanel({super.key});

  @override
  State<TransferPanel> createState() => _TransferPanelState();
}

class _TransferPanelState extends State<TransferPanel> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<TransferProvider>();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.swap_vert,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Transfers',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (provider.hasActiveTransfers) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${provider.activeCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (provider.transfers.isNotEmpty)
                    TextButton.icon(
                      onPressed: provider.clearCompleted,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Transfer list
          if (_isExpanded)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: provider.transfers.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: provider.transfers.length,
                      itemBuilder: (context, index) {
                        final transfer = provider.transfers[index];
                        return _TransferItem(
                          transfer: transfer,
                          onCancel: () => provider.cancelTransfer(transfer.id),
                          onRetry: () => provider.retryTransfer(transfer.id),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 80,
      alignment: Alignment.center,
      child: Text(
        'No transfers',
        style: TextStyle(
          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
      ),
    );
  }
}

class _TransferItem extends StatelessWidget {
  final TransferItem transfer;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const _TransferItem({
    required this.transfer,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getStatusColor(colorScheme).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              transfer.type == TransferType.upload
                  ? Icons.upload
                  : Icons.download,
              size: 18,
              color: _getStatusColor(colorScheme),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transfer.fileName,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${transfer.typeText} • ${transfer.serverName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: transfer.status),
                  ],
                ),
              ],
            ),
          ),

          // Progress or actions
          if (transfer.status == TransferStatus.inProgress)
            SizedBox(
              width: 60,
              child: Column(
                children: [
                  Text(
                    '${(transfer.progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: transfer.progress,
                    minHeight: 2,
                  ),
                ],
              ),
            )
          else if (transfer.status == TransferStatus.pending)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onCancel,
              tooltip: 'Cancel',
              visualDensity: VisualDensity.compact,
            )
          else if (transfer.status == TransferStatus.failed)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: onRetry,
              tooltip: 'Retry',
              visualDensity: VisualDensity.compact,
            )
          else if (transfer.status == TransferStatus.completed)
            Icon(
              Icons.check_circle,
              size: 20,
              color: Colors.green,
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(ColorScheme colorScheme) {
    switch (transfer.status) {
      case TransferStatus.pending:
        return colorScheme.onSurfaceVariant;
      case TransferStatus.inProgress:
        return colorScheme.primary;
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return colorScheme.error;
      case TransferStatus.cancelled:
        return colorScheme.onSurfaceVariant;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final TransferStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color color;
    String text;

    switch (status) {
      case TransferStatus.pending:
        color = colorScheme.onSurfaceVariant;
        text = 'Pending';
        break;
      case TransferStatus.inProgress:
        color = colorScheme.primary;
        text = 'Transferring';
        break;
      case TransferStatus.completed:
        color = Colors.green;
        text = 'Completed';
        break;
      case TransferStatus.failed:
        color = colorScheme.error;
        text = 'Failed';
        break;
      case TransferStatus.cancelled:
        color = colorScheme.onSurfaceVariant;
        text = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
        ),
      ),
    );
  }
}

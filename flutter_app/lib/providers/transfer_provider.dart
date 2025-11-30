import 'package:flutter/foundation.dart';
import '../mcp/mcp_client.dart';

/// Transfer operation types
enum TransferType { upload, download }

/// Transfer status
enum TransferStatus { pending, inProgress, completed, failed, cancelled }

/// Transfer item
class TransferItem {
  final String id;
  final TransferType type;
  final String serverName;
  final String localPath;
  final String remotePath;
  final String fileName;
  TransferStatus status;
  double progress;
  String? error;
  DateTime createdAt;
  DateTime? completedAt;

  TransferItem({
    required this.id,
    required this.type,
    required this.serverName,
    required this.localPath,
    required this.remotePath,
    required this.fileName,
    this.status = TransferStatus.pending,
    this.progress = 0.0,
    this.error,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get statusText {
    switch (status) {
      case TransferStatus.pending:
        return 'Pending';
      case TransferStatus.inProgress:
        return '${(progress * 100).toStringAsFixed(0)}%';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get typeText => type == TransferType.upload ? 'Upload' : 'Download';
}

/// Provider for managing file transfers
class TransferProvider extends ChangeNotifier {
  final McpClient _client;

  final List<TransferItem> _transfers = [];
  int _activeTransfers = 0;
  final int _maxConcurrent = 3;
  int _idCounter = 0;

  // Getters
  List<TransferItem> get transfers => List.unmodifiable(_transfers);
  List<TransferItem> get pendingTransfers =>
      _transfers.where((t) => t.status == TransferStatus.pending).toList();
  List<TransferItem> get activeTransfers =>
      _transfers.where((t) => t.status == TransferStatus.inProgress).toList();
  List<TransferItem> get completedTransfers => _transfers
      .where((t) =>
          t.status == TransferStatus.completed ||
          t.status == TransferStatus.failed ||
          t.status == TransferStatus.cancelled)
      .toList();
  int get activeCount => _activeTransfers;
  bool get hasActiveTransfers => _activeTransfers > 0;

  TransferProvider({required McpClient client}) : _client = client;

  /// Queue an upload
  Future<void> queueUpload({
    required String serverName,
    required String localPath,
    required String remotePath,
    required String fileName,
  }) async {
    final transfer = TransferItem(
      id: 'transfer_${++_idCounter}',
      type: TransferType.upload,
      serverName: serverName,
      localPath: localPath,
      remotePath: remotePath,
      fileName: fileName,
    );

    _transfers.insert(0, transfer);
    notifyListeners();

    _processQueue();
  }

  /// Queue a download
  Future<void> queueDownload({
    required String serverName,
    required String remotePath,
    required String localPath,
    required String fileName,
  }) async {
    final transfer = TransferItem(
      id: 'transfer_${++_idCounter}',
      type: TransferType.download,
      serverName: serverName,
      localPath: localPath,
      remotePath: remotePath,
      fileName: fileName,
    );

    _transfers.insert(0, transfer);
    notifyListeners();

    _processQueue();
  }

  /// Process the transfer queue
  Future<void> _processQueue() async {
    if (_activeTransfers >= _maxConcurrent) return;

    final pending = _transfers.firstWhere(
      (t) => t.status == TransferStatus.pending,
      orElse: () => TransferItem(
        id: '',
        type: TransferType.download,
        serverName: '',
        localPath: '',
        remotePath: '',
        fileName: '',
        status: TransferStatus.completed,
      ),
    );

    if (pending.status != TransferStatus.pending) return;

    _activeTransfers++;
    pending.status = TransferStatus.inProgress;
    pending.progress = 0.1; // Show some progress
    notifyListeners();

    try {
      if (pending.type == TransferType.upload) {
        await _client.callTool('ssh_upload', {
          'server': pending.serverName,
          'localPath': pending.localPath,
          'remotePath': pending.remotePath,
        });
      } else {
        await _client.callTool('ssh_download', {
          'server': pending.serverName,
          'remotePath': pending.remotePath,
          'localPath': pending.localPath,
        });
      }

      pending.status = TransferStatus.completed;
      pending.progress = 1.0;
      pending.completedAt = DateTime.now();
    } catch (e) {
      pending.status = TransferStatus.failed;
      pending.error = e.toString();
    } finally {
      _activeTransfers--;
      notifyListeners();

      // Process next item in queue
      _processQueue();
    }
  }

  /// Cancel a transfer
  void cancelTransfer(String id) {
    final transfer = _transfers.firstWhere(
      (t) => t.id == id,
      orElse: () => TransferItem(
        id: '',
        type: TransferType.download,
        serverName: '',
        localPath: '',
        remotePath: '',
        fileName: '',
      ),
    );

    if (transfer.id.isEmpty) return;

    if (transfer.status == TransferStatus.pending) {
      transfer.status = TransferStatus.cancelled;
      notifyListeners();
    }
    // Note: Cancelling in-progress transfers would require
    // additional implementation with AbortController or similar
  }

  /// Retry a failed transfer
  void retryTransfer(String id) {
    final index = _transfers.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final transfer = _transfers[index];
    if (transfer.status != TransferStatus.failed &&
        transfer.status != TransferStatus.cancelled) {
      return;
    }

    transfer.status = TransferStatus.pending;
    transfer.progress = 0.0;
    transfer.error = null;
    notifyListeners();

    _processQueue();
  }

  /// Clear completed transfers
  void clearCompleted() {
    _transfers.removeWhere((t) =>
        t.status == TransferStatus.completed ||
        t.status == TransferStatus.failed ||
        t.status == TransferStatus.cancelled);
    notifyListeners();
  }

  /// Clear all transfers
  void clearAll() {
    _transfers.removeWhere((t) => t.status != TransferStatus.inProgress);
    notifyListeners();
  }
}

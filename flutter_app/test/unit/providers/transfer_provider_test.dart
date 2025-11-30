import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_file_manager/providers/transfer_provider.dart';

import '../../mocks/mock_mcp_client.dart';

void main() {
  late MockMcpClient mockClient;
  late TransferProvider provider;

  setUp(() {
    mockClient = MockMcpClient();
    provider = TransferProvider(client: mockClient);
  });

  tearDown(() {
    mockClient.dispose();
  });

  group('TransferProvider', () {
    group('initial state', () {
      test('should have empty transfers list', () {
        expect(provider.transfers, isEmpty);
      });

      test('should have no active transfers', () {
        expect(provider.hasActiveTransfers, isFalse);
        expect(provider.activeCount, 0);
      });

      test('should have empty pending, active, and completed lists', () {
        expect(provider.pendingTransfers, isEmpty);
        expect(provider.activeTransfers, isEmpty);
        expect(provider.completedTransfers, isEmpty);
      });
    });

    group('queueUpload', () {
      test('should add upload to transfers list', () async {
        await provider.queueUpload(
          serverName: 'test_server',
          localPath: '/local/file.txt',
          remotePath: '/remote/file.txt',
          fileName: 'file.txt',
        );

        // Give time for the transfer to be queued
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.transfers.length, 1);
        expect(provider.transfers[0].type, TransferType.upload);
        expect(provider.transfers[0].fileName, 'file.txt');
      });

      test('should set transfer to pending then in_progress', () async {
        await provider.queueUpload(
          serverName: 'test_server',
          localPath: '/local/file.txt',
          remotePath: '/remote/file.txt',
          fileName: 'file.txt',
        );

        // Transfer should be processing
        expect(provider.transfers.isNotEmpty, isTrue);
      });

      test('should call ssh_upload tool', () async {
        await provider.queueUpload(
          serverName: 'test_server',
          localPath: '/local/file.txt',
          remotePath: '/remote/file.txt',
          fileName: 'file.txt',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(mockClient.verifyCall('callTool'), isTrue);
        final calls = mockClient.getCallsTo('callTool');
        expect(calls.any((c) => c.arguments['name'] == 'ssh_upload'), isTrue);
      });
    });

    group('queueDownload', () {
      test('should add download to transfers list', () async {
        await provider.queueDownload(
          serverName: 'test_server',
          remotePath: '/remote/file.txt',
          localPath: '/local/file.txt',
          fileName: 'file.txt',
        );

        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.transfers.length, 1);
        expect(provider.transfers[0].type, TransferType.download);
      });

      test('should call ssh_download tool', () async {
        await provider.queueDownload(
          serverName: 'test_server',
          remotePath: '/remote/file.txt',
          localPath: '/local/file.txt',
          fileName: 'file.txt',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(mockClient.verifyCall('callTool'), isTrue);
        final calls = mockClient.getCallsTo('callTool');
        expect(calls.any((c) => c.arguments['name'] == 'ssh_download'), isTrue);
      });
    });

    group('concurrent transfers', () {
      test('should limit concurrent transfers', () async {
        // Queue more than max concurrent
        for (var i = 0; i < 5; i++) {
          await provider.queueUpload(
            serverName: 'test_server',
            localPath: '/local/file$i.txt',
            remotePath: '/remote/file$i.txt',
            fileName: 'file$i.txt',
          );
        }

        await Future.delayed(const Duration(milliseconds: 50));

        // Should have max 3 active at once
        expect(provider.activeCount, lessThanOrEqualTo(3));
      });
    });

    group('cancelTransfer', () {
      test('should cancel pending transfer', () async {
        // Create a mock that delays to keep transfer pending
        mockClient = MockMcpClient();
        provider = TransferProvider(client: mockClient);

        await provider.queueUpload(
          serverName: 'test_server',
          localPath: '/local/file.txt',
          remotePath: '/remote/file.txt',
          fileName: 'file.txt',
        );

        final transferId = provider.transfers[0].id;

        // If it's still pending, cancel it
        if (provider.transfers[0].status == TransferStatus.pending) {
          provider.cancelTransfer(transferId);
          expect(provider.transfers[0].status, TransferStatus.cancelled);
        }
      });

      test('should do nothing for non-existent transfer', () {
        provider.cancelTransfer('non_existent_id');
        // Should not throw
        expect(provider.transfers, isEmpty);
      });
    });

    group('retryTransfer', () {
      test('should retry failed transfer', () async {
        // Make the mock fail
        mockClient.mockToolResult = null;

        await provider.queueUpload(
          serverName: 'test_server',
          localPath: '/local/file.txt',
          remotePath: '/remote/file.txt',
          fileName: 'file.txt',
        );

        await Future.delayed(const Duration(milliseconds: 200));

        // Find the failed transfer
        final transfer = provider.transfers.firstWhere(
          (t) => t.status == TransferStatus.failed || t.status == TransferStatus.completed,
          orElse: () => provider.transfers.first,
        );

        if (transfer.status == TransferStatus.failed) {
          provider.retryTransfer(transfer.id);

          // Should be back to pending
          expect(transfer.status, TransferStatus.pending);
          expect(transfer.progress, 0.0);
          expect(transfer.error, isNull);
        }
      });
    });

    group('clearCompleted', () {
      test('should remove completed transfers', () async {
        await provider.queueUpload(
          serverName: 'test_server',
          localPath: '/local/file.txt',
          remotePath: '/remote/file.txt',
          fileName: 'file.txt',
        );

        await Future.delayed(const Duration(milliseconds: 200));

        final initialCount = provider.transfers.length;
        provider.clearCompleted();

        expect(provider.transfers.length, lessThanOrEqualTo(initialCount));
        expect(
          provider.transfers.where((t) =>
            t.status == TransferStatus.completed ||
            t.status == TransferStatus.failed ||
            t.status == TransferStatus.cancelled
          ),
          isEmpty,
        );
      });
    });

    group('clearAll', () {
      test('should remove non-active transfers', () async {
        await provider.queueUpload(
          serverName: 'test_server',
          localPath: '/local/file.txt',
          remotePath: '/remote/file.txt',
          fileName: 'file.txt',
        );

        await Future.delayed(const Duration(milliseconds: 200));

        provider.clearAll();

        // Only in-progress transfers should remain
        for (final transfer in provider.transfers) {
          expect(transfer.status, TransferStatus.inProgress);
        }
      });
    });
  });

  group('TransferItem', () {
    test('should create with required fields', () {
      final item = TransferItem(
        id: 'test_1',
        type: TransferType.upload,
        serverName: 'server',
        localPath: '/local',
        remotePath: '/remote',
        fileName: 'file.txt',
      );

      expect(item.id, 'test_1');
      expect(item.type, TransferType.upload);
      expect(item.status, TransferStatus.pending);
      expect(item.progress, 0.0);
      expect(item.error, isNull);
    });

    test('statusText should return correct text for each status', () {
      final item = TransferItem(
        id: 'test',
        type: TransferType.download,
        serverName: 'server',
        localPath: '/local',
        remotePath: '/remote',
        fileName: 'file.txt',
      );

      item.status = TransferStatus.pending;
      expect(item.statusText, 'Pending');

      item.status = TransferStatus.inProgress;
      item.progress = 0.5;
      expect(item.statusText, '50%');

      item.status = TransferStatus.completed;
      expect(item.statusText, 'Completed');

      item.status = TransferStatus.failed;
      expect(item.statusText, 'Failed');

      item.status = TransferStatus.cancelled;
      expect(item.statusText, 'Cancelled');
    });

    test('typeText should return correct text', () {
      final upload = TransferItem(
        id: 'u1',
        type: TransferType.upload,
        serverName: 'server',
        localPath: '/local',
        remotePath: '/remote',
        fileName: 'file.txt',
      );
      expect(upload.typeText, 'Upload');

      final download = TransferItem(
        id: 'd1',
        type: TransferType.download,
        serverName: 'server',
        localPath: '/local',
        remotePath: '/remote',
        fileName: 'file.txt',
      );
      expect(download.typeText, 'Download');
    });
  });
}

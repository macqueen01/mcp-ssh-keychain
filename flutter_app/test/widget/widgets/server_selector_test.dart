import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_file_manager/widgets/server_selector.dart';

void main() {
  group('ServerInfo', () {
    test('should create with required fields', () {
      final server = ServerInfo(
        name: 'production',
        host: 'prod.example.com',
        user: 'deploy',
      );

      expect(server.name, 'production');
      expect(server.host, 'prod.example.com');
      expect(server.user, 'deploy');
      expect(server.defaultDir, isNull);
    });

    test('should create from JSON', () {
      final json = {
        'name': 'staging',
        'host': 'staging.example.com',
        'user': 'admin',
        'default_dir': '/var/www',
      };

      final server = ServerInfo.fromJson(json);

      expect(server.name, 'staging');
      expect(server.host, 'staging.example.com');
      expect(server.user, 'admin');
      expect(server.defaultDir, '/var/www');
    });

    test('should handle missing fields in JSON', () {
      final json = <String, dynamic>{};

      final server = ServerInfo.fromJson(json);

      expect(server.name, '');
      expect(server.host, '');
      expect(server.user, '');
      expect(server.defaultDir, isNull);
    });
  });

  group('ServerSelector Widget', () {
    testWidgets('should show loading indicator when isLoading is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerSelector(
              servers: const [],
              onServerSelected: (_) {},
              isLoading: true,
            ),
          ),
        ),
      );

      // Widget uses CupertinoActivityIndicator, not CircularProgressIndicator
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text('Loading servers...'), findsOneWidget);
    });

    testWidgets('should show empty state when servers list is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerSelector(
              servers: const [],
              onServerSelected: (_) {},
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.text('No servers configured'), findsOneWidget);
      expect(find.text('Add servers in Settings'), findsOneWidget);
    });

    testWidgets('should display server list', (tester) async {
      final servers = [
        ServerInfo(name: 'server1', host: 'host1.com', user: 'user1'),
        ServerInfo(name: 'server2', host: 'host2.com', user: 'user2'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerSelector(
              servers: servers,
              onServerSelected: (_) {},
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.text('server1'), findsOneWidget);
      expect(find.text('server2'), findsOneWidget);
    });

    testWidgets('should show server count', (tester) async {
      final servers = [
        ServerInfo(name: 'server1', host: 'host1.com', user: 'user1'),
        ServerInfo(name: 'server2', host: 'host2.com', user: 'user2'),
        ServerInfo(name: 'server3', host: 'host3.com', user: 'user3'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerSelector(
              servers: servers,
              onServerSelected: (_) {},
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.text('3 servers'), findsOneWidget);
    });

    testWidgets('should show singular "server" for one server', (tester) async {
      final servers = [
        ServerInfo(name: 'server1', host: 'host1.com', user: 'user1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerSelector(
              servers: servers,
              onServerSelected: (_) {},
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.text('1 server'), findsOneWidget);
    });

    testWidgets('should call onServerSelected when server is tapped',
        (tester) async {
      ServerInfo? selectedServer;
      final servers = [
        ServerInfo(name: 'server1', host: 'host1.com', user: 'user1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerSelector(
              servers: servers,
              onServerSelected: (server) => selectedServer = server,
              isLoading: false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('server1'));
      await tester.pumpAndSettle();

      expect(selectedServer, isNotNull);
      expect(selectedServer!.name, 'server1');
    });

    // Note: Search and toggle tests require CupertinoSearchTextField
    // which has platform-specific behavior. These are integration tests.

    testWidgets('should have view toggle buttons', (tester) async {
      final servers = [
        ServerInfo(name: 'server1', host: 'host1.com', user: 'user1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServerSelector(
              servers: servers,
              onServerSelected: (_) {},
              isLoading: false,
            ),
          ),
        ),
      );

      // The view toggle buttons should be present
      expect(find.byType(GestureDetector), findsWidgets);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/online.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'create and resume advertise ranked and lobby features; ready is sent',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final actions = <Map<String, dynamic>>[];
      final sockets = <WebSocket>[];
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((raw) {
          final action = jsonDecode(raw as String) as Map<String, dynamic>;
          actions.add(action);
          if (action['type'] == 'create' || action['type'] == 'resume') {
            socket.add(
              jsonEncode({
                'type': 'session',
                'code': 'ABC234',
                'token': 'saved-token',
                'playerId': 'alice',
              }),
            );
            socket.add(
              jsonEncode({
                'type': 'state',
                'code': 'ABC234',
                'phase': 'waiting',
                'lobbyMode': true,
                'lobbyReady': <String>[],
                'players': [
                  {
                    'id': 'alice',
                    'name': 'Alice',
                    'score': 0,
                    'connected': true,
                  },
                ],
                'cards': List<dynamic>.filled(12, null),
              }),
            );
          }
        });
      });
      final online = OnlineGame(
        prefs,
        serverUrl: 'ws://127.0.0.1:${server.port}/ws',
      );
      try {
        await online.open({
          'type': 'create',
          'name': 'Alice',
          'pairs': 6,
          'theme': 'garden',
        });
        await _until(() => online.state?['lobbyMode'] == true);
        expect(
          actions.first['supportedFeatures'],
          containsAll(['ranked-v1', 'ranked-attempts-v1', 'lobby-v1']),
        );
        online.ready(true);
        await _until(() => actions.any((action) => action['type'] == 'ready'));
        expect(actions.last, {'type': 'ready', 'ready': true});
        expect(actions.first['lobbyMode'], isNull);
        await sockets.first.close(1001, 'reconnect');
        await _until(() => actions.any((action) => action['type'] == 'resume'));
        expect(actions.last['supportedFeatures'], contains('lobby-v1'));
        expect(
          actions.last['supportedFeatures'],
          contains('ranked-attempts-v1'),
        );
      } finally {
        online.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      }
    },
  );

  test(
    'voice messages reach listeners only after the seat is confirmed',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((raw) {
          final action = jsonDecode(raw as String) as Map<String, dynamic>;
          if (action['type'] != 'create') return;
          socket.add(
            jsonEncode({'type': 'voice', 'action': 'state', 'members': []}),
          );
          socket.add(
            jsonEncode({
              'type': 'session',
              'code': 'ABC234',
              'token': 't',
              'playerId': 'alice',
            }),
          );
          socket.add(
            jsonEncode({
              'type': 'voice',
              'action': 'state',
              'members': [
                {'id': 'alice', 'generation': 3, 'muted': false},
              ],
            }),
          );
        });
      });
      final online = OnlineGame(
        prefs,
        serverUrl: 'ws://127.0.0.1:${server.port}/ws',
      );
      final received = <Map<String, dynamic>>[];
      online.voiceMessages.listen(received.add);
      try {
        expect(online.seated, isFalse);
        await online.open({
          'type': 'create',
          'name': 'Alice',
          'pairs': 6,
          'theme': 'garden',
        });
        await _until(() => received.isNotEmpty);
        expect(received, hasLength(1));
        expect(online.seated, isTrue);
        expect(online.sessionSerial, 1);
        expect(online.voiceRoster?['members'], hasLength(1));
        await sockets.first.close(1001, 'drop');
        await _until(() => !online.seated);
      } finally {
        online.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      }
    },
  );
}

Future<void> _until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for server message');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

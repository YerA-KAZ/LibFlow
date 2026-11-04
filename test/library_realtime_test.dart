import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libflow/services/library_realtime_service.dart';

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for state');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late HttpServer server;
  late LibraryRealtimeService service;
  late List<WebSocket> sockets;
  late List<String> received;
  late List<RealtimeStatus> states;
  late int changes;
  late bool answerPing;

  void serve() {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((data) {
        if (socket.readyState != WebSocket.open) return;
        final type = (jsonDecode(data as String) as Map)['type'] as String;
        received.add(type);
        if (type == 'sync') {
          socket.add(jsonEncode({'type': 'catalogue_changed'}));
        } else if (type == 'ping' && answerPing) {
          socket.add(jsonEncode({'type': 'pong'}));
        }
      });
    });
  }

  setUp(() async {
    sockets = [];
    received = [];
    states = [];
    changes = 0;
    answerPing = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serve();
    service = LibraryRealtimeService(
      uri: Uri.parse('ws://127.0.0.1:${server.port}/ws/catalogue'),
      onCatalogueChanged: () => changes++,
      retryDelay: const Duration(milliseconds: 40),
      heartbeatInterval: const Duration(milliseconds: 200),
    );
    service.addListener(() => states.add(service.status));
  });

  tearDown(() async {
    service.dispose();
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  });

  test(
    'connect sends sync and receives catalogue event automatically',
    () async {
      await service.connect();
      await until(() => changes == 1);
      expect(received.first, 'sync');
      expect(service.status, RealtimeStatus.online);
      expect(states.take(2), [
        RealtimeStatus.connecting,
        RealtimeStatus.online,
      ]);
    },
  );

  test('server push updates without another client request', () async {
    await service.connect();
    await until(() => changes == 1);
    sockets.single.add(jsonEncode({'type': 'catalogue_changed'}));
    await until(() => changes == 2);
    expect(received.where((event) => event == 'sync').length, 1);
  });

  test(
    'unavailable server shows offline then recovers when server returns',
    () async {
      final port = server.port;
      await server.close(force: true);
      await service.connect();
      expect(service.status, RealtimeStatus.offline);
      expect(changes, 0);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      serve();
      await until(
        () => service.status == RealtimeStatus.online && changes == 1,
      );
      expect(received.first, 'sync');
      expect(states, contains(RealtimeStatus.offline));
    },
  );

  test('disconnect reconnects and resyncs missed catalogue events', () async {
    await service.connect();
    await until(() => changes == 1);
    await sockets.first.close();
    await until(() => sockets.length == 2 && changes == 2);
    expect(states, contains(RealtimeStatus.offline));
    expect(service.status, RealtimeStatus.online);
    expect(received.where((event) => event == 'sync').length, 2);
  });

  test('invalid JSON exposes error and reconnects', () async {
    await service.connect();
    await until(() => changes == 1);
    sockets.first.add('{invalid');
    await until(() => states.contains(RealtimeStatus.error));
    await until(() => changes == 2);
    expect(service.status, RealtimeStatus.online);
  });

  test('silent connection is detected by heartbeat timeout', () async {
    answerPing = false;
    await service.connect();
    await until(() => states.contains(RealtimeStatus.offline));
    expect(received, contains('ping'));
  });

  test('pong keeps healthy connection online', () async {
    await service.connect();
    await until(() => received.where((event) => event == 'ping').length >= 3);
    expect(service.status, RealtimeStatus.online);
    expect(sockets.length, 1);
    expect(states, isNot(contains(RealtimeStatus.offline)));
  });

  test('repeated connect calls do not create duplicate sockets', () async {
    await Future.wait([
      service.connect(),
      service.connect(),
      service.connect(),
    ]);
    await until(() => changes == 1);
    expect(sockets.length, 1);
    expect(received.where((event) => event == 'sync').length, 1);
  });

  test('manual retry replaces connection and syncs again', () async {
    await service.connect();
    await until(() => changes == 1);
    service.retryNow();
    await until(() => changes == 2);
    expect(sockets.length, 2);
    expect(service.status, RealtimeStatus.online);
  });

  test('dispose prevents retries and callbacks', () async {
    await service.connect();
    await until(() => changes == 1);
    service.dispose();
    final count = states.length;
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(sockets.length, 1);
    expect(changes, 1);
    expect(states.length, count);
  });
}

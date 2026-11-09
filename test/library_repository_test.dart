import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:libflow/models/book_model.dart';
import 'package:libflow/services/library_api_service.dart';
import 'package:libflow/services/library_database_service.dart';
import 'package:libflow/services/library_repository.dart';

import 'library_realtime_test.dart' show until;

http.Response jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Directory.systemTemp.createTempSync(
    'libflow_repository_test_',
  );
  final cache = LibraryDatabaseService();
  setUpAll(() async {
    LibraryDatabaseService.storageDirectoryOverride = directory.path;
    await cache.initializeDatabase();
  });
  tearDownAll(() async {
    LibraryDatabaseService.storageDirectoryOverride = null;
    await directory.delete(recursive: true);
  });

  test('Realtime event during REST loading schedules a fresh GET', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    var syncReceived = false;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {
        syncReceived = true;
        socket.add(jsonEncode({'type': 'catalogue_changed'}));
      });
    });
    final gate = Completer<void>();
    var gets = 0;
    final repository = LibraryRepository(
      cache: cache,
      api: LibraryApiService(
        baseUrl: 'http://127.0.0.1:${server.port}',
        client: MockClient((_) async {
          gets++;
          if (gets == 1) await gate.future;
          return jsonResponse(
            jsonEncode([
              {'id': 'live', 'title': gets == 1 ? 'Stale' : 'Live title'},
            ]),
            200,
          );
        }),
      ),
    );
    try {
      await cache.replaceBooks([
        Book.fromMap({
          'id': 'live',
          'isFavorite': 1,
          'reservationCode': 'PRIVATE',
        }),
      ]);
      final initial = repository.refresh();
      repository.startRealtime();
      await until(() => syncReceived);
      // Wait until the event has reached the client before completing GET.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      gate.complete();
      await initial;
      await until(
        () => gets == 2 && repository.status == LibraryStatus.success,
      );
      expect(repository.books.single.title, 'Live title');
      expect(repository.books.single.isFavorite, isTrue);
      expect(repository.books.single.reservationCode, 'PRIVATE');
      expect(gets, 2);
    } finally {
      if (!gate.isCompleted) gate.complete();
      repository.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    }
  });

  test(
    'Authenticated reader uses the server reservation and ignores cached QR',
    () async {
      final old = Book.fromMap({
        'id': 'reader-book',
        'isReserved': true,
        'reservationCode': 'OLD-LOCAL-CODE',
        'isFavorite': true,
      });
      await cache.replaceBooks([old]);
      final book = {
        'id': old.id,
        'title': 'Reader book',
        'author': 'Author',
        'availableCopies': 1,
        'totalCopies': 1,
        'isAvailable': true,
      };
      final api = LibraryApiService(
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer test-session');
          return switch ((request.method, request.url.path)) {
            ('GET', '/api/books') => jsonResponse(jsonEncode([book]), 200),
            ('GET', '/api/reservations/mine') ||
            ('GET', '/api/favorites') => jsonResponse('[]', 200),
            ('POST', '/api/books/reader-book/reserve') => jsonResponse(
              jsonEncode({
                'book': {...book, 'availableCopies': 0, 'isAvailable': false},
                'reservation': {
                  'code': 'SERVER-QR',
                  'status': 'reserved',
                  'book_id': old.id,
                  'created_at': DateTime.now().toIso8601String(),
                },
              }),
              201,
            ),
            _ => throw StateError(
              'Unexpected request: ${request.method} ${request.url.path}',
            ),
          };
        }),
      )..sessionToken = 'test-session';
      final repository = LibraryRepository(api: api, cache: cache);
      addTearDown(repository.dispose);

      expect(await repository.refresh(), isTrue);
      final fresh = repository.books.single;
      expect(fresh.reservationCode, isNull);
      expect(fresh.isFavorite, isFalse);
      expect(await repository.update(fresh.copyWith(isReserved: true)), isTrue);
      expect(repository.books.single.reservationCode, 'SERVER-QR');
      expect(repository.books.single.availableCopies, 0);
    },
  );

  test('Disposed repository rejects further operations', () async {
    var requests = 0;
    final repository = LibraryRepository(
      api: LibraryApiService(
        client: MockClient((_) async {
          requests++;
          return jsonResponse('[]', 200);
        }),
      ),
    );
    repository.dispose();
    expect(await repository.refresh(), isFalse);
    expect(requests, 0);
  });

  test(
    'Cache write failure is surfaced instead of reporting success',
    () async {
      final blocker = File('${directory.path}/not_a_directory');
      await blocker.writeAsString('blocked');
      final repository = LibraryRepository(
        api: LibraryApiService(
          client: MockClient(
            (request) async => jsonResponse(
              request.method == 'GET' ? '[]' : request.body,
              200,
            ),
          ),
        ),
      );
      LibraryDatabaseService.storageDirectoryOverride = blocker.path;
      try {
        expect(await repository.refresh(), isFalse);
        expect(repository.status, LibraryStatus.error);
        expect(
          await repository.add(Book.fromMap({'id': 'disk_error'})),
          isFalse,
        );
        expect(repository.error, contains('құрылғыға жазылмады'));
      } finally {
        LibraryDatabaseService.storageDirectoryOverride = directory.path;
        repository.dispose();
      }
    },
  );

  test(
    'GET merges personal state, removes stale books, and persists snapshot',
    () async {
      final local = Book.fromMap({
        'id': 'merged',
        'title': 'Local',
        'isFavorite': 1,
        'isReserved': 1,
        'reservationCode': 'MY_CODE',
      });
      await cache.replaceBooks([
        local,
        Book.fromMap({'id': 'removed'}),
      ]);
      final repository = LibraryRepository(
        cache: cache,
        api: LibraryApiService(
          client: MockClient(
            (_) async => jsonResponse(
              jsonEncode([
                {'id': 'merged', 'title': 'Server title'},
              ]),
              200,
            ),
          ),
        ),
      );
      final states = <LibraryStatus>[];
      repository.addListener(() => states.add(repository.status));
      expect(await repository.refresh(), isTrue);
      expect(states, [LibraryStatus.loading, LibraryStatus.success]);
      expect(repository.books.single.title, 'Server title');
      expect(repository.books.single.isFavorite, isTrue);
      expect(repository.books.single.reservationCode, 'MY_CODE');
      final disk = jsonDecode(
        await File('${directory.path}/libflow_offline_database.json')
            .readAsString(),
      );
      expect((disk['books'] as List).single['title'], 'Server title');
      repository.dispose();
    },
  );

  test('POST, PUT, DELETE update the cache only after success', () async {
    await cache.replaceBooks([]);
    final methods = <String>[];
    final repository = LibraryRepository(
      cache: cache,
      api: LibraryApiService(
        client: MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'DELETE') return jsonResponse('', 204);
          return jsonResponse(
            request.body,
            request.method == 'POST' ? 201 : 200,
          );
        }),
      ),
    );
    final book = Book.fromMap({'id': 'crud', 'title': 'Created'});
    expect(await repository.add(book), isTrue);
    expect(repository.books.single.title, 'Created');
    expect(await repository.update(book.copyWith(title: 'Updated')), isTrue);
    expect(repository.books.single.title, 'Updated');
    expect(await repository.delete(book.id), isTrue);
    expect(repository.books, isEmpty);
    expect(methods, ['POST', 'PUT', 'DELETE']);
    repository.dispose();
  });

  test('Offline GET and failed writes preserve cached data', () async {
    final book = Book.fromMap({'id': 'offline', 'title': 'Cached'});
    await cache.replaceBooks([book]);
    final repository = LibraryRepository(
      cache: cache,
      api: LibraryApiService(
        client: MockClient((_) async => throw const SocketException('offline')),
      ),
    );
    expect(await repository.refresh(), isFalse);
    expect(repository.status, LibraryStatus.error);
    expect(repository.error, isNotEmpty);
    expect(await repository.add(book.copyWith(title: 'Unconfirmed')), isFalse);
    expect(
      await repository.update(book.copyWith(title: 'Unconfirmed')),
      isFalse,
    );
    expect(await repository.delete(book.id), isFalse);
    expect(repository.books.single.title, 'Cached');
    repository.dispose();
  });
}

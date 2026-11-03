import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:libflow/models/book_model.dart';
import 'package:libflow/services/library_api_service.dart';
import 'package:libflow/services/library_database_service.dart';
import 'package:libflow/services/library_repository.dart';

http.Response jsonResponse(String body, int status) => http.Response(
  body, status, headers: {'content-type': 'application/json; charset=utf-8'});

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

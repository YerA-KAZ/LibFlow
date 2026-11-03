import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:libflow/models/book_model.dart';
import 'package:libflow/services/library_api_service.dart';

http.Response jsonResponse(String body, int status) => http.Response(
  body, status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  final book = Book.fromMap({
    'id': 'book_test',
    'title': 'Қара сөздер',
    'author': 'Абай',
  });

  test('GET converts UTF-8 JSON into Dart Book objects', () async {
    final api = LibraryApiService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/books');
        return http.Response.bytes(
          utf8.encode(jsonEncode([book.toMap()])),
          200,
        );
      }),
    );
    expect((await api.getBooks()).single.title, 'Қара сөздер');
    api.close();
  });

  for (final method in ['POST', 'PUT']) {
    test('$method sends JSON and decodes saved book', () async {
      final api = LibraryApiService(
        client: MockClient((request) async {
          expect(request.method, method);
          expect(
            request.url.path,
            method == 'POST' ? '/api/books' : '/api/books/book_test',
          );
          final data = jsonDecode(request.body) as Map;
          expect(data['title'], book.title);
          expect(data.containsKey('isFavorite'), isFalse);
          return jsonResponse(jsonEncode(data), method == 'POST' ? 201 : 200);
        }),
      );
      final saved = method == 'POST'
          ? await api.createBook(book)
          : await api.updateBook(book);
      expect(saved.id, book.id);
      api.close();
    });
  }

  test('DELETE handles empty 204 response', () async {
    final api = LibraryApiService(
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/books/book_test');
        return jsonResponse('', 204);
      }),
    );
    await api.deleteBook(book.id);
    api.close();
  });

  for (final status in [404, 409, 422, 500, 503]) {
    test('HTTP $status becomes a readable exception', () async {
      final api = LibraryApiService(
        client: MockClient((_) async => jsonResponse('{}', status)),
      );
      await expectLater(api.getBooks(), throwsA(isA<LibraryApiException>()));
      api.close();
    });
  }

  test('No internet is handled', () async {
    final api = LibraryApiService(
      client: MockClient((_) async => throw const SocketException('offline')),
    );
    await expectLater(api.getBooks(), throwsA(isA<LibraryApiException>()));
    api.close();
  });

  test('Client exception is handled', () async {
    final api = LibraryApiService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(api.getBooks(), throwsA(isA<LibraryApiException>()));
    api.close();
  });

  test('Slow server times out', () async {
    final api = LibraryApiService(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return jsonResponse('[]', 200);
      }),
    );
    await expectLater(api.getBooks(), throwsA(isA<LibraryApiException>()));
    api.close();
  });

  for (final body in ['not json', '{}', '[{"pages":"invalid"}]']) {
    test('Malformed response $body is handled', () async {
      final api = LibraryApiService(
        client: MockClient((_) async => jsonResponse(body, 200)),
      );
      await expectLater(api.getBooks(), throwsA(isA<LibraryApiException>()));
      api.close();
    });
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/book_model.dart';

class LibraryApiException implements Exception {
  final String message;
  const LibraryApiException(this.message);
  @override
  String toString() => message;
}

/// REST client for our PostgreSQL-backed catalogue.
class LibraryApiService {
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  LibraryApiService({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       baseUrl =
           (baseUrl ??
                   const String.fromEnvironment(
                     'API_BASE_URL',
                     defaultValue: '',
                   ))
               .replaceFirst(RegExp(r'/+$'), '');

  String get _url => baseUrl.isNotEmpty
      ? baseUrl
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? 'http://10.0.2.2:8000'
            : 'http://127.0.0.1:8000');

  static const personalFields = [
    'isFavorite',
    'isReserved',
    'reservationTime',
    'reservationCode',
    'isBorrowed',
    'dueDate',
  ];

  Map<String, dynamic> _payload(Book book) =>
      Map.of(book.toMap())
        ..removeWhere((key, _) => personalFields.contains(key));

  Future<dynamic> _request(String method, String path, [Book? book]) async {
    try {
      final request = http.Request(method, Uri.parse('$_url$path'));
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      if (book != null) request.body = jsonEncode(_payload(book));
      final response = await (() async {
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = switch (response.statusCode) {
          404 => 'Кітап серверден табылмады. Тізімді жаңартыңыз.',
          409 => 'Бұл кітап серверге бұрын қосылған. Тізімді жаңартыңыз.',
          422 => 'Кітап деректері дұрыс емес. Өрістерді тексеріңіз.',
          _ => 'Сервер қатесі (${response.statusCode}). Қайта көріңіз.',
        };
        throw LibraryApiException(message);
      }
      if (response.statusCode == 204) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const LibraryApiException(
        'Сервердің жауап беру уақыты аяқталды. Қайта көріңіз.',
      );
    } on SocketException {
      throw const LibraryApiException(
        'Желі немесе сервер қолжетімсіз. Байланысты тексеріңіз.',
      );
    } on http.ClientException {
      throw const LibraryApiException(
        'Серверге қосылу мүмкін болмады. Интернет пен сервер мекенжайын тексеріңіз.',
      );
    } on FormatException {
      throw const LibraryApiException('Серверден қате JSON жауабы келді.');
    }
  }

  Future<List<Book>> getBooks() async {
    final data = await _request('GET', '/api/books');
    try {
      return (data as List)
          .map((item) => Book.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      throw const LibraryApiException(
        'Сервердегі кітап деректерінің пішімі дұрыс емес.',
      );
    }
  }

  Future<Book> _save(String method, String path, Book book) async {
    final data = await _request(method, path, book);
    try {
      return Book.fromMap(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      throw const LibraryApiException(
        'Сервердегі кітап деректерінің пішімі дұрыс емес.',
      );
    }
  }

  Future<Book> createBook(Book book) => _save('POST', '/api/books', book);
  Future<Book> updateBook(Book book) =>
      _save('PUT', '/api/books/${Uri.encodeComponent(book.id)}', book);
  Future<void> deleteBook(String id) async {
    await _request('DELETE', '/api/books/${Uri.encodeComponent(id)}');
  }

  void close() => _client.close();
}

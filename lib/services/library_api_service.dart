import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/book_model.dart';

class LibraryApiException implements Exception {
  final String message;
  final int? status;
  const LibraryApiException(this.message, {this.status});
  @override
  String toString() => message;
}

/// REST client for our PostgreSQL-backed catalogue.
class LibraryApiService {
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;
  String? sessionToken;

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

  String get resolvedBaseUrl => baseUrl.isNotEmpty
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

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final request = http.Request(method, Uri.parse('$resolvedBaseUrl$path'));
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      final token = sessionToken;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);
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
        String? detail;
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map && data['detail'] is String) {
            detail = data['detail'] as String;
          }
        } on FormatException {
          // Proxy responses may not contain JSON.
        }
        throw LibraryApiException(
          detail ?? message,
          status: response.statusCode,
        );
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
    final data = await request('GET', '/api/books');
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
    final data = await request(method, path, body: _payload(book));
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
    await request('DELETE', '/api/books/${Uri.encodeComponent(id)}');
  }

  void close() => _client.close();
}

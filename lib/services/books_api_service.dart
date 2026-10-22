import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/book_model.dart';

class BooksApiService {
  static const String googleBooksBaseUrl =
      'https://www.googleapis.com/books/v1/volumes';
  static const String openLibraryBaseUrl =
      'https://openlibrary.org/search.json';

  // Optional custom API key for Google Books (if provided by user/admin)
  static String? googleApiKey;

  /// Search books from Google Books API
  static Future<List<Book>> searchGoogleBooks(
    String query, {
    int maxResults = 15,
  }) async {
    try {
      final keyParam = (googleApiKey != null && googleApiKey!.isNotEmpty)
          ? '&key=$googleApiKey'
          : '';
      final url = Uri.parse(
          '$googleBooksBaseUrl?q=${Uri.encodeComponent(query)}&maxResults=$maxResults$keyParam');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'LibFlowApp/1.0 (Flutter Mobile)'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final items = data['items'] as List<dynamic>?;
        if (items != null) {
          return items
              .whereType<Map<String, dynamic>>()
              .map((item) => Book.fromGoogleBooks(item))
              .toList();
        }
      } else if (response.statusCode == 429) {
        if (kDebugMode) {
          print('Google Books API: Quota reached (429). Using fallback.');
        }
      } else {
        if (kDebugMode) {
          print('Google Books API error: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Google Books API exception: $e');
      }
    }
    return [];
  }

  /// Search books from Open Library API
  static Future<List<Book>> searchOpenLibrary(
    String query, {
    int limit = 15,
  }) async {
    try {
      final url = Uri.parse(
          '$openLibraryBaseUrl?q=${Uri.encodeComponent(query)}&limit=$limit');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'LibFlowApp/1.0 (contact: info@libflow.kz)'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final docs = data['docs'] as List<dynamic>?;
        if (docs != null) {
          return docs
              .whereType<Map<String, dynamic>>()
              .map((doc) => Book.fromOpenLibrary(doc))
              .toList();
        }
      } else {
        if (kDebugMode) {
          print('Open Library API error: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Open Library API exception: $e');
      }
    }
    return [];
  }

  /// Combined search: Queries both APIs simultaneously and merges unique books
  static Future<List<Book>> searchCombined(
    String query, {
    int limit = 20,
  }) async {
    final futures = await Future.wait([
      searchOpenLibrary(query, limit: limit),
      searchGoogleBooks(query, maxResults: limit),
    ]);

    final openLibResults = futures[0];
    final googleResults = futures[1];

    final List<Book> combined = [];
    final Set<String> titlesSeen = {};

    // Interleave results so user gets a rich mix from both sources
    final int maxLen = openLibResults.length > googleResults.length
        ? openLibResults.length
        : googleResults.length;

    for (int i = 0; i < maxLen; i++) {
      if (i < openLibResults.length) {
        final b = openLibResults[i];
        final cleanTitle = b.title.trim().toLowerCase();
        if (!titlesSeen.contains(cleanTitle)) {
          titlesSeen.add(cleanTitle);
          combined.add(b);
        }
      }
      if (i < googleResults.length) {
        final b = googleResults[i];
        final cleanTitle = b.title.trim().toLowerCase();
        if (!titlesSeen.contains(cleanTitle)) {
          titlesSeen.add(cleanTitle);
          combined.add(b);
        }
      }
    }

    return combined.take(limit).toList();
  }

  /// Search by ISBN across both APIs
  static Future<Book?> searchByIsbn(String isbn) async {
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '');

    // Try Open Library first
    final olList = await searchOpenLibrary('isbn:$cleanIsbn', limit: 1);
    if (olList.isNotEmpty) return olList.first;

    // Try Google Books
    final gbList = await searchGoogleBooks('isbn:$cleanIsbn', maxResults: 1);
    if (gbList.isNotEmpty) return gbList.first;

    return null;
  }
}

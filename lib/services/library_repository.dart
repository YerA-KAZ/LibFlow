import 'package:flutter/foundation.dart';

import '../models/book_model.dart';
import 'library_api_service.dart';
import 'library_database_service.dart';

enum LibraryStatus { idle, loading, success, error }

class LibraryRepository extends ChangeNotifier {
  final LibraryApiService api;
  final LibraryDatabaseService cache;
  LibraryStatus status = LibraryStatus.idle;
  String? error;
  bool _disposed = false;
  List<Book> get books => cache.books;

  LibraryRepository({LibraryApiService? api, LibraryDatabaseService? cache})
    : api = api ?? LibraryApiService(),
      cache = cache ?? LibraryDatabaseService();

  Book _withPersonalState(Book remote, Book? local) {
    if (local == null) return remote;
    final map = remote.toMap();
    final personal = local.toMap();
    for (final key in LibraryApiService.personalFields) {
      map[key] = personal[key];
    }
    return Book.fromMap(map);
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (status == LibraryStatus.loading) return false;
    status = LibraryStatus.loading;
    error = null;
    notifyListeners();
    try {
      await action();
      status = LibraryStatus.success;
      return true;
    } catch (e) {
      error = e is LibraryApiException
          ? e.message
          : 'Деректерді өңдеу кезінде қате шықты. Қайта көріңіз.';
      status = LibraryStatus.error;
      return false;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> refresh() => _run(() async {
    final remote = await api.getBooks();
    final merged = remote
        .map((book) => _withPersonalState(book, cache.getBookById(book.id)))
        .toList();
    await cache.replaceBooks(merged);
  });

  Future<bool> add(Book book) => _run(() async {
    final saved = await api.createBook(book);
    await cache.insertBook(_withPersonalState(saved, book));
  });

  Future<bool> update(Book book) => _run(() async {
    final local = cache.getBookById(book.id);
    // External search results are imported with POST before entering our catalogue.
    final saved = local == null
        ? await api.createBook(book)
        : await api.updateBook(book);
    await cache.insertBook(_withPersonalState(saved, book));
  });

  Future<bool> delete(String id) => _run(() async {
    await api.deleteBook(id);
    await cache.deleteBook(id);
  });

  @override
  void dispose() {
    _disposed = true;
    api.close();
    super.dispose();
  }
}

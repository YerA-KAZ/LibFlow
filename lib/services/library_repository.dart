import 'package:flutter/foundation.dart';

import '../models/book_model.dart';
import 'library_api_service.dart';
import 'library_database_service.dart';
import 'library_realtime_service.dart';
import 'app_log.dart';

enum LibraryStatus { idle, loading, success, error }

class LibraryRepository extends ChangeNotifier {
  final LibraryApiService api;
  final LibraryDatabaseService cache;
  LibraryStatus status = LibraryStatus.idle;
  String? error;
  bool _disposed = false;
  bool _refreshPending = false;
  LibraryRealtimeService? _realtime;
  RealtimeStatus get realtimeStatus => _realtime?.status ?? RealtimeStatus.idle;

  void startRealtime() {
    if (_disposed || _realtime != null) return;
    final base = Uri.parse(api.resolvedBaseUrl);
    _realtime = LibraryRealtimeService(
      uri: base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '${base.path}/ws/catalogue',
      ),
      onCatalogueChanged: _scheduleRefresh,
    )..addListener(_realtimeChanged);
    _realtime!.connect();
  }

  void _realtimeChanged() {
    if (!_disposed) notifyListeners();
  }

  void retryRealtime() => _realtime?.retryNow();

  void _scheduleRefresh() {
    if (_disposed) return;
    if (status == LibraryStatus.loading) {
      _refreshPending = true;
    } else {
      refresh();
    }
  }

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

  Future<bool> _run(String operation, Future<void> Function() action) async {
    if (_disposed || status == LibraryStatus.loading) return false;
    status = LibraryStatus.loading;
    error = null;
    notifyListeners();
    try {
      await action();
      status = LibraryStatus.success;
      AppLog.event('catalogue.$operation.succeeded');
      return true;
    } catch (e) {
      AppLog.event('catalogue.$operation.failed', error: e);
      error = e is LibraryApiException
          ? e.message
          : 'Деректерді өңдеу кезінде қате шықты. Қайта көріңіз.';
      status = LibraryStatus.error;
      return false;
    } finally {
      if (!_disposed) notifyListeners();
      if (_refreshPending && !_disposed) {
        _refreshPending = false;
        _scheduleRefresh();
      }
    }
  }

  Future<bool> refresh() => _run('refresh', () async {
    final remote = await api.getBooks();
    final merged = remote
        .map((book) => _withPersonalState(book, cache.getBookById(book.id)))
        .toList();
    await cache.replaceBooks(merged);
  });

  Future<bool> add(Book book) => _run('create', () async {
    final saved = await api.createBook(book);
    await _cacheBook(_withPersonalState(saved, book));
  });

  Future<void> _cacheBook(Book book) async {
    if (!await cache.insertBook(book)) {
      throw const LibraryApiException(
        'Серверге сақталды, бірақ құрылғыға жазылмады. Тізімді қайта жаңартыңыз.',
      );
    }
  }

  Future<bool> update(Book book) => _run('update', () async {
    final local = cache.getBookById(book.id);
    // External search results are imported with POST before entering our catalogue.
    final saved = local == null
        ? await api.createBook(book)
        : await api.updateBook(book);
    await _cacheBook(_withPersonalState(saved, book));
  });

  Future<bool> delete(String id) => _run('delete', () async {
    await api.deleteBook(id);
    if (!await cache.deleteBook(id)) {
      throw const LibraryApiException(
        'Серверден өшірілді, бірақ кэш жаңармады. Тізімді қайта жаңартыңыз.',
      );
    }
  });

  @override
  void dispose() {
    _disposed = true;
    _realtime?.removeListener(_realtimeChanged);
    _realtime?.dispose();
    api.close();
    super.dispose();
  }
}

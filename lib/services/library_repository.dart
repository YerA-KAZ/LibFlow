import 'package:flutter/foundation.dart';

import '../models/book_model.dart';
import 'library_api_service.dart';
import 'library_database_service.dart';
import 'library_realtime_service.dart';
import 'app_log.dart';

enum LibraryStatus { idle, loading, success, error }

class LibraryRepository extends ChangeNotifier {
  final LibraryApiService api;
  final bool catalogueOnly;
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

  LibraryRepository({
    LibraryApiService? api,
    LibraryDatabaseService? cache,
    this.catalogueOnly = false,
  }) : api = api ?? LibraryApiService(),
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

  List<Map<String, dynamic>> reservations = [];
  bool hasLoadedAccount = false;

  Book _withReservation(Book book, Map<String, dynamic>? entry) {
    final status = entry?['display_status'] ?? entry?['status'];
    final reserved = status == 'reserved';
    final issued = status == 'issued';
    final map = book.toMap();
    map['isReserved'] = reserved;
    map['reservationTime'] = reserved ? entry!['created_at'] : null;
    map['reservationCode'] = reserved ? entry!['code'] : null;
    map['isBorrowed'] = issued;
    map['dueDate'] = issued ? entry!['due_at'] : null;
    return Book.fromMap(map);
  }

  Future<void> _refreshReservations() async {
    final result = await api.request('GET', '/api/reservations/mine') as List;
    reservations = result
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  Future<void> _applyReservationResponse(dynamic response, Book local) async {
    final entry = Map<String, dynamic>.from(response['reservation'] as Map);
    reservations = [
      entry,
      ...reservations.where((item) => item['code'] != entry['code']),
    ];
    final remote = Book.fromMap(
      Map<String, dynamic>.from(response['book'] as Map),
    );
    await _cacheBook(
      _withReservation(remote.copyWith(isFavorite: local.isFavorite), entry),
    );
  }

  Future<bool> refresh() => _run('refresh', () async {
    final remote = await api.getBooks();
    if (catalogueOnly) {
      await cache.replaceBooks(remote);
      return;
    }
    if (api.sessionToken != null) {
      await _refreshReservations();
      final favorites = (await api.request('GET', '/api/favorites') as List)
          .toSet();
      final active = {
        for (final entry in reservations)
          if ([
            'reserved',
            'issued',
          ].contains(entry['display_status'] ?? entry['status']))
            entry['book_id']: entry,
      };
      await cache.replaceBooks(
        remote.map((book) {
          final favorite = favorites.contains(book.id);
          return _withReservation(
            book.copyWith(isFavorite: favorite),
            active[book.id],
          );
        }).toList(),
      );
      hasLoadedAccount = true;
      return;
    }
    final merged = remote
        .map((book) => _withPersonalState(book, cache.getBookById(book.id)))
        .toList();
    await cache.replaceBooks(merged);
  });

  Future<bool> add(Book book) => _run('create', () async {
    final saved = await api.createBook(book);
    await _cacheBook(_withPersonalState(saved, book));
  });

  Future<void> _cacheBook(Book book, {Loan? reservationHistory}) async {
    if (!await cache.insertBook(book, reservationHistory: reservationHistory)) {
      throw const LibraryApiException(
        'Серверге сақталды, бірақ құрылғыға жазылмады. Тізімді қайта жаңартыңыз.',
      );
    }
  }

  Future<bool> update(Book book, {Loan? reservationHistory}) =>
      _run('update', () async {
        final local = cache.getBookById(book.id);
        if (!catalogueOnly && api.sessionToken != null && local != null) {
          if (!local.isReserved && book.isReserved) {
            final id = Uri.encodeComponent(book.id);
            await _applyReservationResponse(
              await api.request('POST', '/api/books/$id/reserve'),
              local,
            );
            return;
          }
          if (local.isReserved &&
              !book.isReserved &&
              local.reservationCode != null) {
            final code = Uri.encodeComponent(local.reservationCode!);
            await _applyReservationResponse(
              await api.request('POST', '/api/reservations/$code/cancel'),
              local,
            );
            return;
          }
          if (local.isBorrowed &&
              book.isBorrowed &&
              local.dueDate != book.dueDate) {
            final entry = reservations
                .where(
                  (entry) =>
                      entry['book_id'] == book.id &&
                      (entry['display_status'] ?? entry['status']) == 'issued',
                )
                .firstOrNull;
            if (entry == null) {
              throw const LibraryApiException('Белсенді берілім табылмады.');
            }
            final code = Uri.encodeComponent(entry['code'] as String);
            await _applyReservationResponse(
              await api.request('POST', '/api/reservations/$code/extend'),
              local,
            );
            return;
          }
          if (local.isFavorite != book.isFavorite) {
            final id = Uri.encodeComponent(book.id);
            await api.request(
              'PUT',
              '/api/books/$id/favorite',
              body: {'selected': book.isFavorite},
            );
            await _cacheBook(local.copyWith(isFavorite: book.isFavorite));
            return;
          }
        }
        // External search results are imported with POST before entering our catalogue.
        final saved = local == null
            ? await api.createBook(book)
            : await api.updateBook(book);
        await _cacheBook(
          _withPersonalState(saved, book),
          reservationHistory: reservationHistory,
        );
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

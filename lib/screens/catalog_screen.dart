import 'package:flutter/material.dart';

import '../models/book_model.dart';
import '../services/books_api_service.dart';
import '../services/library_database_service.dart';
import '../widgets/library_book_tile.dart';
import 'book_detail_screen.dart';
import 'book_form_screen.dart';
import 'qr_scanner_screen.dart';

enum CatalogSource { localOnly, all, openLibrary, googleBooks }

class CatalogScreen extends StatefulWidget {
  final List<Book> books;
  final Future<bool> Function(Book) onBookUpdated;
  final Future<bool> Function(Book)? onBookAdded;
  final Future<bool> Function(String bookId)? onBookDeleted;
  final bool staff;
  final Future<bool> Function(Book)? onReservationFinished;
  final int searchRequest;
  final bool loading;

  const CatalogScreen({
    super.key,
    required this.books,
    required this.onBookUpdated,
    this.onBookAdded,
    this.onBookDeleted,
    this.staff = false,
    this.onReservationFinished,
    this.searchRequest = 0,
    this.loading = false,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  CatalogSource _source = CatalogSource.localOnly;
  String? _category;
  bool _available = false;
  bool _audio = false;
  bool _ebook = false;
  bool _loading = false;
  String? _message;
  int _request = 0;
  List<Book> _external = [];
  BookSortOption _sort = BookSortOption.titleAsc;

  static const _sources = {
    CatalogSource.localOnly: 'Кітапхана қоры',
    CatalogSource.all: 'Барлық сыртқы дереккөз',
    CatalogSource.openLibrary: 'Open Library',
    CatalogSource.googleBooks: 'Google Books',
  };
  static const _sorts = {
    BookSortOption.titleAsc: 'Атауы · А–Я',
    BookSortOption.titleDesc: 'Атауы · Я–А',
    BookSortOption.ratingDesc: 'Рейтинг',
    BookSortOption.yearDesc: 'Жаңа басылымдар',
    BookSortOption.yearAsc: 'Ескі басылымдар',
    BookSortOption.pagesAsc: 'Бет саны',
  };

  bool get _local => _source == CatalogSource.localOnly;
  List<String> get _categories =>
      (widget.books
          .map((book) => book.category)
          .where((category) => category.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort());

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchRequest != oldWidget.searchRequest) {
      _source = CatalogSource.localOnly;
      _invalidateSearch();
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _invalidateSearch() {
    _request++;
    _loading = false;
    _message = null;
    _external = [];
  }

  Future<void> _searchOnline() async {
    final query = _search.text.trim();
    if (_local || query.isEmpty) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _message = null;
      _external = [];
    });
    try {
      final results = await switch (_source) {
        CatalogSource.openLibrary => BooksApiService.searchOpenLibrary(
          query,
          limit: 20,
        ),
        CatalogSource.googleBooks => BooksApiService.searchGoogleBooks(
          query,
          maxResults: 20,
        ),
        CatalogSource.all => BooksApiService.searchCombined(query, limit: 25),
        CatalogSource.localOnly => Future.value(<Book>[]),
      };
      if (!mounted || request != _request) return;
      setState(() {
        _external = results;
        _loading = false;
        if (results.isEmpty) {
          _message = 'Нәтиже жоқ. Сұрауды және интернет байланысын тексеріңіз.';
        }
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _message = 'Сыртқы каталогқа қосылу мүмкін болмады. Қайта көріңіз.';
      });
    }
  }

  List<Book> _results() {
    final query = _search.text.trim().toLowerCase();
    final candidates = _local
        ? widget.books.where((book) {
            return [
                  book.title,
                  book.author,
                  book.isbn,
                  book.description,
                  book.category,
                ].any((value) => value.toLowerCase().contains(query)) &&
                (_category == null || book.category == _category) &&
                (!_available ||
                    (book.isAvailable && book.availableCopies > 0)) &&
                (!_audio || book.hasAudio) &&
                (!_ebook || book.hasEBook);
          })
        : _external;
    return LibraryDatabaseService().sortBooks(candidates.toList(), _sort);
  }

  void _filters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          void change(VoidCallback update) {
            setState(update);
            setSheetState(() {});
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Сүзгі және сұрыптау',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<BookSortOption>(
                    initialValue: _sort,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Сұрыптау'),
                    items: [
                      for (final entry in _sorts.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) => change(() => _sort = value!),
                  ),
                  if (_local) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _categories.contains(_category)
                          ? _category
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Жанр'),
                      hint: const Text('Барлық жанр'),
                      items: [
                        const DropdownMenuItem<String>(
                          child: Text('Барлық жанр'),
                        ),
                        for (final category in _categories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(
                              category,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => change(() => _category = value),
                    ),
                    SwitchListTile(
                      title: const Text('Тек қолда бар даналар'),
                      value: _available,
                      onChanged: (value) => change(() => _available = value),
                    ),
                    SwitchListTile(
                      title: const Text('Аудиосы бар'),
                      value: _audio,
                      onChanged: (value) => change(() => _audio = value),
                    ),
                    SwitchListTile(
                      title: const Text('Электронды мәтіні бар'),
                      value: _ebook,
                      onChanged: (value) => change(() => _ebook = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Нәтижені көрсету'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final books = _results();
    final loading = _local ? widget.loading : _loading;
    final hasFilters = _category != null || _available || _audio || _ebook;
    final emptyLabel = _local
        ? widget.books.isEmpty
              ? 'Каталог әзірге бос'
              : 'Сәйкес кітап табылмады'
        : _message ??
              'Сыртқы каталогтан іздеу үшін атауын немесе авторын енгізіңіз.';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.staff ? 'Қызметкер бөлімі' : 'Кітаптар каталогы'),
        actions: [
          if (widget.staff)
            IconButton(
              tooltip: 'Бронь QR кодын тексеру',
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => QrScannerScreen(
                    onBookUpdated: widget.onReservationFinished,
                  ),
                ),
              ),
            ),
          if (widget.staff && widget.onBookAdded != null)
            IconButton(
              tooltip: 'Жаңа кітап қосу',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BookFormScreen(onSave: widget.onBookAdded!),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                sliver: SliverList.list(
                  children: [
                    Text(
                      widget.staff ? 'Қорды басқару' : 'Кітап табыңыз',
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 12),
                    ...[
                      DropdownButtonFormField<CatalogSource>(
                        key: ValueKey(_source),
                        initialValue: _source,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Іздеу аймағы',
                          prefixIcon: Icon(Icons.shelves),
                        ),
                        items: [
                          for (final entry in _sources.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _source = value!;
                            _invalidateSearch();
                          });
                          _searchOnline();
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            focusNode: _focus,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setState(_invalidateSearch),
                            onSubmitted: (_) => _searchOnline(),
                            decoration: InputDecoration(
                              hintText: 'Атауы, авторы немесе ISBN',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Іздеуді тазарту',
                                      onPressed: () => setState(() {
                                        _search.clear();
                                        _invalidateSearch();
                                      }),
                                      icon: const Icon(Icons.close),
                                    ),
                            ),
                          ),
                        ),
                        if (!_local) ...[
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: 'Сыртқы каталогтан іздеу',
                            onPressed: _loading || _search.text.trim().isEmpty
                                ? null
                                : _searchOnline,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ],
                    ),
                    if (!_local)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Сыртқы дереккөздер кітап туралы мәлімет береді. Қолжетімді даналар кітапхана қорында көрсетіледі.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${books.length} кітап',
                          style: theme.textTheme.titleMedium,
                        ),
                        TextButton.icon(
                          onPressed: _filters,
                          icon: const Icon(Icons.tune_rounded),
                          label: Text(
                            hasFilters && _local
                                ? 'Сүзгі · белсенді'
                                : 'Сүзгі және сұрыптау',
                          ),
                        ),
                      ],
                    ),
                    if (loading && (!_local || widget.staff))
                      const LinearProgressIndicator(),
                  ],
                ),
              ),
              if (books.isEmpty && !loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          emptyLabel,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (_message != null)
                          TextButton(
                            onPressed: _searchOnline,
                            child: const Text('Қайта іздеу'),
                          ),
                        if (_local && (hasFilters || _search.text.isNotEmpty))
                          TextButton(
                            onPressed: () => setState(() {
                              _search.clear();
                              _category = null;
                              _available = _audio = _ebook = false;
                            }),
                            child: const Text('Сүзгілерді тазарту'),
                          ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverList.builder(
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LibraryBookTile(
                        book: book,
                        inCollection: _local,
                        showInventory: widget.staff && _local,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => BookDetailScreen(
                              book: book,
                              inCollection: _local,
                              staff: widget.staff,
                              onBookAdded:
                                  widget.staff &&
                                      !widget.books.any(
                                        (item) => item.id == book.id,
                                      )
                                  ? widget.onBookAdded
                                  : null,
                              onBookUpdated: widget.onBookUpdated,
                              onBookDeleted: widget.staff
                                  ? widget.onBookDeleted
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

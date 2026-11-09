import 'package:flutter/material.dart';

import '../models/book_model.dart';
import '../widgets/audio_player_sheet.dart';
import '../widgets/library_book_tile.dart';
import 'book_detail_screen.dart';
import 'ereader_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<Book> books;
  final Future<bool> Function(Book) onBookUpdated;
  final Book? Function(String)? savedBook;
  final VoidCallback onNavigateToCatalog;
  final VoidCallback onNavigateToMyBooks;
  final String readerName;
  final Book? demoBook;
  final bool loading;
  final VoidCallback? onSearch;

  const HomeScreen({
    super.key,
    required this.books,
    required this.onBookUpdated,
    this.savedBook,
    required this.onNavigateToCatalog,
    required this.onNavigateToMyBooks,
    this.readerName = 'Оқырман',
    this.demoBook,
    this.loading = false,
    this.onSearch,
  });

  void _openBook(BuildContext context, Book book) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookDetailScreen(
          book: book,
          onBookUpdated: onBookUpdated,
          savedBook: savedBook,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = readerName.trim();
    final available = books
        .where((book) => book.isAvailable && book.availableCopies > 0)
        .toList();
    final featured = available.firstOrNull;
    final popular = books.where((book) => book.reviewCount > 0).toList()
      ..sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    final recentEditions = books.where((book) => book.publishYear > 0).toList()
      ..sort((a, b) => b.publishYear.compareTo(a.publishYear));
    final reserved = books.where((book) => book.hasActiveReservation).length;
    final demo = demoBook;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_stories_outlined, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('LibFlow', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    CircleAvatar(
                      child: Text(
                        name.isEmpty
                            ? '?'
                            : name.characters.first.toUpperCase(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  'КІТАПХАНА',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Сәлем, ${name.isEmpty ? 'Оқырман' : name.split(' ').first}!',
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Кітапты табыңыз, брондаңыз және кітапханадан алыңыз.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onSearch ?? onNavigateToCatalog,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Кітаптарды іздеу'),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    onTap: onNavigateToMyBooks,
                    leading: Icon(
                      Icons.confirmation_number_outlined,
                      color: scheme.primary,
                    ),
                    title: const Text('Менің броньдарым'),
                    subtitle: Text(
                      reserved == 0
                          ? 'Белсенді бронь жоқ'
                          : 'Белсенді бронь · $reserved',
                    ),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
                const SizedBox(height: 24),
                if (featured != null)
                  Card(
                    color: const Color(0xFF282E54),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ҚОРДАН ҰСЫНЫС',
                                  style: TextStyle(
                                    color: Color(0xFFF2CEA6),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  featured.title,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(color: Colors.white),
                                ),
                                Text(
                                  featured.author,
                                  style: const TextStyle(
                                    color: Color(0xFFE0E2F1),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFF2CEA6),
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () => _openBook(context, featured),
                                  child: const Text('Кітапты қарау →'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 82,
                            child: LibraryBookCover(book: featured),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (books.isEmpty && !loading)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.shelves),
                      title: Text('Каталог әзірге бос'),
                    ),
                  ),
                if (popular.isNotEmpty)
                  _Shelf(
                    title: 'Танымал кітаптар',
                    books: popular.take(6),
                    onBookTap: (book) => _openBook(context, book),
                  ),
                if (recentEditions.isNotEmpty)
                  _Shelf(
                    title: 'Жаңа басылымдар',
                    books: recentEditions.take(6),
                    onBookTap: (book) => _openBook(context, book),
                  ),
                if (demo != null) ...[
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Оқу және аудио · демо',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(demo.title),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.menu_book),
                                label: const Text('Демо кітапты оқу'),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => EReaderScreen(book: demo),
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.headphones),
                                label: const Text('Демо аудионы тыңдау'),
                                onPressed: () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => AudioPlayerSheet(book: demo),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.title,
    required this.books,
    required this.onBookTap,
  });
  final String title;
  final Iterable<Book> books;
  final ValueChanged<Book> onBookTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final book in books)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 132,
                      child: Card(
                        child: InkWell(
                          onTap: () => onBookTap(book),
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LibraryBookCover(book: book),
                                const SizedBox(height: 8),
                                Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  book.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

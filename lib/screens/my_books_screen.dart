import 'package:flutter/material.dart';

import '../models/book_model.dart';
import '../widgets/library_book_tile.dart';
import '../widgets/reservation_ticket.dart';
import 'book_detail_screen.dart';

class MyBooksScreen extends StatefulWidget {
  final List<Book> books;
  final Future<bool> Function(Book) onBookUpdated;
  final int initialTabIndex;
  final List<Loan> reservationHistory;
  final Future<bool> Function(Book)? onReservationFinished;

  const MyBooksScreen({
    super.key,
    required this.books,
    required this.onBookUpdated,
    this.initialTabIndex = 0,
    this.reservationHistory = const [],
    this.onReservationFinished,
  });

  @override
  State<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends State<MyBooksScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTabIndex,
  );
  bool _saving = false;

  @override
  void didUpdateWidget(covariant MyBooksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabs.animateTo(widget.initialTabIndex);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _save(
    Book book,
    String success, {
    bool finishReservation = false,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    final update = finishReservation
        ? widget.onReservationFinished ?? widget.onBookUpdated
        : widget.onBookUpdated;
    final saved = await update(book);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? success : 'Серверге сақтау орындалмады. Қайта көріңіз.',
        ),
      ),
    );
  }

  Future<void> _cancelReservation(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Броньды жою керек пе?'),
        content: Text('«${book.title}» данасы қорға қайтарылады.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Артқа'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Броньды жою'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final current = widget.books
        .where((item) => item.id == book.id)
        .firstOrNull;
    if (current == null ||
        !current.isReserved ||
        current.reservationCode != book.reservationCode ||
        current.reservationTime != book.reservationTime) {
      return;
    }
    final copies = current.availableCopies < current.totalCopies
        ? current.availableCopies + 1
        : current.availableCopies;
    await _save(
      current.copyWith(
        isReserved: false,
        reservationCode: null,
        availableCopies: copies,
      ),
      '«${book.title}» кітабының броны жойылды.',
      finishReservation: true,
    );
  }

  void _openBook(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            BookDetailScreen(book: book, onBookUpdated: widget.onBookUpdated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borrowed = widget.books.where((book) => book.isBorrowed).toList();
    final reserved = widget.books.where((book) => book.isReserved).toList()
      ..sort(
        (a, b) => (a.hasActiveReservation ? 0 : 1).compareTo(
          b.hasActiveReservation ? 0 : 1,
        ),
      );
    final favorites = widget.books.where((book) => book.isFavorite).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Менің кітаптарым'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Алынған (${borrowed.length})'),
            Tab(text: 'Брондалған (${reserved.length})'),
            Tab(text: 'Таңдаулы (${favorites.length})'),
            const Tab(text: 'Тарих'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: TabBarView(
            controller: _tabs,
            children: [
              _list(
                borrowed,
                'Алынған кітаптар жоқ',
                Icons.local_library_outlined,
                _borrowedCard,
              ),
              _list(
                reserved,
                'Броньдар жоқ',
                Icons.confirmation_number_outlined,
                _reservationCard,
              ),
              _list(
                favorites,
                'Таңдаулы кітаптар жоқ',
                Icons.favorite_border,
                (book) =>
                    LibraryBookTile(book: book, onTap: () => _openBook(book)),
              ),
              _history(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(
    List<Book> books,
    String empty,
    IconData icon,
    Widget Function(Book) card,
  ) {
    final theme = Theme.of(context);
    if (books.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            empty,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: books.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => card(books[index]),
    );
  }

  Widget _history() {
    if (widget.reservationHistory.isEmpty) {
      return _list(
        const [],
        'Аяқталған броньдар жоқ',
        Icons.history,
        (_) => const SizedBox(),
      );
    }
    final localizations = MaterialLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: widget.reservationHistory.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = widget.reservationHistory[index];
        final status = switch (entry.status) {
          'collected' => 'Кітап берілді',
          'expired' => 'Бронь мерзімі аяқталды',
          _ => 'Бронь жойылды',
        };
        final date = (entry.returnDate ?? entry.borrowDate).toLocal();
        return Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text(entry.bookTitle),
            subtitle: Text('$status · ${localizations.formatShortDate(date)}'),
          ),
        );
      },
    );
  }

  Widget _reservationCard(Book book) {
    final active = book.hasActiveReservation;
    return _ticket(
      book,
      active ? 'Белсенді бронь' : 'Бронь мерзімі аяқталған',
      [
        OutlinedButton.icon(
          onPressed: () => showReservationTicket(context, book),
          icon: Icon(active ? Icons.qr_code_2 : Icons.info_outline),
          label: Text(active ? 'Бронь билеті' : 'Мәлімет'),
        ),
        TextButton(
          onPressed: _saving ? null : () => _cancelReservation(book),
          child: Text(active ? 'Броньды жою' : 'Броньды жабу'),
        ),
      ],
    );
  }

  Widget _borrowedCard(Book book) {
    final due = book.dueDate;
    final date = due == null
        ? null
        : MaterialLocalizations.of(context).formatShortDate(due.toLocal());
    final overdue = due?.isBefore(DateTime.now()) ?? false;
    return _ticket(
      book,
      date == null
          ? 'Берілген кітап'
          : overdue
          ? 'Мерзімі өтті · $date'
          : 'Қайтару күні · $date',
      [
        OutlinedButton(
          onPressed: _saving
              ? null
              : () {
                  final currentDue =
                      due ?? DateTime.now().add(const Duration(days: 3));
                  final next = currentDue.add(const Duration(days: 7));
                  _save(
                    book.copyWith(dueDate: next),
                    'Қайтару мерзімі 7 күнге ұзартылды.',
                  );
                },
          child: const Text('7 күнге ұзарту'),
        ),
      ],
    );
  }

  Widget _ticket(Book book, String status, List<Widget> actions) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openBook(book),
              child: Row(
                children: [
                  SizedBox(width: 54, child: LibraryBookCover(book: book)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(book.title, style: theme.textTheme.titleMedium),
                        Text(book.author, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: actions),
          ],
        ),
      ),
    );
  }
}

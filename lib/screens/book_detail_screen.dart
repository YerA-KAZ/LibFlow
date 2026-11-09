import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book_model.dart';

import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/audio_player_sheet.dart';
import '../widgets/library_book_tile.dart';
import '../widgets/reservation_ticket.dart';
import 'book_form_screen.dart';
import 'ereader_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;
  final bool inCollection;
  final bool staff;
  final Future<bool> Function(Book)? onBookAdded;
  final Future<bool> Function(Book updatedBook) onBookUpdated;
  final Book? Function(String)? savedBook;
  final Future<bool> Function(String bookId)? onBookDeleted;

  const BookDetailScreen({
    super.key,
    required this.book,
    required this.onBookUpdated,
    this.savedBook,
    this.onBookDeleted,
    this.onBookAdded,
    this.inCollection = true,
    this.staff = false,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late Book _book;
  bool _isMutating = false;

  void _showMutationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Серверге сақтау орындалмады. Қайта көріңіз.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  final List<BookReview> _reviews = [];

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  void _confirmDeleteBook() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.delete_forever_rounded,
              color: AppColors.error,
              size: 28,
            ),
            SizedBox(width: 8),
            Text(
              'Кітапты өшіру',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '«${_book.title}» кітабын қордан біржола өшіргіңіз келе ме? Бұл әрекетті қайтару мүмкін емес.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Бас тарту'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (_isMutating || widget.onBookDeleted == null) return;
              setState(() => _isMutating = true);
              final deleted = await widget.onBookDeleted!(_book.id);
              if (!mounted || !ctx.mounted) return;
              setState(() => _isMutating = false);
              Navigator.pop(ctx);
              if (deleted) {
                Navigator.pop(context, 'deleted');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Кітап серверден өшірілді.')),
                );
              } else {
                _showMutationError();
              }
            },
            child: const Text('Өшіру'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    final updated = _book.copyWith(isFavorite: !_book.isFavorite);
    final saved = await widget.onBookUpdated(updated);
    if (!mounted) return;
    setState(() {
      _isMutating = false;
      if (saved) _book = widget.savedBook?.call(updated.id) ?? updated;
    });
    if (!saved) _showMutationError();
  }

  Future<void> _reserveBook() async {
    if (_isMutating) return;
    if (!widget.inCollection ||
        _book.isReserved ||
        _book.isBorrowed ||
        !_book.isAvailable ||
        _book.availableCopies <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Бұл кітап қазір қорда жоқ!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final random = Random.secure();
    final suffix = List.generate(
      4,
      (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
    ).join().toUpperCase();
    final code = 'LIBFLOW-$suffix';
    final updated = _book.copyWith(
      isReserved: true,
      reservationTime: DateTime.now(),
      reservationCode: code,
      availableCopies: _book.availableCopies - 1,
    );
    setState(() => _isMutating = true);
    final saved = await widget.onBookUpdated(updated);
    if (!mounted) return;
    setState(() {
      _isMutating = false;
      if (saved) _book = widget.savedBook?.call(updated.id) ?? updated;
    });
    if (!saved) {
      _showMutationError();
      return;
    }

    await showReservationTicket(context, _book);
  }

  void _showAddReviewDialog() {
    double selectedRating = 5.0;
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Пікір мен рейтинг қосу'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Бағалау (1-ден 5-ке дейін):',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    iconSize: 32,
                    icon: Icon(
                      index < selectedRating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.accent,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        selectedRating = (index + 1).toDouble();
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Осы кітап туралы пікіріңізді жазыңыз...',
                  hintStyle: const TextStyle(fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Бас тарту'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  setState(() {
                    _reviews.insert(
                      0,
                      BookReview(
                        id: DateTime.now().toString(),
                        userName:
                            context.read<AuthProvider?>()?.user?['name']
                                as String? ??
                            'Оқырман',
                        rating: selectedRating,
                        date: 'Бүгін',
                        comment: textController.text.trim(),
                      ),
                    );
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Пікіріңіз сәтті жарияланды!'),
                    ),
                  );
                }
              },
              child: const Text('Жариялау'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inCollection = widget.inCollection;
    final available =
        !_book.isBorrowed && _book.isAvailable && _book.availableCopies > 0;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.staff ? 'Қордағы кітап' : 'Кітап туралы'),
        actions: [
          if (inCollection && widget.staff) ...[
            IconButton(
              tooltip: 'Кітапты өңдеу',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _isMutating ? null : _editBook,
            ),
            if (widget.onBookDeleted != null)
              IconButton(
                tooltip: 'Кітапты өшіру',
                icon: const Icon(Icons.delete_outline),
                onPressed: _isMutating ? null : _confirmDeleteBook,
              ),
          ],
          if (inCollection && !widget.staff)
            IconButton(
              tooltip: _book.isFavorite
                  ? 'Таңдаулыдан алып тастау'
                  : 'Таңдаулыға қосу',
              icon: Icon(
                _book.isFavorite ? Icons.favorite : Icons.favorite_border,
              ),
              onPressed: _isMutating ? null : _toggleFavorite,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 20,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 124,
                      child: LibraryBookCover(book: _book),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(_book.title, style: theme.textTheme.displaySmall),
              const SizedBox(height: 4),
              Text(
                _book.author,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  BookAvailability(book: _book, inCollection: inCollection),
                  if (_book.category.isNotEmpty) Text(_book.category),
                  if (_book.publishYear > 0) Text('· ${_book.publishYear}'),
                  if (_book.pages > 0) Text('· ${_book.pages} бет'),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: Icon(
                    inCollection ? Icons.local_library_outlined : Icons.public,
                    color: scheme.primary,
                  ),
                  title: Text(inCollection ? 'Қағаз дана' : _book.source),
                  subtitle: Text(
                    !inCollection
                        ? 'Бұл дереккөз кітапханадағы даналар туралы ақпарат бермейді.'
                        : widget.staff
                        ? 'Қолда бар дана: ${_book.availableCopies} / ${_book.totalCopies}'
                        : _book.isReserved
                        ? (_book.hasActiveReservation
                              ? 'Кітап сізге брондалған.'
                              : 'Бронь мерзімі аяқталған.')
                        : _book.isBorrowed
                        ? 'Бұл кітап сізге берілген.'
                        : available
                        ? 'Брондалған дананы 24 сағат ішінде кітапханадан алыңыз.'
                        : 'Брондауға қолжетімді дана жоқ.',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Кітап туралы', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                _book.description.trim().isEmpty
                    ? 'Сипаттама әзірге жоқ.'
                    : _book.description,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
              ),
              if (_book.isbn.trim().isNotEmpty && _book.isbn != 'ISBN-жоқ') ...[
                const SizedBox(height: 10),
                Text('ISBN ${_book.isbn}', style: theme.textTheme.bodySmall),
              ],
              if (!inCollection && (_book.previewUrl ?? _book.infoUrl) != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('Дереккөз сілтемесін көшіру'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: (_book.previewUrl ?? _book.infoUrl)!,
                        ),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Сілтеме көшірілді.')),
                      );
                    },
                  ),
                ),
              if (_book.canRead || _book.hasAudio) ...[
                const SizedBox(height: 24),
                Text('Танысуға арналған', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                if (_book.canRead)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EReaderScreen(book: _book),
                      ),
                    ),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Оқуды бастау'),
                  ),
                if (_book.hasAudio)
                  OutlinedButton.icon(
                    onPressed: !_book.canListen
                        ? null
                        : () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => AudioPlayerSheet(book: _book),
                          ),
                    icon: const Icon(Icons.headphones_outlined),
                    label: const Text('Аудио тыңдау'),
                  ),
              ],
              if (inCollection && !widget.staff) ...[
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Пікірлер · осы сеанс',
                      style: theme.textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: _showAddReviewDialog,
                      child: const Text('Пікір жазу'),
                    ),
                  ],
                ),
                ..._reviews.map((review) => _buildReviewTile(review, isDark)),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          (inCollection && !widget.staff) ||
              (!inCollection && widget.staff && widget.onBookAdded != null)
          ? BottomAppBar(
              height: 76,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: Icon(
                        _book.isReserved
                            ? Icons.qr_code_2
                            : Icons.confirmation_number_outlined,
                      ),
                      label: Text(
                        !inCollection
                            ? 'Қорға қосу'
                            : _isMutating
                            ? 'Сақталуда…'
                            : _book.isReserved
                            ? 'Бронь билеті'
                            : _book.isBorrowed
                            ? 'Бұл кітап сізге берілген.'
                            : available
                            ? 'Дананы брондау'
                            : 'Дана қолжетімсіз',
                      ),
                      onPressed: _isMutating
                          ? null
                          : !inCollection
                          ? _importBook
                          : _book.isReserved
                          ? () => showReservationTicket(context, _book)
                          : available
                          ? _reserveBook
                          : null,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _editBook() async {
    final updated = await Navigator.push<Book>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BookFormScreen(book: _book, onSave: widget.onBookUpdated),
      ),
    );
    if (mounted && updated != null) setState(() => _book = updated);
  }

  void _importBook() {
    Navigator.push(
      context,
      MaterialPageRoute<Book>(
        builder: (_) => BookFormScreen(
          book: _book,
          onSave: widget.onBookAdded!,
          importing: true,
        ),
      ),
    );
  }

  Widget _buildReviewTile(BookReview review, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withAlpha(40),
                child: Text(
                  review.userName.substring(0, 1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      review.date,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    review.rating.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

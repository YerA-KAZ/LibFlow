import 'package:flutter/material.dart';

import '../models/book_model.dart';

class LibraryBookCover extends StatelessWidget {
  const LibraryBookCover({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final url = book.coverUrl?.trim();
    final fallback = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const inks = [
          Color(0xFF364268),
          Color(0xFF773C3D),
          Color(0xFF31534F),
          Color(0xFF624A36),
        ];
        final ink = inks[book.id.hashCode % inks.length];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: ink,
            border: const Border(
              left: BorderSide(color: Color(0x44FFFFFF), width: 4),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(width * .12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  color: const Color(0xFFF0D4A7),
                  size: width * .24,
                ),
                SizedBox(height: width * .08),
                Flexible(
                  child: Text(
                    book.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const ['serif', 'Roboto', 'Segoe UI'],
                      color: Colors.white,
                      fontSize: (width * .105).clamp(8, 21).toDouble(),
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url == null || url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class BookAvailability extends StatelessWidget {
  const BookAvailability({
    super.key,
    required this.book,
    this.inCollection = true,
  });
  final Book book;
  final bool inCollection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final available =
        inCollection && book.isAvailable && book.availableCopies > 0;
    final label = !inCollection
        ? 'Сыртқы каталог'
        : available
        ? 'Қолда бар · ${book.availableCopies}'
        : 'Қазір қолда жоқ';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: available
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: available
                ? scheme.onTertiaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class LibraryBookTile extends StatelessWidget {
  const LibraryBookTile({
    super.key,
    required this.book,
    required this.onTap,
    this.inCollection = true,
    this.showInventory = false,
  });
  final Book book;
  final VoidCallback onTap;
  final bool inCollection;
  final bool showInventory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(width: 60, child: LibraryBookCover(book: book)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    BookAvailability(book: book, inCollection: inCollection),
                    if (showInventory)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Дана: ${book.availableCopies} / ${book.totalCopies}',
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

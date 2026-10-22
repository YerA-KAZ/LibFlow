import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../utils/constants.dart';
import 'book_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<Book> books;
  final Function(Book) onBookUpdated;
  final VoidCallback onNavigateToCatalog;
  final VoidCallback onNavigateToMyBooks;

  const HomeScreen({
    super.key,
    required this.books,
    required this.onBookUpdated,
    required this.onNavigateToCatalog,
    required this.onNavigateToMyBooks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final readingBook = books.firstWhere(
      (b) => b.isBorrowed || b.title.contains('Абай'),
      orElse: () => books.first,
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сәлем, Айша!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Бүгін қандай кітап оқимыз?',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          // Circular Avatar (A) as in Figma screen 06
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFE5EDE8),
              child: const Text(
                'A',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field matching Figma
            GestureDetector(
              onTap: onNavigateToCatalog,
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.textSecondaryLight, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Кітаптарды іздеу',
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Figma Hero Promo Banner: "АПТАНЫҢ ТАҢДАУЫ: Шабыт сыйлар кітаптар"
            Container(
              height: 140,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'АПТАНЫҢ ТАҢДАУЫ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Шабыт сыйлар\nкітаптар',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '20+ жаңа шығарма',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Styled book preview on the right
                  Transform.rotate(
                    angle: 0.08,
                    child: Container(
                      width: 72,
                      height: 98,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC06C52),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFD4A373), width: 3),
                            ),
                          ),
                          const Positioned(
                            bottom: 8,
                            child: Text(
                              'Абай\nжолы',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Section: Оқуды жалғастыру (Continue reading)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Оқуды жалғастыру',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                GestureDetector(
                  onTap: onNavigateToMyBooks,
                  child: const Row(
                    children: [
                      Text(
                        'Барлығы',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primaryLight),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reading Progress Card
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookDetailScreen(
                      book: readingBook,
                      onBookUpdated: onBookUpdated,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    // Book mini cover
                    Container(
                      width: 52,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFD4A373), width: 2),
                            ),
                          ),
                          const Positioned(
                            bottom: 6,
                            child: Text(
                              'Абай жолы',
                              style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            readingBook.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '45 / 190 бет • 24%',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: 0.24,
                              minHeight: 5,
                              backgroundColor: isDark ? Colors.white12 : const Color(0xFFE5EDE8),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Section: Сізге ұсынылады (Recommended for you)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Сізге ұсынылады',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                GestureDetector(
                  onTap: onNavigateToCatalog,
                  child: const Row(
                    children: [
                      Text(
                        'Қарау',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primaryLight),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2-column Figma Cards
            Row(
              children: [
                Expanded(
                  child: _buildFigmaBookItem(
                    title: 'Көшпенділер',
                    author: 'І. Есенберлин',
                    rating: '4.8',
                    coverColor: const Color(0xFF1E3347),
                    isDark: isDark,
                    onTap: () {
                      final b = books.firstWhere((b) => b.title.contains('Көшпенділер'), orElse: () => books[1]);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: b, onBookUpdated: onBookUpdated)));
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildFigmaBookItem(
                    title: '1984',
                    author: 'Джордж Оруэлл',
                    rating: '4.8',
                    coverColor: const Color(0xFF282B30),
                    isDark: isDark,
                    onTap: () {
                      final b = books.firstWhere((b) => b.title.contains('Қан мен тер'), orElse: () => books[2]);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: b, onBookUpdated: onBookUpdated)));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFigmaBookItem({
    required String title,
    required String author,
    required String rating,
    required Color coverColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Styled Figma Book Cover with Gold Circle
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: coverColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4A373), width: 3),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD4A373)),
                const SizedBox(width: 3),
                Text(
                  rating,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

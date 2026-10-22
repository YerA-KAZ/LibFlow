import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../utils/constants.dart';
import '../widgets/qr_widget.dart';
import 'book_detail_screen.dart';

class MyBooksScreen extends StatefulWidget {
  final List<Book> books;
  final Function(Book) onBookUpdated;

  const MyBooksScreen({
    super.key,
    required this.books,
    required this.onBookUpdated,
  });

  @override
  State<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends State<MyBooksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Book> get _borrowedBooks =>
      widget.books.where((b) => b.isBorrowed).toList();

  List<Book> get _reservedBooks =>
      widget.books.where((b) => b.isReserved).toList();

  List<Book> get _favorites =>
      widget.books.where((b) => b.isFavorite).toList();

  void _extendBorrow(Book book) {
    final currentDue = book.dueDate ?? DateTime.now().add(const Duration(days: 3));
    final newDue = currentDue.add(const Duration(days: 7));

    final updated = book.copyWith(dueDate: newDue);
    widget.onBookUpdated(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: Text(
          '«${book.title}» мерзімі +7 күнге сәтті ұзартылды!\nЖаңа дедлайн: ${newDue.day}.${newDue.month}.${newDue.year}',
        ),
      ),
    );
  }

  void _cancelReservation(Book book) {
    final updated = book.copyWith(
      isReserved: false,
      reservationCode: null,
      availableCopies: book.availableCopies + 1,
    );
    widget.onBookUpdated(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«${book.title}» кітабының броны жойылды.'),
      ),
    );
  }

  void _showReservationQr(Book book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(book.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Кітапханашыға осы кодты көрсетіп, кітапты алып кетіңіз:',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CustomQrView(data: book.reservationCode ?? 'LIB-8492', size: 180),
            const SizedBox(height: 12),
            Text(
              'Код: ${book.reservationCode ?? "LIB-8492"}',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Жабу'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Менің кітаптарым',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryLight,
          indicatorColor: AppColors.primaryLight,
          tabs: [
            Tab(text: 'Алынған (${_borrowedBooks.length})'),
            Tab(text: 'Брондалған (${_reservedBooks.length})'),
            Tab(text: 'Сүйіктілер (${_favorites.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Borrowed Books Tab
          _borrowedBooks.isEmpty
              ? _buildEmptyState('Алынған кітаптар жоқ', Icons.book_outlined, isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _borrowedBooks.length,
                  itemBuilder: (context, index) {
                    final book = _borrowedBooks[index];
                    final dueDate = book.dueDate ?? DateTime.now().add(const Duration(days: 3));
                    final daysLeft = dueDate.difference(DateTime.now()).inDays;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 30 : 8),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 68,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: book.coverGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Icon(Icons.auto_stories, color: Colors.white, size: 24),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      book.author,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Тапсыру мерзімі:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${dueDate.day}.${dueDate.month}.${dueDate.year}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: daysLeft <= 3 ? AppColors.error.withAlpha(25) : AppColors.success.withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$daysLeft күн қалды',
                                  style: TextStyle(
                                    color: daysLeft <= 3 ? AppColors.error : AppColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // US-04: «Мерзімді ұзарту» батырмасы (+7 күн)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.update_rounded, size: 18),
                              label: const Text('Мерзімді ұзарту (+7 күн)'),
                              onPressed: () => _extendBorrow(book),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

          // 2. Reserved Books Tab
          _reservedBooks.isEmpty
              ? _buildEmptyState('Брондалған кітаптар жоқ', Icons.qr_code_2_rounded, isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reservedBooks.length,
                  itemBuilder: (context, index) {
                    final book = _reservedBooks[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
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
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 68,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: book.coverGradient),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Icon(Icons.bookmark_added, color: Colors.white, size: 24),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      book.author,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 18, color: AppColors.warning),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Бронь 24 сағат сақталады. Кітапханадан алып кетіңіз.',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.qr_code, size: 18),
                                  label: const Text('QR көрсету'),
                                  onPressed: () => _showReservationQr(book),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                tooltip: 'Броньды жою',
                                onPressed: () => _cancelReservation(book),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

          // 3. Favorites Tab
          _favorites.isEmpty
              ? _buildEmptyState('Сүйікті кітаптар жоқ', Icons.favorite_border_rounded, isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final book = _favorites[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: book.coverGradient),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_stories, color: Colors.white, size: 20),
                      ),
                      title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(book.author),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () {
                          widget.onBookUpdated(book.copyWith(isFavorite: false));
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookDetailScreen(
                              book: book,
                              onBookUpdated: widget.onBookUpdated,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: isDark ? Colors.white24 : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Каталогтан кітаптарды таңдап, осы жерден бақылаңыз',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

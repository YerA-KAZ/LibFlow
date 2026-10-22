import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../services/dummy_books.dart';
import '../utils/constants.dart';
import '../widgets/audio_player_sheet.dart';
import '../widgets/qr_widget.dart';
import 'ereader_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;
  final Function(Book updatedBook) onBookUpdated;

  const BookDetailScreen({
    super.key,
    required this.book,
    required this.onBookUpdated,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late Book _book;
  final List<BookReview> _reviews = DummyDataService.getSampleReviews();

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  void _toggleFavorite() {
    setState(() {
      _book = _book.copyWith(isFavorite: !_book.isFavorite);
    });
    widget.onBookUpdated(_book);
  }

  void _reserveBook() {
    if (!_book.isAvailable || _book.availableCopies <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Бұл кітап қазір қорда жоқ!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final code = 'LIBFLOW-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    setState(() {
      _book = _book.copyWith(
        isReserved: true,
        reservationTime: DateTime.now(),
        reservationCode: code,
        availableCopies: _book.availableCopies - 1,
      );
    });
    widget.onBookUpdated(_book);

    // Show Reservation Modal with QR Code
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Text('Брондау сәтті аяқталды!', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Кітап сізге 24 сағатқа брондалды. Кітапханаға барып, кітапханашыға осы QR-кодты көрсетіңіз:',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CustomQrView(data: code, size: 180),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Бронь коды: $code',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Жабу', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddReviewDialog() {
    double selectedRating = 5.0;
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Пікір мен рейтинг қосу'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Бағалау (1-ден 5-ке дейін):', style: TextStyle(fontSize: 13)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  setState(() {
                    _reviews.insert(
                      0,
                      BookReview(
                        id: DateTime.now().toString(),
                        userName: 'Ернұр Асқаров',
                        rating: selectedRating,
                        date: 'Бүгін',
                        comment: textController.text.trim(),
                      ),
                    );
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пікіріңіз сәтті жарияланды!')),
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Collapsible App Bar with Forest Green Cover Container matching Figma 08
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _book.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _book.isFavorite ? Colors.redAccent : Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: _toggleFavorite,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.primary,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 36),
                      // Figma Floating Book Cover with Gold Circle
                      Container(
                        width: 130,
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC06C52),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(90),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFD4A373), width: 3.5),
                              ),
                            ),
                            Positioned(
                              bottom: 18,
                              child: Text(
                                _book.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Book Details Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Author
                  Text(
                    _book.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _book.author,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Figma 08: Rating, Pages, Language row
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFD4A373), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${_book.rating}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(
                        '${_book.pages} бет',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(
                        'Қазақша',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Figma 08 Genre Tags: Классика, Роман
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF0ECE3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Классика',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF0ECE3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Роман',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section Title: Кітап туралы
                  const Text(
                    'Кітап туралы',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _book.description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Prominent Figma 08 Action Button: "Оқуды бастау ->"
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EReaderScreen(book: _book),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Оқуды бастау',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  if (_book.hasAudio) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.headphones_rounded),
                        label: const Text('Аудио тыңдау',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            builder: (_) => AudioPlayerSheet(book: _book),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Physical Library Reservation Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: AppColors.primaryLight),
                            const SizedBox(width: 8),
                            const Text(
                              'Кітапханадан физикалық алу',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const Spacer(),
                            if (_book.isReserved)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Брондалған',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Кітапты онлайн брондап, 24 сағат ішінде QR-кодпен кітапханадан кезексіз алыңыз.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _book.isReserved
                                  ? Colors.grey
                                  : AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: Text(
                              _book.isReserved
                                  ? 'Брондау коды сақталды'
                                  : 'Қазір брондау (24 сағат)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _book.isReserved ? null : _reserveBook,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    'Кітап туралы мәлімет',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _book.description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ISBN: ${_book.isbn}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 28),

                  // Reviews section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Оқырмандар пікірлері',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Пікір жазу'),
                        onPressed: _showAddReviewDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._reviews.map((r) => _buildReviewTile(r, isDark)),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    review.date,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 2),
                  Text(
                    review.rating.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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

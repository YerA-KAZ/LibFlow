import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../utils/constants.dart';

enum ReaderTheme { white, sepia, dark }

class EReaderScreen extends StatefulWidget {
  final Book book;

  const EReaderScreen({super.key, required this.book});

  @override
  State<EReaderScreen> createState() => _EReaderScreenState();
}

class _EReaderScreenState extends State<EReaderScreen> {
  double _fontSize = 17.0;
  ReaderTheme _readerTheme = ReaderTheme.white;
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        setState(() {
          _scrollProgress = (_scrollController.offset /
                  _scrollController.position.maxScrollExtent)
              .clamp(0.0, 1.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getBgColor() {
    switch (_readerTheme) {
      case ReaderTheme.white:
        return const Color(0xFFF9F7F2); // Warm Cream Paper matching Figma
      case ReaderTheme.sepia:
        return const Color(0xFFF5EFEB);
      case ReaderTheme.dark:
        return const Color(0xFF131A16);
    }
  }

  Color _getTextColor() {
    switch (_readerTheme) {
      case ReaderTheme.white:
        return const Color(0xFF1E2320); // Deep charcoal
      case ReaderTheme.sepia:
        return const Color(0xFF3E342B);
      case ReaderTheme.dark:
        return const Color(0xFFE5EDE8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBgColor();
    final textColor = _getTextColor();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.book.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          // "Aa" button as in Figma Screen 09
          IconButton(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: textColor.withAlpha(60)),
              ),
              child: Text(
                'Aa',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ),
            onPressed: () => _showSettingsModal(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Mode Indicator Header as in Figma: "ОҚУ РЕЖИМІ • МӘТІН ҮЛГІСІ"
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text(
              'ОҚУ РЕЖИМІ • МӘТІН ҮЛГІСІ',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                color: textColor.withAlpha(120),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Figma Title: Оқу — ойға саяхат
                  Text(
                    'Оқу — ойға саяхат',
                    style: TextStyle(
                      fontSize: _fontSize + 7,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Кітап бетін ашқан сәтте алдымыздан жаңа әлем ашылады. Әрбір тарау жаңа ойға жетелейді, ал әрбір кейіпкер өмірге басқа қырынан қарауға көмектеседі.\n\nТыныш кеште оқылған жақсы кітап адамға ерекше әсер қалдырады. Ол тек ақпарат көзі емес, өзімізді танудың да бір жолы.\n\nБірнеше беттен басталған оқу әдеті уақыт өте үлкен жетістікке айналуы мүмкін.',
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: 1.8,
                      letterSpacing: 0.2,
                      color: textColor,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    widget.book.readingContent,
                    style: TextStyle(
                      fontSize: _fontSize,
                      height: 1.8,
                      letterSpacing: 0.2,
                      color: textColor,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Bottom Bar matching Figma Screen 09
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                top: BorderSide(color: textColor.withAlpha(20)),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '45 / 190 бет',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textColor.withAlpha(150),
                      ),
                    ),
                    Text(
                      '${(_scrollProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor.withAlpha(150),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: textColor.withAlpha(60)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Оқуды аяқтау',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Оқу баптаулары',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Font Size
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Қаріп өлшемі',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.remove),
                            onPressed: _fontSize > 12
                                ? () {
                                    setState(() => _fontSize -= 1);
                                    setModalState(() {});
                                  }
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '${_fontSize.toInt()} pt',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.add),
                            onPressed: _fontSize < 28
                                ? () {
                                    setState(() => _fontSize += 1);
                                    setModalState(() {});
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Color Scheme
                  const Text('Фон тақырыбы',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildThemeTile('Ашық', ReaderTheme.white,
                          const Color(0xFFFAFAFA), Colors.black, setModalState),
                      const SizedBox(width: 12),
                      _buildThemeTile('Сепия', ReaderTheme.sepia,
                          const Color(0xFFFBF0D9), const Color(0xFF45322E), setModalState),
                      const SizedBox(width: 12),
                      _buildThemeTile('Қараңғы', ReaderTheme.dark,
                          const Color(0xFF121826), Colors.white, setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeTile(String label, ReaderTheme theme, Color bg, Color text,
      void Function(void Function()) setModalState) {
    final bool isSelected = _readerTheme == theme;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _readerTheme = theme);
          setModalState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.grey[300]!,
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.text_fields_rounded, color: text, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: text,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

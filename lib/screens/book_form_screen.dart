import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../utils/constants.dart';

class BookFormScreen extends StatefulWidget {
  final Book? book; // If provided, edit mode. If null, create mode.
  final Function(Book) onSave;

  const BookFormScreen({
    super.key,
    this.book,
    required this.onSave,
  });

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _descriptionController;
  late TextEditingController _isbnController;
  late TextEditingController _pagesController;
  late TextEditingController _publishYearController;
  late TextEditingController _totalCopiesController;
  late TextEditingController _coverUrlController;
  late TextEditingController _audioDurationController;
  late TextEditingController _readingContentController;

  late String _selectedCategory;
  late bool _hasEBook;
  late bool _hasAudio;
  late bool _isAvailable;

  final List<String> _categories = [
    'Классика',
    'Роман',
    'Ғылыми-көпшілік',
    'Тарих',
    'Психология',
    'Бизнес',
    'Поэзия',
    'Фантастика',
    'Жалпы әдебиет',
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.book;

    _titleController = TextEditingController(text: b?.title ?? '');
    _authorController = TextEditingController(text: b?.author ?? '');
    _descriptionController = TextEditingController(text: b?.description ?? '');
    _isbnController = TextEditingController(
      text: b?.isbn ?? '978-601-${DateTime.now().millisecondsSinceEpoch.toString().substring(6, 12)}',
    );
    _pagesController = TextEditingController(text: (b?.pages ?? 250).toString());
    _publishYearController = TextEditingController(
      text: (b?.publishYear ?? DateTime.now().year).toString(),
    );
    _totalCopiesController = TextEditingController(
      text: (b?.totalCopies ?? 5).toString(),
    );
    _coverUrlController = TextEditingController(text: b?.coverUrl ?? '');
    _audioDurationController = TextEditingController(text: b?.audioDuration ?? '1 сағ 45 мин');
    _readingContentController = TextEditingController(
      text: b?.readingContent ??
          'Бұл кітаптың толық электронды мәтіні осы жерге жүктеледі немесе оқырмандарға ұсынылады.',
    );

    _selectedCategory = (b != null && _categories.contains(b.category))
        ? b.category
        : _categories.first;
    _hasEBook = b?.hasEBook ?? true;
    _hasAudio = b?.hasAudio ?? false;
    _isAvailable = b?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _isbnController.dispose();
    _pagesController.dispose();
    _publishYearController.dispose();
    _totalCopiesController.dispose();
    _coverUrlController.dispose();
    _audioDurationController.dispose();
    _readingContentController.dispose();
    super.dispose();
  }

  void _saveBook() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Барлық міндетті өрістерді дұрыс толтырыңыз!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final pages = int.tryParse(_pagesController.text.trim()) ?? 200;
    final year = int.tryParse(_publishYearController.text.trim()) ?? DateTime.now().year;
    final totalCopies = int.tryParse(_totalCopiesController.text.trim()) ?? 3;
    final isEdit = widget.book != null;

    final resultBook = Book(
      id: widget.book?.id ?? 'book_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      category: _selectedCategory,
      rating: widget.book?.rating ?? 4.8,
      reviewCount: widget.book?.reviewCount ?? 12,
      pages: pages,
      publishYear: year,
      isbn: _isbnController.text.trim(),
      description: _descriptionController.text.trim(),
      coverGradient: widget.book?.coverGradient ??
          const [AppColors.primary, AppColors.primaryLight],
      coverUrl: _coverUrlController.text.trim().isNotEmpty
          ? _coverUrlController.text.trim()
          : widget.book?.coverUrl,
      source: widget.book?.source ?? 'LibFlow',
      isAvailable: _isAvailable && totalCopies > 0,
      availableCopies: widget.book != null
          ? (widget.book!.availableCopies > totalCopies ? totalCopies : widget.book!.availableCopies)
          : totalCopies,
      totalCopies: totalCopies,
      hasEBook: _hasEBook,
      hasAudio: _hasAudio,
      audioDuration: _audioDurationController.text.trim(),
      readingContent: _readingContentController.text.trim(),
      isFavorite: widget.book?.isFavorite ?? false,
      isReserved: widget.book?.isReserved ?? false,
      reservationTime: widget.book?.reservationTime,
      reservationCode: widget.book?.reservationCode,
      isBorrowed: widget.book?.isBorrowed ?? false,
      dueDate: widget.book?.dueDate,
    );

    widget.onSave(resultBook);
    Navigator.pop(context, resultBook);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEdit
              ? '«${resultBook.title}» кітабы сәтті жаңартылды!'
              : '«${resultBook.title}» кітапхана қорына қосылды!',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.book != null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Кітапты өңдеу' : 'Жаңа кітап қосу',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.primary),
            tooltip: 'Сақтау',
            onPressed: _saveBook,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note_rounded : Icons.library_add_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Деректерді жаңарту' : 'Каталогқа кітап енгізу',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Кітапхана қорындағы жазбаларды басқару',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Section: Негізгі ақпарат
            _buildSectionHeader('Негізгі мәліметтер', Icons.menu_book_rounded),
            const SizedBox(height: 12),

            // Title Field
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration(
                label: 'Кітап атауы *',
                hint: 'Мысалы: Абай жолы',
                icon: Icons.title_rounded,
                isDark: isDark,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Кітап атауын енгізу міндетті';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Author Field
            TextFormField(
              controller: _authorController,
              decoration: _inputDecoration(
                label: 'Авторы *',
                hint: 'Мысалы: Мұхтар Әуезов',
                icon: Icons.person_rounded,
                isDark: isDark,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Автордың аты-жөнін көрсетіңіз';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: _inputDecoration(
                label: 'Санаты (Жанры) *',
                hint: 'Санатты таңдаңыз',
                icon: Icons.category_rounded,
                isDark: isDark,
              ),
              dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
              items: _categories.map((c) {
                return DropdownMenuItem<String>(
                  value: c,
                  child: Text(c),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: _inputDecoration(
                label: 'Қысқаша аннотация / сипаттама *',
                hint: 'Кітап мазмұны туралы қысқаша жазыңыз...',
                icon: Icons.notes_rounded,
                isDark: isDark,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Кітап сипаттамасын енгізіңіз';
                }
                if (value.trim().length < 10) {
                  return 'Сипаттама тым қысқа (кемінде 10 таңба)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Section: Баспа және қор ақпараты
            _buildSectionHeader('Баспа және қор параметрлері', Icons.inventory_2_rounded),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pagesController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      label: 'Бет саны *',
                      hint: '320',
                      icon: Icons.auto_stories_rounded,
                      isDark: isDark,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Бет саны';
                      if (int.tryParse(val.trim()) == null) return 'Сан болуы керек';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _publishYearController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      label: 'Шыққан жылы *',
                      hint: '2023',
                      icon: Icons.calendar_today_rounded,
                      isDark: isDark,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Жылы';
                      final year = int.tryParse(val.trim());
                      if (year == null || year < 1800 || year > 2030) {
                        return '1800-2030';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _isbnController,
                    decoration: _inputDecoration(
                      label: 'ISBN коды *',
                      hint: '978-601-03-0145-2',
                      icon: Icons.qr_code_rounded,
                      isDark: isDark,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'ISBN коды қажет';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _totalCopiesController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      label: 'Дана саны (Қор) *',
                      hint: '5',
                      icon: Icons.content_copy_rounded,
                      isDark: isDark,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Дана саны';
                      final count = int.tryParse(val.trim());
                      if (count == null || count < 0) return 'Дұрыс сан жазыңыз';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cover URL (optional)
            TextFormField(
              controller: _coverUrlController,
              decoration: _inputDecoration(
                label: 'Мұқаба суретінің URL (міндетті емес)',
                hint: 'https://images.unsplash.com/...',
                icon: Icons.image_rounded,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 24),

            // Section: Сандық және аудио мүмкіндіктер
            _buildSectionHeader('Сандық форматтар', Icons.devices_rounded),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Қорда қолжетімді (Available)'),
              subtitle: const Text('Оқырмандар кітапханадан алып кете алады'),
              value: _isAvailable,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _isAvailable = val),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('e-Book қолжетімді'),
              subtitle: const Text('Электронды кітап қосымша ішінде ашылады'),
              value: _hasEBook,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _hasEBook = val),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Аудио нұсқасы бар'),
              subtitle: const Text('Оқырман аудиоплеерден тыңдай алады'),
              value: _hasAudio,
              activeThumbColor: AppColors.primary,
              onChanged: (val) => setState(() => _hasAudio = val),
            ),

            if (_hasAudio) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _audioDurationController,
                decoration: _inputDecoration(
                  label: 'Аудио ұзақтығы',
                  hint: '2 сағ 15 мин',
                  icon: Icons.timer_rounded,
                  isDark: isDark,
                ),
              ),
            ],

            const SizedBox(height: 16),
            TextFormField(
              controller: _readingContentController,
              maxLines: 4,
              decoration: _inputDecoration(
                label: 'Электронды оқуға арналған мәтін үзіндісі',
                hint: 'Кітаптың 1-тарауы немесе бастапқы кіріспесі...',
                icon: Icons.article_rounded,
                isDark: isDark,
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _saveBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isEdit ? Icons.save_rounded : Icons.add_circle_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Өзгерістерді сақтау' : 'Кітапты қосу',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppColors.primaryLight),
      filled: true,
      fillColor: isDark ? AppColors.surfaceDark : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }
}

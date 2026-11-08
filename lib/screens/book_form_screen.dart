import 'package:flutter/material.dart';

import '../models/book_model.dart';
import '../utils/constants.dart';

class BookFormScreen extends StatefulWidget {
  final Book? book;
  final bool importing;
  final Future<bool> Function(Book) onSave;

  const BookFormScreen({
    super.key,
    this.book,
    this.importing = false,
    required this.onSave,
  });

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _ChapterEditor {
  final String id;
  final TextEditingController title;
  final TextEditingController text;
  _ChapterEditor(BookChapter chapter)
    : id = chapter.id,
      title = TextEditingController(text: chapter.title),
      text = TextEditingController(text: chapter.text);
  void dispose() {
    title.dispose();
    text.dispose();
  }
}

class _BookFormScreenState extends State<BookFormScreen> {
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _descriptionController;
  late TextEditingController _isbnController;
  late TextEditingController _pagesController;
  late TextEditingController _publishYearController;
  late TextEditingController _totalCopiesController;
  late TextEditingController _availableCopiesController;
  late TextEditingController _coverUrlController;
  late TextEditingController _audioDurationController;
  late TextEditingController _readingContentController;

  late TextEditingController _audioUrlController;
  final List<_ChapterEditor> _chapterEditors = [];
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

  final List<Map<String, String>> _presetCovers = [
    {
      'name': 'Классика',
      'url': 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=600&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Тарих',
      'url': 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=600&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Психология',
      'url': 'https://images.unsplash.com/photo-1589829085413-56de8ae18c73?w=600&auto=format&fit=crop&q=80',
    },
    {
      'name': 'IT / Техника',
      'url': 'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=600&auto=format&fit=crop&q=80',
    },
    {
      'name': 'Роман',
      'url': 'https://images.unsplash.com/photo-1532012164546-f432f2e3edd4?w=600&auto=format&fit=crop&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.book;

    _titleController = TextEditingController(text: b?.title ?? '');
    _authorController = TextEditingController(text: b?.author ?? '');
    _descriptionController = TextEditingController(text: b?.description ?? '');
    _isbnController = TextEditingController(text: b?.isbn ?? '');
    _pagesController = TextEditingController(
      text: (b?.pages ?? 250).toString(),
    );
    _publishYearController = TextEditingController(
      text: (b?.publishYear ?? DateTime.now().year).toString(),
    );
    _totalCopiesController = TextEditingController(
      text: (b?.totalCopies ?? 0).toString(),
    );
    _availableCopiesController = TextEditingController(
      text: (b?.availableCopies ?? 0).toString(),
    );
    _coverUrlController = TextEditingController(text: b?.coverUrl ?? '');
    _coverUrlController.addListener(_onCoverUrlChanged);
    _audioDurationController = TextEditingController(
      text: b?.audioDuration ?? '1 сағ 45 мин',
    );
    _readingContentController = TextEditingController(
      text: b?.readingContent ?? '',
    );

    _audioUrlController = TextEditingController(text: b?.audioUrl ?? '');
    _chapterEditors.addAll(
      (b?.chapters ?? <BookChapter>[]).map(_ChapterEditor.new),
    );
    final category = b?.category.trim();
    if (category != null &&
        category.isNotEmpty &&
        !_categories.contains(category)) {
      _categories.add(category);
    }
    _selectedCategory = category == null || category.isEmpty
        ? _categories.first
        : category;
    _hasEBook = b?.hasEBook ?? true;
    _hasAudio = b?.hasAudio ?? false;
    _isAvailable = widget.importing || (b?.isAvailable ?? true);
  }

  void _onCoverUrlChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _coverUrlController.removeListener(_onCoverUrlChanged);
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _isbnController.dispose();
    _pagesController.dispose();
    _publishYearController.dispose();
    _totalCopiesController.dispose();
    _availableCopiesController.dispose();
    _coverUrlController.dispose();
    _audioDurationController.dispose();
    _readingContentController.dispose();
    _audioUrlController.dispose();
    for (final editor in _chapterEditors) {
      editor.dispose();
    }
    super.dispose();
  }

  Future<void> _saveBook() async {
    if (_isSaving) return;
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
    final year =
        int.tryParse(_publishYearController.text.trim()) ?? DateTime.now().year;
    final totalCopies = int.tryParse(_totalCopiesController.text.trim()) ?? 3;
    final isEdit = widget.book != null && !widget.importing;

    final availableCopies = isEdit
        ? int.parse(_availableCopiesController.text.trim())
        : totalCopies;

    final resultBook = Book(
      id: widget.book?.id ?? 'book_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      category: _selectedCategory,
      rating: widget.book?.rating ?? 0,
      reviewCount: widget.book?.reviewCount ?? 0,
      pages: pages,
      publishYear: year,
      isbn: _isbnController.text.trim(),
      description: _descriptionController.text.trim(),
      coverGradient:
          widget.book?.coverGradient ??
          const [AppColors.primary, AppColors.primaryLight],
      coverUrl: _coverUrlController.text.trim().isNotEmpty
          ? _coverUrlController.text.trim()
          : widget.book?.coverUrl,
      previewUrl: widget.book?.previewUrl,
      infoUrl: widget.book?.infoUrl,
      source: widget.book?.source ?? 'LibFlow',
      isAvailable: _isAvailable && availableCopies > 0,
      availableCopies: availableCopies,
      totalCopies: totalCopies,
      hasEBook: _hasEBook,
      hasAudio: _hasAudio,
      audioDuration: _audioDurationController.text.trim(),
      readingContent: _readingContentController.text.trim(),
      chapters: _chapterEditors
          .map(
            (e) => BookChapter(
              id: e.id,
              title: e.title.text.trim(),
              text: e.text.text.trim(),
            ),
          )
          .toList(),
      audioUrl: _hasAudio && _audioUrlController.text.trim().isNotEmpty
          ? _audioUrlController.text.trim()
          : null,
      isFavorite: widget.book?.isFavorite ?? false,
      isReserved: widget.book?.isReserved ?? false,
      reservationTime: widget.book?.reservationTime,
      reservationCode: widget.book?.reservationCode,
      isBorrowed: widget.book?.isBorrowed ?? false,
      dueDate: widget.book?.dueDate,
    );

    setState(() => _isSaving = true);
    final saved = await widget.onSave(resultBook);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сақтау орындалмады. Сервер байланысын тексеріп, қайта көріңіз.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, resultBook);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
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
    final isEdit = widget.book != null && !widget.importing;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Кітапты өңдеу' : 'Жаңа кітап қосу',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Сақтау',
            onPressed: _isSaving ? null : _saveBook,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            if (_isSaving) const LinearProgressIndicator(),
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
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEdit
                          ? Icons.edit_note_rounded
                          : Icons.library_add_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit
                              ? 'Деректерді жаңарту'
                              : 'Каталогқа кітап енгізу',
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
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
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
              isExpanded: true,
              initialValue: _selectedCategory,
              decoration: _inputDecoration(
                label: 'Санаты (Жанры) *',
                hint: 'Санатты таңдаңыз',
                icon: Icons.category_rounded,
                isDark: isDark,
              ),
              dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
              items: _categories.map((c) {
                return DropdownMenuItem<String>(value: c, child: Text(c));
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
            _buildSectionHeader(
              'Баспа және қор параметрлері',
              Icons.inventory_2_rounded,
            ),
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
                      if (int.tryParse(val.trim()) == null) {
                        return 'Сан болуы керек';
                      }
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
                      if (year == null ||
                          year < 0 ||
                          year > DateTime.now().year + 1) {
                        return 'Жылды тексеріңіз';
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
                      label: 'ISBN',
                      hint: '978-601-03-0145-2',
                      icon: Icons.qr_code_rounded,
                      isDark: isDark,
                    ),
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
                      if (count == null || count < 0) {
                        return 'Дұрыс сан жазыңыз';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isEdit) ...[
              TextFormField(
                controller: _availableCopiesController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  label: 'Қолда бар дана саны',
                  hint: '0',
                  icon: Icons.inventory_outlined,
                  isDark: isDark,
                ),
                validator: (value) {
                  final copies = int.tryParse(value?.trim() ?? '');
                  final total = int.tryParse(
                    _totalCopiesController.text.trim(),
                  );
                  if (copies == null ||
                      copies < 0 ||
                      (total != null && copies > total)) {
                    return 'Қолда бар дана саны қор санынан аспауы керек';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            // Cover URL with Live Preview & Presets
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live Cover Preview Box
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 65,
                          height: 90,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: _coverUrlController.text.trim().isNotEmpty
                              ? Image.network(
                                  _coverUrlController.text.trim(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image_rounded,
                                            size: 24,
                                            color: AppColors.error,
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Қате URL',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 26,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Сурет жоқ',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Text input & Clear button
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Кітап мұқабасының суреті',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _coverUrlController,
                              style: const TextStyle(fontSize: 13),
                              decoration:
                                  _inputDecoration(
                                    label: 'Сурет URL сілтемесі',
                                    hint: 'https://...',
                                    icon: Icons.link_rounded,
                                    isDark: isDark,
                                  ).copyWith(
                                    suffixIcon:
                                        _coverUrlController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              _coverUrlController.clear();
                                            },
                                          )
                                        : null,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text(
                    'Дайын сапалы мұқаба үлгілері (таңдау үшін басыңыз):',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _presetCovers.map((preset) {
                        final isSelected =
                            _coverUrlController.text.trim() == preset['url'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(preset['name']!),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _coverUrlController.text = preset['url']!;
                                } else {
                                  _coverUrlController.clear();
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
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
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) => setState(() => _isAvailable = val),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('e-Book қолжетімді'),
              subtitle: const Text('Электронды кітап қосымша ішінде ашылады'),
              value: _hasEBook,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) => setState(() => _hasEBook = val),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Аудио нұсқасы бар'),
              subtitle: const Text('Оқырман аудиоплеерден тыңдай алады'),
              value: _hasAudio,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) => setState(() => _hasAudio = val),
            ),

            if (_hasAudio) ...[
              TextFormField(
                controller: _audioUrlController,
                decoration: const InputDecoration(
                  labelText: 'MP3 сілтемесі (HTTPS)',
                ),
                validator: (value) {
                  if (!_hasAudio) return null;
                  final source = value?.trim() ?? '';
                  if (source == 'asset:assets/audio/aesop_fox_grapes.mp3') {
                    return null;
                  }
                  final uri = Uri.tryParse(source);
                  return uri != null &&
                          uri.scheme == 'https' &&
                          uri.host.isNotEmpty &&
                          uri.userInfo.isEmpty
                      ? null
                      : 'Қолжетімді HTTPS аудио сілтемесін енгізіңіз';
                },
              ),
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
                label: 'Кітап мәтіні (тараулар болмаса қолданылады)',
                hint: 'Кітаптың 1-тарауы немесе бастапқы кіріспесі...',
                icon: Icons.article_rounded,
                isDark: isDark,
              ),
            ),

            for (final editor in _chapterEditors)
              Card(
                key: ValueKey(editor.id),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: editor.title,
                        decoration: const InputDecoration(
                          labelText: 'Тарау атауы',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Тарау атауын енгізіңіз'
                            : null,
                      ),
                      TextFormField(
                        controller: editor.text,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Тарау мәтіні',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Тарау мәтінін енгізіңіз'
                            : null,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Тарауды жою'),
                        onPressed: () {
                          setState(() => _chapterEditors.remove(editor));
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => editor.dispose(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Тарау қосу'),
              onPressed: () => setState(() {
                if (_chapterEditors.isEmpty &&
                    _readingContentController.text.trim().isNotEmpty) {
                  _chapterEditors.add(
                    _ChapterEditor(
                      BookChapter(
                        id: 'legacy',
                        title: '1-тарау',
                        text: _readingContentController.text.trim(),
                      ),
                    ),
                  );
                  _readingContentController.clear();
                }
                _chapterEditors.add(
                  _ChapterEditor(
                    BookChapter(
                      id: 'chapter_${DateTime.now().microsecondsSinceEpoch}',
                      title: '',
                      text: '',
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveBook,
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
                  Icon(
                    isEdit ? Icons.save_rounded : Icons.add_circle_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Өзгерістерді сақтау' : 'Кітапты қосу',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
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
      prefixIcon: Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
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
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
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

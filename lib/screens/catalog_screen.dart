import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../services/books_api_service.dart';
import '../utils/constants.dart';
import 'book_detail_screen.dart';
import 'book_form_screen.dart';

enum CatalogSource { all, openLibrary, googleBooks, localOnly }

class CatalogScreen extends StatefulWidget {
  final List<Book> books;
  final Function(Book) onBookUpdated;
  final Function(Book)? onBookAdded;

  const CatalogScreen({
    super.key,
    required this.books,
    required this.onBookUpdated,
    this.onBookAdded,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Барлығы';
  bool _onlyAvailable = false;
  bool _onlyAudio = false;
  bool _onlyEBook = false;

  CatalogSource _selectedSource = CatalogSource.all;
  bool _isLoadingApi = false;
  String? _apiErrorMessage;
  List<Book> _apiSearchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Trigger online API search for Google Books & Open Library
  Future<void> _performOnlineSearch([String? overrideQuery]) async {
    final query = (overrideQuery ?? _searchController.text).trim();
    if (query.isEmpty) {
      setState(() {
        _apiSearchResults = [];
        _apiErrorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoadingApi = true;
      _apiErrorMessage = null;
    });

    try {
      List<Book> results = [];
      switch (_selectedSource) {
        case CatalogSource.openLibrary:
          results = await BooksApiService.searchOpenLibrary(query, limit: 20);
          break;
        case CatalogSource.googleBooks:
          results = await BooksApiService.searchGoogleBooks(query, maxResults: 20);
          break;
        case CatalogSource.all:
          results = await BooksApiService.searchCombined(query, limit: 25);
          break;
        case CatalogSource.localOnly:
          results = [];
          break;
      }

      if (mounted) {
        setState(() {
          _apiSearchResults = results;
          _isLoadingApi = false;
          if (results.isEmpty && _selectedSource != CatalogSource.localOnly) {
            _apiErrorMessage =
                'Онлайн базадан сәйкес кітап табылмады немесе желі шектеулі.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingApi = false;
          _apiErrorMessage = 'Іздеу кезінде қате орын алды: $e';
        });
      }
    }
  }

  List<Book> get _currentDisplayList {
    final query = _searchController.text.trim().toLowerCase();

    // If local only selected
    if (_selectedSource == CatalogSource.localOnly) {
      return widget.books.where((book) {
        final matchesQuery = query.isEmpty ||
            book.title.toLowerCase().contains(query) ||
            book.author.toLowerCase().contains(query) ||
            book.isbn.toLowerCase().contains(query);

        final matchesCategory = _selectedCategory == 'Барлығы' ||
            book.category == _selectedCategory;

        final matchesAvailable = !_onlyAvailable || book.isAvailable;
        final matchesAudio = !_onlyAudio || book.hasAudio;
        final matchesEBook = !_onlyEBook || book.hasEBook;

        return matchesQuery &&
            matchesCategory &&
            matchesAvailable &&
            matchesAudio &&
            matchesEBook;
      }).toList();
    }

    // If API search has results or user is in OpenLibrary / GoogleBooks mode
    if (_apiSearchResults.isNotEmpty) {
      return _apiSearchResults;
    }

    // Default: local books filtered
    return widget.books.where((book) {
      final matchesQuery = query.isEmpty ||
          book.title.toLowerCase().contains(query) ||
          book.author.toLowerCase().contains(query) ||
          book.isbn.toLowerCase().contains(query);

      final matchesCategory = _selectedCategory == 'Барлығы' ||
          book.category == _selectedCategory;

      final matchesAvailable = !_onlyAvailable || book.isAvailable;
      final matchesAudio = !_onlyAudio || book.hasAudio;
      final matchesEBook = !_onlyEBook || book.hasEBook;

      return matchesQuery &&
          matchesCategory &&
          matchesAvailable &&
          matchesAudio &&
          matchesEBook;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final results = _currentDisplayList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Кітаптар каталогы',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Жаңа кітап қосу',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookFormScreen(
                    onSave: (newBook) {
                      if (widget.onBookAdded != null) {
                        widget.onBookAdded!(newBook);
                      } else {
                        widget.onBookUpdated(newBook);
                      }
                      setState(() {});
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync_rounded),
            tooltip: 'API деректерін жаңарту',
            onPressed: () => _performOnlineSearch(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Bar with Online Search Action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (val) => _performOnlineSearch(val),
                    decoration: InputDecoration(
                      hintText: 'Атауы, авторы, ISBN немесе тақырыбы...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.primaryLight),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _apiSearchResults = [];
                                  _apiErrorMessage = null;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor:
                          isDark ? AppColors.surfaceDark : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Search button
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    icon: _isLoadingApi
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white),
                    tooltip: 'Іздеу (API + Қор)',
                    onPressed: _isLoadingApi
                        ? null
                        : () => _performOnlineSearch(),
                  ),
                ),
              ],
            ),
          ),

          // API Source Selector Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSourceChip(
                    label: 'Барлығы (API + Қор)',
                    source: CatalogSource.all,
                    icon: Icons.hub_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildSourceChip(
                    label: 'Open Library API',
                    source: CatalogSource.openLibrary,
                    icon: Icons.public_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildSourceChip(
                    label: 'Google Books API',
                    source: CatalogSource.googleBooks,
                    icon: Icons.auto_stories_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildSourceChip(
                    label: 'LibFlow қоры',
                    source: CatalogSource.localOnly,
                    icon: Icons.account_balance_rounded,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          // Categories horizontal scroll matching Figma (Барлығы, Роман, Тарих, Басқа)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                'Барлығы',
                'Роман',
                'Тарих',
                'Басқа',
              ].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                      });
                      if (cat != 'Барлығы' && _selectedSource != CatalogSource.localOnly) {
                        _performOnlineSearch(cat);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.surfaceDark : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Filter toggles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    avatar: Icon(Icons.check_circle_outline,
                        size: 16,
                        color: _onlyAvailable ? Colors.white : Colors.green),
                    label: const Text('Тек қолда барлар',
                        style: TextStyle(fontSize: 11)),
                    selected: _onlyAvailable,
                    onSelected: (val) => setState(() => _onlyAvailable = val),
                    selectedColor: AppColors.success,
                    labelStyle: TextStyle(
                      color: _onlyAvailable ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: Icon(Icons.headphones,
                        size: 16,
                        color: _onlyAudio ? Colors.white : Colors.amber),
                    label: const Text('Аудиокітап',
                        style: TextStyle(fontSize: 11)),
                    selected: _onlyAudio,
                    onSelected: (val) => setState(() => _onlyAudio = val),
                    selectedColor: Colors.amber[800],
                    labelStyle: TextStyle(
                      color: _onlyAudio ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: Icon(Icons.menu_book,
                        size: 16,
                        color: _onlyEBook ? Colors.white : Colors.blue),
                    label: const Text('Электронды',
                        style: TextStyle(fontSize: 11)),
                    selected: _onlyEBook,
                    onSelected: (val) => setState(() => _onlyEBook = val),
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      color: _onlyEBook ? Colors.white : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 10),

          // Results header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Табылған кітаптар: ${results.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    if (_apiSearchResults.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.info.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Live API нәтижелері',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_apiSearchResults.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _apiSearchResults = [];
                        _searchController.clear();
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                    ),
                    child: const Text('Тазарту', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),

          // Error banner if any
          if (_apiErrorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _apiErrorMessage!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Figma 07: "Танымал кітаптар" Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Танымал кітаптар',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${results.length} кітап',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),

          // List View matching Figma Screen 07
          Expanded(
            child: _isLoadingApi
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Google Books және Open Library базаларынан ізделуде...',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 72,
                              color:
                                  isDark ? Colors.white24 : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Кітап табылмады',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final book = results[index];
                          return GestureDetector(
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
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Mini Book Cover with circle
                                  Container(
                                    width: 50,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: book.coverGradient),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFFD4A373), width: 2),
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
                                          book.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          book.author,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD4A373)),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${book.rating}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '•  ${book.category}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: isDark ? Colors.white38 : Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Кітап қосу', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookFormScreen(
                onSave: (newBook) {
                  if (widget.onBookAdded != null) {
                    widget.onBookAdded!(newBook);
                  } else {
                    widget.onBookUpdated(newBook);
                  }
                  setState(() {});
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSourceChip({
    required String label,
    required CatalogSource source,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedSource == source;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : AppColors.primary),
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedSource = source;
          });
          if (_searchController.text.trim().isNotEmpty) {
            _performOnlineSearch();
          }
        }
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
    );
  }
}

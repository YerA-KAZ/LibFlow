import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';

import '../models/book_model.dart';
import 'dummy_books.dart';

/// Сұрыптау критерийлері (Sorting Options)
enum BookSortOption {
  titleAsc, // Атауы бойынша (А-Я / A-Z)
  titleDesc, // Атауы бойынша (Я-А / Z-A)
  ratingDesc, // Рейтингі бойынша (Ең жоғарыдан төменге)
  yearDesc, // Шыққан жылы бойынша (Жаңа кітаптар алдымен)
  yearAsc, // Шыққан жылы бойынша (Ескі кітаптар алдымен)
  pagesAsc, // Бет саны бойынша (Аз беттілер алдымен)
}

/// JSON файлындағы тұрақты офлайн кэш және жергілікті оқырман деректері.
/// Сервермен синхрондауды LibraryRepository орындайды.
class LibraryDatabaseService {
  static final LibraryDatabaseService _instance =
      LibraryDatabaseService._internal();
  factory LibraryDatabaseService() => _instance;
  LibraryDatabaseService._internal();

  static const String _dbFileName = 'libflow_offline_database.json';
  bool _isInitialized = false;
  // Tests can opt into an isolated directory without platform plugins.
  static String? storageDirectoryOverride;

  // Локалды жадтағы кестелер (Tables)
  final List<Book> _booksTable = [];
  final List<Author> _authorsTable = [];
  final List<BookCategory> _categoriesTable = [];
  final List<Reader> _readersTable = [];
  final List<Loan> _loansTable = [];
  final List<BookReview> _reviewsTable = [];

  // Getters for in-memory tables
  List<Book> get books => List.unmodifiable(_booksTable);
  List<Author> get authors => List.unmodifiable(_authorsTable);
  List<BookCategory> get categories => List.unmodifiable(_categoriesTable);
  List<Reader> get readers => List.unmodifiable(_readersTable);
  List<Loan> get loans => List.unmodifiable(_loansTable);
  List<BookReview> get reviews => List.unmodifiable(_reviewsTable);

  /// Деректер қорын инициализациялау (Database Initialization)
  Future<void> initializeDatabase() async {
    if (_isInitialized) return;
    var hasStoredBooks = false;

    try {
      final file = await _getDatabaseFile();
      // Preserve the previous desktop cache when moving to app support storage.
      if (storageDirectoryOverride == null &&
          !Platform.isAndroid && !Platform.isIOS && !await file.exists()) {
        final legacy = File('${Directory.current.path}/$_dbFileName');
        if (await legacy.exists()) await legacy.copy(file.path);
      }
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(content);

          // 1. Books table
          if (data['books'] != null) {
            hasStoredBooks = true;
            _booksTable.clear();
            for (var item in data['books']) {
              _booksTable.add(Book.fromMap(Map<String, dynamic>.from(item)));
            }
          }

          // 2. Authors table
          if (data['authors'] != null) {
            _authorsTable.clear();
            for (var item in data['authors']) {
              _authorsTable.add(
                Author.fromMap(Map<String, dynamic>.from(item)),
              );
            }
          }

          // 3. Categories table
          if (data['categories'] != null) {
            _categoriesTable.clear();
            for (var item in data['categories']) {
              _categoriesTable.add(
                BookCategory.fromMap(Map<String, dynamic>.from(item)),
              );
            }
          }

          // 4. Readers table
          if (data['readers'] != null) {
            _readersTable.clear();
            for (var item in data['readers']) {
              _readersTable.add(
                Reader.fromMap(Map<String, dynamic>.from(item)),
              );
            }
          }

          // 5. Loans table
          if (data['loans'] != null) {
            _loansTable.clear();
            for (var item in data['loans']) {
              _loansTable.add(Loan.fromMap(Map<String, dynamic>.from(item)));
            }
          }

          // 6. Reviews table
          if (data['reviews'] != null) {
            _reviewsTable.clear();
            for (var item in data['reviews']) {
              _reviewsTable.add(
                BookReview.fromMap(Map<String, dynamic>.from(item)),
              );
            }
          }

          debugPrint(
            'LibraryDatabaseService: Деректер қоры локалды файлдан сәтті оқылды. Кітаптар саны: ${_booksTable.length}',
          );
        }
      }

      // Егер деректер қоры бос болса, бастапқы демонстрациялық мәндермен толтыру (Seed Database)
      if (_booksTable.isEmpty && !hasStoredBooks) {
        await _seedInitialData();
      }

      _isInitialized = true;
    } catch (e, stack) {
      debugPrint(
        'Қате: Деректер қорын инициализациялау кезінде ақау шықты: $e\n$stack',
      );
      // Қате болған жағдайда да қосымша жұмысын тоқтатпауы үшін бастапқы мәндермен жүктеу
      if (_booksTable.isEmpty) {
        _booksTable.addAll(DummyDataService.getInitialBooks());
      }
      _isInitialized = true;
    }
  }

  /// Локалды файлға барлық кестелерді тұрақты сақтау (Persist to Local Storage)
  Future<void> _persistDatabase() async {
    try {
      final file = await _getDatabaseFile();
      final data = {
        'version': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'books': _booksTable.map((b) => b.toMap()).toList(),
        'authors': _authorsTable.map((a) => a.toMap()).toList(),
        'categories': _categoriesTable.map((c) => c.toMap()).toList(),
        'readers': _readersTable.map((r) => r.toMap()).toList(),
        'loans': _loansTable.map((l) => l.toMap()).toList(),
        'reviews': _reviewsTable.map((rw) => rw.toMap()).toList(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Қате: Деректер қорын сақтау кезінде ақау шықты: $e');
    }
  }

  /// Базалық деректерді инициализациялау (Database Seeding)
  Future<void> _seedInitialData() async {
    _booksTable.clear();
    _booksTable.addAll(DummyDataService.getInitialBooks());

    _categoriesTable.addAll([
      BookCategory(
        id: 'cat_1',
        name: 'Көркем әдебиет',
        description: 'Классикалық романдар мен әңгімелер',
        iconName: 'auto_stories',
        bookCount: 12,
      ),
      BookCategory(
        id: 'cat_2',
        name: 'Тарих',
        description: 'Тарихи шежіре, хроника және зерттеулер',
        iconName: 'history_edu',
        bookCount: 8,
      ),
      BookCategory(
        id: 'cat_3',
        name: 'Классика',
        description: 'Ұлттық және әлемдік классика',
        iconName: 'menu_book',
        bookCount: 15,
      ),
      BookCategory(
        id: 'cat_4',
        name: 'Психология',
        description: 'Тұлғалық даму, әдеттер мен мотивация',
        iconName: 'psychology',
        bookCount: 6,
      ),
      BookCategory(
        id: 'cat_5',
        name: 'IT және Техника',
        description: 'Бағдарламалау, жасанды интеллект, инженерия',
        iconName: 'computer',
        bookCount: 9,
      ),
      BookCategory(
        id: 'cat_6',
        name: 'Роман',
        description: 'Драма, романтикалық және қоғамдық туындылар',
        iconName: 'local_library',
        bookCount: 11,
      ),
    ]);

    _authorsTable.addAll([
      Author(
        id: 'auth_1',
        fullName: 'Мұхтар Әуезов',
        biography: 'Ұлы қазақ жазушысы, қоғам қайраткері, филология ғылымының докторы.',
        birthYear: 1897,
        country: 'Қазақстан',
        booksCount: 4,
      ),
      Author(
        id: 'auth_2',
        fullName: 'Ілияс Есенберлин',
        biography: 'Қазақ тарихи романының негізін қалаушы, атақты трилогиялар авторы.',
        birthYear: 1915,
        country: 'Қазақстан',
        booksCount: 3,
      ),
      Author(
        id: 'auth_3',
        fullName: 'Әбдіжәміл Нұрпейісов',
        biography: 'Қазақстанның Халық жазушысы, Арал тақырыбын шебер суреттеген классик.',
        birthYear: 1924,
        country: 'Қазақстан',
        booksCount: 2,
      ),
      Author(
        id: 'auth_4',
        fullName: 'Джеймс Клир',
        biography: 'Әдеттер, шешім қабылдау және үздіксіз өзін-өзі дамыту бойынша әлемдік сарапшы.',
        birthYear: 1986,
        country: 'АҚШ',
        booksCount: 1,
      ),
    ]);

    _readersTable.add(
      Reader(
        id: 'user_ernur',
        ticketNumber: 'LIB-77492',
        fullName: 'Ернұр Асқаров',
        email: 'ernur.askar@gmail.com',
        phone: '+7 701 555 44 33',
        registeredAt: DateTime.now().subtract(const Duration(days: 45)),
        isActive: true,
      ),
    );

    // Initial borrowed / reserved loan
    _loansTable.add(
      Loan(
        id: 'loan_1',
        bookId: '1',
        readerId: 'user_ernur',
        bookTitle: 'Абай жолы (1-том)',
        readerName: 'Ернұр Асқаров',
        borrowDate: DateTime.now().subtract(const Duration(days: 4)),
        dueDate: DateTime.now().add(const Duration(days: 3)),
        status: 'active',
        qrCode: 'LIBFLOW-LOAN-001',
      ),
    );

    await _persistDatabase();
  }

  // ==========================================
  // 1. CREATE ОПЕРАЦИЯЛАРЫ (Insert)
  // ==========================================

  /// Жаңа кітап қосу (Insert Book)
  Future<bool> insertBook(Book book) async {
    try {
      // Идентификатор бірегейлігін тексеру
      final existingIndex = _booksTable.indexWhere((b) => b.id == book.id);
      if (existingIndex != -1) {
        _booksTable[existingIndex] = book;
      } else {
        _booksTable.insert(0, book);
      }
      await _persistDatabase();
      return true;
    } catch (e) {
      debugPrint('Қате: Кітап қосу кезінде ақау: $e');
      return false;
    }
  }

  /// Жаңа пікір қосу (Insert Review)
  Future<bool> addReview(BookReview review) async {
    try {
      _reviewsTable.insert(0, review);
      await _persistDatabase();
      return true;
    } catch (e) {
      debugPrint('Қате: Пікір қосу кезінде ақау: $e');
      return false;
    }
  }

  /// Кітапты брондау немесе алу транзакциясын құру (Create Loan)
  Future<bool> createLoan(Loan loan) async {
    try {
      _loansTable.insert(0, loan);
      await _persistDatabase();
      return true;
    } catch (e) {
      debugPrint('Қате: Кітап алу транзакциясын құру кезінде ақау: $e');
      return false;
    }
  }

  // ==========================================
  // 2. READ ОПЕРАЦИЯЛАРЫ (Select / Query)
  // ==========================================

  /// Барлық кітаптар тізімін алу
  List<Book> getAllBooks() {
    return List.from(_booksTable);
  }

  /// Replace the server catalogue, including removals; keep other local tables.
  Future<void> replaceBooks(List<Book> books) async {
    _booksTable
      ..clear()
      ..addAll(books);
    await _persistDatabase();
  }

  /// ID бойынша кітапты табу
  Book? getBookById(String id) {
    try {
      return _booksTable.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Таңдаулы кітаптарды алу (Favorites)
  List<Book> getFavoriteBooks() {
    return _booksTable.where((b) => b.isFavorite).toList();
  }

  /// Қолда бар (алынған) кітаптарды алу
  List<Book> getBorrowedBooks() {
    return _booksTable.where((b) => b.isBorrowed).toList();
  }

  /// Брондалған кітаптарды алу
  List<Book> getReservedBooks() {
    return _booksTable.where((b) => b.isReserved).toList();
  }

  // ==========================================
  // 3. UPDATE ОПЕРАЦИЯЛАРЫ (Update)
  // ==========================================

  /// Бар кітап жазбасын жаңарту
  Future<bool> updateBook(Book updatedBook) async {
    try {
      final index = _booksTable.indexWhere((b) => b.id == updatedBook.id);
      if (index != -1) {
        _booksTable[index] = updatedBook;
        await _persistDatabase();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Қате: Кітап жаңарту кезінде ақау: $e');
      return false;
    }
  }

  /// Таңдаулы күйін ауыстыру (Toggle Favorite)
  Future<Book?> toggleFavorite(String bookId) async {
    try {
      final index = _booksTable.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        final current = _booksTable[index];
        final updated = current.copyWith(isFavorite: !current.isFavorite);
        _booksTable[index] = updated;
        await _persistDatabase();
        return updated;
      }
      return null;
    } catch (e) {
      debugPrint('Қате: Таңдаулы күйін өзгерту кезінде ақау: $e');
      return null;
    }
  }

  // ==========================================
  // 4. DELETE ОПЕРАЦИЯЛАРЫ (Delete)
  // ==========================================

  /// Кітапты өшіру (Delete Book by ID)
  Future<bool> deleteBook(String bookId) async {
    try {
      final index = _booksTable.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        _booksTable.removeAt(index);
        await _persistDatabase();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Қате: Кітап өшіру кезінде ақау: $e');
      return false;
    }
  }

  // ==========================================
  // 5. ІЗДЕУ (Search), СҮЗГІЛЕУ (Filter), СҰРЫПТАУ (Sort)
  // ==========================================

  /// Атауы, авторы, ISBN немесе сипаттамасы бойынша іздеу
  List<Book> searchBooks(String query, {List<Book>? sourceList}) {
    final list = sourceList ?? _booksTable;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.from(list);

    return list.where((b) {
      final inTitle = b.title.toLowerCase().contains(q);
      final inAuthor = b.author.toLowerCase().contains(q);
      final inIsbn = b.isbn.toLowerCase().contains(q);
      final inCategory = b.category.toLowerCase().contains(q);
      final inDesc = b.description.toLowerCase().contains(q);
      return inTitle || inAuthor || inIsbn || inCategory || inDesc;
    }).toList();
  }

  /// Критерийлер бойынша сүзгілеу (Filter)
  List<Book> filterBooks({
    List<Book>? sourceList,
    String? category,
    bool? onlyAvailable,
    bool? onlyAudio,
    bool? onlyEBook,
  }) {
    var result = List<Book>.from(sourceList ?? _booksTable);

    if (category != null && category != 'Барлығы') {
      result = result.where((b) => b.category == category).toList();
    }

    if (onlyAvailable == true) {
      result = result.where((b) => b.isAvailable).toList();
    }

    if (onlyAudio == true) {
      result = result.where((b) => b.hasAudio).toList();
    }

    if (onlyEBook == true) {
      result = result.where((b) => b.hasEBook).toList();
    }

    return result;
  }

  /// Деректерді кемінде екі параметр бойынша сұрыптау (Sorting)
  List<Book> sortBooks(List<Book> list, BookSortOption sortOption) {
    final sortedList = List<Book>.from(list);

    switch (sortOption) {
      case BookSortOption.titleAsc:
        // Атауы бойынша: А-дан Я-ға дейін
        sortedList.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;

      case BookSortOption.titleDesc:
        // Атауы бойынша: Я-дан А-ға дейін
        sortedList.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;

      case BookSortOption.ratingDesc:
        // Рейтингі бойынша: Ең жоғары бағаланғандар
        sortedList.sort((a, b) => b.rating.compareTo(a.rating));
        break;

      case BookSortOption.yearDesc:
        // Шыққан жылы бойынша: Жаңа кітаптар
        sortedList.sort((a, b) => b.publishYear.compareTo(a.publishYear));
        break;

      case BookSortOption.yearAsc:
        // Шыққан жылы бойынша: Ескі кітаптар
        sortedList.sort((a, b) => a.publishYear.compareTo(b.publishYear));
        break;

      case BookSortOption.pagesAsc:
        // Бет саны бойынша
        sortedList.sort((a, b) => a.pages.compareTo(b.pages));
        break;
    }

    return sortedList;
  }

  /// Жүйелік файл жолын анықтау
  Future<File> _getDatabaseFile() async {
    // Жобаның жергілікті директориясында немесе қолданба деректерінде сақтау
    final currentDir =
        storageDirectoryOverride ??
        (await getApplicationSupportDirectory()).path;
    await Directory(currentDir).create(recursive: true);
    final filePath = '$currentDir/$_dbFileName';
    return File(filePath);
  }
}

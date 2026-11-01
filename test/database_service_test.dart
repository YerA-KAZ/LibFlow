import 'package:flutter_test/flutter_test.dart';
import 'package:libflow/models/book_model.dart';
import 'package:libflow/services/library_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Практикалық жұмыс №4: Entity/Model және DatabaseService тесттері', () {
    late LibraryDatabaseService dbService;

    setUp(() async {
      dbService = LibraryDatabaseService();
      await dbService.initializeDatabase();
    });

    test('1. 5-тен астам Entity/Model дұрыс инициализацияланады және toMap/fromMap жұмыс істейді', () {
      // 1. Author
      final author = Author(
        id: 'auth_test',
        fullName: 'Ахмет Байтұрсынұлы',
        biography: 'Қазақ ақыны, тіл білімінің атасы.',
        birthYear: 1872,
        country: 'Қазақстан',
        booksCount: 5,
      );
      final authorMap = author.toMap();
      final restoredAuthor = Author.fromMap(authorMap);
      expect(restoredAuthor.fullName, 'Ахмет Байтұрсынұлы');

      // 2. Category
      final category = Category(
        id: 'cat_test',
        name: 'Ғылыми әдебиет',
        description: 'Оқулықтар мен монографиялар',
        bookCount: 10,
      );
      final catMap = category.toMap();
      final restoredCat = Category.fromMap(catMap);
      expect(restoredCat.name, 'Ғылыми әдебиет');

      // 3. Reader
      final reader = Reader(
        id: 'reader_1',
        ticketNumber: 'LIB-9911',
        fullName: 'Әлішер Қасымов',
        email: 'alisher@test.kz',
        phone: '+7 777 000 11 22',
        registeredAt: DateTime(2026, 1, 1),
      );
      final readerMap = reader.toMap();
      final restoredReader = Reader.fromMap(readerMap);
      expect(restoredReader.fullName, 'Әлішер Қасымов');

      // 4. Loan
      final loan = Loan(
        id: 'loan_test_1',
        bookId: 'book_101',
        readerId: 'reader_1',
        bookTitle: 'Маса',
        readerName: 'Әлішер Қасымов',
        borrowDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 14)),
        qrCode: 'TEST-QR-9911',
      );
      final loanMap = loan.toMap();
      final restoredLoan = Loan.fromMap(loanMap);
      expect(restoredLoan.qrCode, 'TEST-QR-9911');

      // 5. BookReview
      final review = BookReview(
        id: 'rev_1',
        bookId: 'book_101',
        userName: 'Айгүл',
        rating: 5.0,
        date: '2026-10-31',
        comment: 'Тамаша кітап!',
      );
      final revMap = review.toMap();
      final restoredRev = BookReview.fromMap(revMap);
      expect(restoredRev.comment, 'Тамаша кітап!');
    });

    test('2. CRUD: Create - Жаңа кітап сәтті қосылады', () async {
      final newBook = Book(
        id: 'test_book_999',
        title: 'Қара сөздер',
        author: 'Абай Құнанбайұлы',
        category: 'Философия',
        rating: 5.0,
        reviewCount: 50,
        pages: 180,
        publishYear: 1898,
        isbn: '978-601-99-9999-9',
        description: 'Абайдың қарасөздері — қазақ руханиятының шыңы.',
        coverGradient: const [],
        isAvailable: true,
        availableCopies: 10,
        totalCopies: 10,
        readingContent: 'Бірінші сөз...',
      );

      final result = await dbService.insertBook(newBook);
      expect(result, isTrue);

      final fetched = dbService.getBookById('test_book_999');
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Қара сөздер');
    });

    test('3. CRUD: Read - Кітаптар оқылады және іздеу жүйесі жұмыс істейді', () {
      final books = dbService.getAllBooks();
      expect(books.isNotEmpty, isTrue);

      // Search by title or author
      final searchResults = dbService.searchBooks('Абай');
      expect(searchResults.any((b) => b.title.contains('Абай') || b.author.contains('Абай')), isTrue);
    });

    test('4. CRUD: Update - Бар кітаптың мәліметтері мен Favorites жаңартылады', () async {
      final existing = dbService.getAllBooks().first;
      final updated = existing.copyWith(
        title: '${existing.title} (Жаңартылған басылым)',
        isFavorite: true,
      );

      final updateRes = await dbService.updateBook(updated);
      expect(updateRes, isTrue);

      final fetched = dbService.getBookById(existing.id);
      expect(fetched!.title.contains('Жаңартылған басылым'), isTrue);
      expect(fetched.isFavorite, isTrue);
    });

    test('5. CRUD: Delete - Кітап сәтті өшіріледі', () async {
      const deleteId = 'test_book_999';
      final deleteRes = await dbService.deleteBook(deleteId);
      expect(deleteRes, isTrue);

      final fetched = dbService.getBookById(deleteId);
      expect(fetched, isNull);
    });

    test('6. Сұрыптау: Кемінде 3 түрлі параметр бойынша сұрыптау тексерісі', () {
      final list = dbService.getAllBooks();
      expect(list.length, greaterThanOrEqualTo(2));

      // 1) Атауы бойынша (titleAsc)
      final sortedByTitle = dbService.sortBooks(list, BookSortOption.titleAsc);
      for (int i = 0; i < sortedByTitle.length - 1; i++) {
        expect(
          sortedByTitle[i].title.toLowerCase().compareTo(sortedByTitle[i + 1].title.toLowerCase()) <= 0,
          isTrue,
        );
      }

      // 2) Рейтинг бойынша (ratingDesc)
      final sortedByRating = dbService.sortBooks(list, BookSortOption.ratingDesc);
      for (int i = 0; i < sortedByRating.length - 1; i++) {
        expect(sortedByRating[i].rating >= sortedByRating[i + 1].rating, isTrue);
      }

      // 3) Шыққан жылы бойынша (yearDesc)
      final sortedByYear = dbService.sortBooks(list, BookSortOption.yearDesc);
      for (int i = 0; i < sortedByYear.length - 1; i++) {
        expect(sortedByYear[i].publishYear >= sortedByYear[i + 1].publishYear, isTrue);
      }
    });

    test('7. Сүзгілеу: Категория және қолжетімділік бойынша сүзгілеу тексерісі', () {
      final filtered = dbService.filterBooks(onlyAvailable: true);
      for (var b in filtered) {
        expect(b.isAvailable, isTrue);
      }
    });
  });
}


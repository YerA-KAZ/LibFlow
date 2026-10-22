import 'package:flutter_test/flutter_test.dart';
import 'package:libflow/models/book_model.dart';
import 'package:libflow/services/books_api_service.dart';

void main() {
  group('Books API Integration Tests', () {
    test('Book.fromGoogleBooks parses JSON volume correctly', () {
      final googleJson = {
        'id': 'test_gb_123',
        'volumeInfo': {
          'title': 'Flutter in Action',
          'authors': ['Eric Windmill'],
          'categories': ['Computers'],
          'pageCount': 350,
          'publishedDate': '2020-01-15',
          'averageRating': 4.7,
          'ratingsCount': 85,
          'description': 'A guide to building mobile apps with Flutter.',
          'industryIdentifiers': [
            {'type': 'ISBN_13', 'identifier': '9781617296147'}
          ],
          'imageLinks': {
            'thumbnail': 'http://books.google.com/thumbnail.jpg',
          },
          'previewLink': 'https://books.google.com/preview',
          'infoLink': 'https://books.google.com/info',
        }
      };

      final book = Book.fromGoogleBooks(googleJson);
      expect(book.title, 'Flutter in Action');
      expect(book.author, 'Eric Windmill');
      expect(book.category, 'Computers');
      expect(book.pages, 350);
      expect(book.publishYear, 2020);
      expect(book.isbn, '9781617296147');
      expect(book.source, 'Google Books');
      expect(book.coverUrl, 'https://books.google.com/thumbnail.jpg');
    });

    test('Book.fromOpenLibrary parses JSON doc correctly', () {
      final openLibJson = {
        'key': '/works/OL123456W',
        'title': 'Clean Architecture',
        'author_name': ['Robert C. Martin'],
        'subject': ['Software Architecture', 'Programming'],
        'first_publish_year': 2017,
        'number_of_pages_median': 432,
        'cover_i': 8234125,
        'isbn': ['9780134494166'],
        'ratings_average': 4.8,
        'edition_count': 15,
      };

      final book = Book.fromOpenLibrary(openLibJson);
      expect(book.title, 'Clean Architecture');
      expect(book.author, 'Robert C. Martin');
      expect(book.publishYear, 2017);
      expect(book.pages, 432);
      expect(book.isbn, '9780134494166');
      expect(book.source, 'Open Library');
      expect(book.coverUrl, 'https://covers.openlibrary.org/b/id/8234125-M.jpg');
    });

    test('BooksApiService URL and configuration', () {
      expect(BooksApiService.googleBooksBaseUrl,
          'https://www.googleapis.com/books/v1/volumes');
      expect(BooksApiService.openLibraryBaseUrl,
          'https://openlibrary.org/search.json');
    });
  });
}

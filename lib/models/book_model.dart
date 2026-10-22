import 'package:flutter/material.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String category;
  final double rating;
  final int reviewCount;
  final int pages;
  final int publishYear;
  final String isbn;
  final String description;
  final List<Color> coverGradient;
  final String? coverUrl;
  final String source; // 'LibFlow', 'Google Books', 'Open Library'
  final String? previewUrl;
  final String? infoUrl;
  final bool isAvailable;
  final int availableCopies;
  final int totalCopies;
  final bool hasEBook;
  final bool hasAudio;
  final String audioDuration;
  final String readingContent;
  bool isFavorite;
  bool isReserved;
  DateTime? reservationTime;
  String? reservationCode;
  bool isBorrowed;
  DateTime? dueDate;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.pages,
    required this.publishYear,
    required this.isbn,
    required this.description,
    required this.coverGradient,
    this.coverUrl,
    this.source = 'LibFlow',
    this.previewUrl,
    this.infoUrl,
    required this.isAvailable,
    required this.availableCopies,
    required this.totalCopies,
    this.hasEBook = true,
    this.hasAudio = false,
    this.audioDuration = '',
    required this.readingContent,
    this.isFavorite = false,
    this.isReserved = false,
    this.reservationTime,
    this.reservationCode,
    this.isBorrowed = false,
    this.dueDate,
  });

  Book copyWith({
    bool? isFavorite,
    bool? isReserved,
    DateTime? reservationTime,
    String? reservationCode,
    bool? isBorrowed,
    DateTime? dueDate,
    int? availableCopies,
    String? coverUrl,
    String? source,
    String? previewUrl,
    String? infoUrl,
  }) {
    return Book(
      id: id,
      title: title,
      author: author,
      category: category,
      rating: rating,
      reviewCount: reviewCount,
      pages: pages,
      publishYear: publishYear,
      isbn: isbn,
      description: description,
      coverGradient: coverGradient,
      coverUrl: coverUrl ?? this.coverUrl,
      source: source ?? this.source,
      previewUrl: previewUrl ?? this.previewUrl,
      infoUrl: infoUrl ?? this.infoUrl,
      isAvailable: isAvailable,
      availableCopies: availableCopies ?? this.availableCopies,
      totalCopies: totalCopies,
      hasEBook: hasEBook,
      hasAudio: hasAudio,
      audioDuration: audioDuration,
      readingContent: readingContent,
      isFavorite: isFavorite ?? this.isFavorite,
      isReserved: isReserved ?? this.isReserved,
      reservationTime: reservationTime ?? this.reservationTime,
      reservationCode: reservationCode ?? this.reservationCode,
      isBorrowed: isBorrowed ?? this.isBorrowed,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  // Factory for Google Books API item
  factory Book.fromGoogleBooks(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>? ?? {};
    final id = json['id'] as String? ?? UniqueKey().toString();
    final title = volumeInfo['title'] as String? ?? 'Атаусыз кітап';

    // Authors
    final authorsList = volumeInfo['authors'] as List<dynamic>?;
    final author = (authorsList != null && authorsList.isNotEmpty)
        ? authorsList.join(', ')
        : 'Белгісіз автор';

    // Categories
    final categoriesList = volumeInfo['categories'] as List<dynamic>?;
    final category = (categoriesList != null && categoriesList.isNotEmpty)
        ? categoriesList.first.toString()
        : 'Жалпы әдебиет';

    // Page count
    final pages = (volumeInfo['pageCount'] as num?)?.toInt() ?? 250;

    // Year
    int publishYear = 2022;
    final publishedDate = volumeInfo['publishedDate'] as String?;
    if (publishedDate != null && publishedDate.length >= 4) {
      publishYear = int.tryParse(publishedDate.substring(0, 4)) ?? 2022;
    }

    // ISBN
    String isbn = 'ISBN-жоқ';
    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
    if (identifiers != null) {
      for (var iden in identifiers) {
        if (iden is Map<String, dynamic> && iden['identifier'] != null) {
          isbn = iden['identifier'].toString();
          break;
        }
      }
    }

    // Rating
    final rating = (volumeInfo['averageRating'] as num?)?.toDouble() ?? 4.5;
    final reviewCount = (volumeInfo['ratingsCount'] as num?)?.toInt() ?? 18;

    // Description
    final description = volumeInfo['description'] as String? ??
        'Бұл кітап Google Books API деректер базасынан алынған. Толық мазмұнын онлайн қарап шығуға болады.';

    // Images
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    String? coverUrl;
    if (imageLinks != null) {
      coverUrl = (imageLinks['thumbnail'] ?? imageLinks['smallThumbnail']) as String?;
      if (coverUrl != null && coverUrl.startsWith('http://')) {
        coverUrl = coverUrl.replaceFirst('http://', 'https://');
      }
    }

    final previewUrl = volumeInfo['previewLink'] as String?;
    final infoUrl = volumeInfo['infoLink'] as String?;

    // Gradient based on ID hash
    final gradients = [
      [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
      [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
      [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
      [const Color(0xFFC026D3), const Color(0xFFE879F9)],
      [const Color(0xFFD97706), const Color(0xFFFBBF24)],
    ];
    final colorPair = gradients[id.hashCode.abs() % gradients.length];

    return Book(
      id: 'gb_$id',
      title: title,
      author: author,
      category: category,
      rating: rating,
      reviewCount: reviewCount,
      pages: pages,
      publishYear: publishYear,
      isbn: isbn,
      description: description,
      coverGradient: colorPair,
      coverUrl: coverUrl,
      source: 'Google Books',
      previewUrl: previewUrl,
      infoUrl: infoUrl,
      isAvailable: true,
      availableCopies: 3,
      totalCopies: 4,
      hasEBook: true,
      hasAudio: false,
      readingContent: '''$title

Автор: $author
Дереккөз: Google Books API

КІТАПҚА ШОЛУ:
$description

(Толық мәтінді Google Books ресми сайтынан қарап шығуға болады)''',
    );
  }

  // Factory for Open Library API item
  factory Book.fromOpenLibrary(Map<String, dynamic> json) {
    final key = json['key'] as String? ?? UniqueKey().toString();
    final title = json['title'] as String? ?? 'Атаусыз кітап';

    // Authors
    final authorsList = json['author_name'] as List<dynamic>?;
    final author = (authorsList != null && authorsList.isNotEmpty)
        ? authorsList.join(', ')
        : 'Белгісіз автор';

    // Categories / Subjects
    final subjectList = json['subject'] as List<dynamic>?;
    final category = (subjectList != null && subjectList.isNotEmpty)
        ? subjectList.first.toString()
        : 'Әдебиет';

    // Page count
    final pages = (json['number_of_pages_median'] as num?)?.toInt() ?? 280;

    // Year
    final publishYear =
        (json['first_publish_year'] as num?)?.toInt() ?? 2020;

    // ISBN
    String isbn = 'ISBN-жоқ';
    final isbnList = json['isbn'] as List<dynamic>?;
    if (isbnList != null && isbnList.isNotEmpty) {
      isbn = isbnList.first.toString();
    }

    // Rating
    final rating = (json['ratings_average'] as num?)?.toDouble() ?? 4.6;

    // Cover image
    final coverId = json['cover_i'];
    String? coverUrl;
    if (coverId != null) {
      coverUrl = 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
    }

    final infoUrl = 'https://openlibrary.org$key';

    final gradients = [
      [const Color(0xFF0369A1), const Color(0xFF38BDF8)],
      [const Color(0xFF047857), const Color(0xFF34D399)],
      [const Color(0xFF4338CA), const Color(0xFF818CF8)],
      [const Color(0xFFBE123C), const Color(0xFFFB7185)],
    ];
    final colorPair = gradients[key.hashCode.abs() % gradients.length];

    return Book(
      id: 'ol_${key.replaceAll('/', '_')}',
      title: title,
      author: author,
      category: category,
      rating: double.parse(rating.toStringAsFixed(1)),
      reviewCount: (json['edition_count'] as num?)?.toInt() ?? 12,
      pages: pages,
      publishYear: publishYear,
      isbn: isbn,
      description:
          'Бұл кітап Open Library әлемдік ашық цифрлық кітапхана қорынан табылды. Басылымдар саны: ${(json['edition_count'] ?? 1)}. Кілт сөзі: $key.',
      coverGradient: colorPair,
      coverUrl: coverUrl,
      source: 'Open Library',
      infoUrl: infoUrl,
      isAvailable: true,
      availableCopies: 2,
      totalCopies: 3,
      hasEBook: true,
      hasAudio: false,
      readingContent: '''$title

Автор: $author
Басылым жылы: $publishYear
Дереккөз: Open Library (Internet Archive)

МАЗМҰНЫ:
Бұл туынды ашық цифрлық кітапхана каталогында индекстелген. Оны Open Library веб-платформасы арқылы толық көруге болады.

Сілтеме: $infoUrl''',
    );
  }
}

class BookReview {
  final String id;
  final String userName;
  final double rating;
  final String date;
  final String comment;

  BookReview({
    required this.id,
    required this.userName,
    required this.rating,
    required this.date,
    required this.comment,
  });
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final String type; // 'deadline', 'reservation', 'news'
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.isRead = false,
  });
}

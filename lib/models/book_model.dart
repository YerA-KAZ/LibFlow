import 'package:flutter/material.dart';

class BookChapter {
  final String id;
  final String title;
  final String text;
  const BookChapter({
    required this.id,
    required this.title,
    required this.text,
  });
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'text': text};
  factory BookChapter.fromMap(Map<String, dynamic> map) => BookChapter(
    id: map['id'] as String,
    title: map['title'] as String,
    text: map['text'] as String,
  );
}

const _keepAudio = Object();

class Book {
  final String id;
  final String title;
  final String author;
  final String? authorId;
  final String category;
  final String? categoryId;
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
  final List<BookChapter> chapters;
  final String? audioUrl;
  List<BookChapter> get readableChapters =>
      chapters.where((c) => c.text.trim().isNotEmpty).isNotEmpty
      ? chapters.where((c) => c.text.trim().isNotEmpty).toList()
      : readingContent.trim().isEmpty
      ? []
      : [BookChapter(id: 'legacy', title: title, text: readingContent)];
  bool get canRead => hasEBook && readableChapters.isNotEmpty;
  bool get canListen =>
      hasAudio && audioUrl != null && audioUrl!.trim().isNotEmpty;
  bool isFavorite;
  bool isReserved;
  DateTime? reservationTime;
  String? reservationCode;
  bool get hasActiveReservation {
    final time = reservationTime;
    return isReserved &&
        time != null &&
        DateTime.now().isBefore(time.add(const Duration(hours: 24)));
  }

  bool isBorrowed;
  DateTime? dueDate;

  Book({
    required this.id,
    required this.title,
    required this.author,
    this.authorId,
    required this.category,
    this.categoryId,
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
    this.chapters = const [],
    this.audioUrl,
    this.isFavorite = false,
    this.isReserved = false,
    this.reservationTime,
    this.reservationCode,
    this.isBorrowed = false,
    this.dueDate,
  });

  Book copyWith({
    String? title,
    String? author,
    String? authorId,
    String? category,
    String? categoryId,
    double? rating,
    int? reviewCount,
    int? pages,
    int? publishYear,
    String? isbn,
    String? description,
    List<Color>? coverGradient,
    bool? isFavorite,
    bool? isReserved,
    DateTime? reservationTime,
    String? reservationCode,
    bool? isBorrowed,
    DateTime? dueDate,
    bool? isAvailable,
    int? availableCopies,
    int? totalCopies,
    bool? hasEBook,
    bool? hasAudio,
    String? audioDuration,
    String? readingContent,
    List<BookChapter>? chapters,
    Object? audioUrl = _keepAudio,
    String? coverUrl,
    String? source,
    String? previewUrl,
    String? infoUrl,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      authorId: authorId ?? this.authorId,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      pages: pages ?? this.pages,
      publishYear: publishYear ?? this.publishYear,
      isbn: isbn ?? this.isbn,
      description: description ?? this.description,
      coverGradient: coverGradient ?? this.coverGradient,
      coverUrl: coverUrl ?? this.coverUrl,
      source: source ?? this.source,
      previewUrl: previewUrl ?? this.previewUrl,
      infoUrl: infoUrl ?? this.infoUrl,
      isAvailable:
          isAvailable ??
          (availableCopies == null ? this.isAvailable : availableCopies > 0),
      availableCopies: availableCopies ?? this.availableCopies,
      totalCopies: totalCopies ?? this.totalCopies,
      hasEBook: hasEBook ?? this.hasEBook,
      hasAudio: hasAudio ?? this.hasAudio,
      audioDuration: audioDuration ?? this.audioDuration,
      readingContent: readingContent ?? this.readingContent,
      chapters: chapters ?? this.chapters,
      audioUrl: identical(audioUrl, _keepAudio)
          ? this.audioUrl
          : audioUrl as String?,
      isFavorite: isFavorite ?? this.isFavorite,
      isReserved: isReserved ?? this.isReserved,
      reservationTime: isReserved == false
          ? null
          : reservationTime ?? this.reservationTime,
      reservationCode: isReserved == false
          ? null
          : reservationCode ?? this.reservationCode,
      isBorrowed: isBorrowed ?? this.isBorrowed,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  // Map representation for Local Database (SQLite / Local Storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'authorId': authorId,
      'category': category,
      'categoryId': categoryId,
      'rating': rating,
      'reviewCount': reviewCount,
      'pages': pages,
      'publishYear': publishYear,
      'isbn': isbn,
      'description': description,
      'coverUrl': coverUrl,
      'source': source,
      'previewUrl': previewUrl,
      'infoUrl': infoUrl,
      'isAvailable': isAvailable ? 1 : 0,
      'availableCopies': availableCopies,
      'totalCopies': totalCopies,
      'hasEBook': hasEBook ? 1 : 0,
      'hasAudio': hasAudio ? 1 : 0,
      'audioDuration': audioDuration,
      'readingContent': readingContent,
      'chapters': chapters.map((c) => c.toMap()).toList(),
      'audioUrl': audioUrl,
      'isFavorite': isFavorite ? 1 : 0,
      'isReserved': isReserved ? 1 : 0,
      'reservationTime': reservationTime?.toIso8601String(),
      'reservationCode': reservationCode,
      'isBorrowed': isBorrowed ? 1 : 0,
      'dueDate': dueDate?.toIso8601String(),
    };
  }

  // Factory constructor from Map / Local Database
  factory Book.fromMap(Map<String, dynamic> map) {
    // Generate harmonious gradient based on book id
    final gradients = [
      [const Color(0xFF1E392A), const Color(0xFF2D5A42)],
      [const Color(0xFF1E3347), const Color(0xFF2C4A63)],
      [const Color(0xFF8D4B38), const Color(0xFFA65B45)],
      [const Color(0xFF2E384D), const Color(0xFF4A5568)],
      [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
      [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
    ];
    final colorPair =
        gradients[(map['id']?.toString() ?? '1').hashCode.abs() %
            gradients.length];

    return Book(
      id: map['id']?.toString() ?? UniqueKey().toString(),
      title: map['title'] ?? 'Атаусыз кітап',
      author: map['author'] ?? 'Белгісіз автор',
      authorId: map['authorId']?.toString(),
      category: map['category'] ?? 'Жалпы әдебиет',
      categoryId: map['categoryId']?.toString(),
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 10,
      pages: (map['pages'] as num?)?.toInt() ?? 250,
      publishYear: (map['publishYear'] as num?)?.toInt() ?? 2022,
      isbn: map['isbn'] ?? 'ISBN-жоқ',
      description: map['description'] ?? '',
      coverGradient: colorPair,
      coverUrl: map['coverUrl'],
      source: map['source'] ?? 'LibFlow',
      previewUrl: map['previewUrl'],
      infoUrl: map['infoUrl'],
      isAvailable: (map['isAvailable'] == 1 || map['isAvailable'] == true),
      availableCopies: (map['availableCopies'] as num?)?.toInt() ?? 1,
      totalCopies: (map['totalCopies'] as num?)?.toInt() ?? 1,
      hasEBook: (map['hasEBook'] == 1 || map['hasEBook'] == true),
      hasAudio: (map['hasAudio'] == 1 || map['hasAudio'] == true),
      audioDuration: map['audioDuration'] ?? '',
      readingContent: map['readingContent'] ?? '',
      chapters: (map['chapters'] as List? ?? [])
          .map((c) => BookChapter.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      audioUrl: map['audioUrl'] as String?,
      isFavorite: (map['isFavorite'] == 1 || map['isFavorite'] == true),
      isReserved: (map['isReserved'] == 1 || map['isReserved'] == true),
      reservationTime: map['reservationTime'] != null
          ? DateTime.tryParse(map['reservationTime'])
          : null,
      reservationCode: map['reservationCode'],
      isBorrowed: (map['isBorrowed'] == 1 || map['isBorrowed'] == true),
      dueDate: map['dueDate'] != null
          ? DateTime.tryParse(map['dueDate'])
          : null,
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
    final pages = (volumeInfo['pageCount'] as num?)?.toInt() ?? 0;

    // Year
    int publishYear = 0;
    final publishedDate = volumeInfo['publishedDate'] as String?;
    if (publishedDate != null && publishedDate.length >= 4) {
      publishYear = int.tryParse(publishedDate.substring(0, 4)) ?? 0;
    }

    // ISBN
    String isbn = '';
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
    final rating = (volumeInfo['averageRating'] as num?)?.toDouble() ?? 0;
    final reviewCount = (volumeInfo['ratingsCount'] as num?)?.toInt() ?? 0;

    // Description
    final description = volumeInfo['description'] as String? ?? '';

    // Images
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    String? coverUrl;
    if (imageLinks != null) {
      coverUrl =
          (imageLinks['thumbnail'] ?? imageLinks['smallThumbnail']) as String?;
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
      isAvailable: false,
      availableCopies: 0,
      totalCopies: 0,
      hasEBook: false,
      hasAudio: false,
      readingContent: '',
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
    final pages = (json['number_of_pages_median'] as num?)?.toInt() ?? 0;

    // Year
    final publishYear = (json['first_publish_year'] as num?)?.toInt() ?? 0;

    // ISBN
    String isbn = '';
    final isbnList = json['isbn'] as List<dynamic>?;
    if (isbnList != null && isbnList.isNotEmpty) {
      isbn = isbnList.first.toString();
    }

    // Rating
    final rating = (json['ratings_average'] as num?)?.toDouble() ?? 0;

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
      reviewCount: (json['ratings_count'] as num?)?.toInt() ?? 0,
      pages: pages,
      publishYear: publishYear,
      isbn: isbn,
      description: '',
      coverGradient: colorPair,
      coverUrl: coverUrl,
      source: 'Open Library',
      infoUrl: infoUrl,
      isAvailable: false,
      availableCopies: 0,
      totalCopies: 0,
      hasEBook: false,
      hasAudio: false,
      readingContent: '',
    );
  }
}

class BookReview {
  final String id;
  final String bookId;
  final String userName;
  final double rating;
  final String date;
  final String comment;

  BookReview({
    required this.id,
    this.bookId = '',
    required this.userName,
    required this.rating,
    required this.date,
    required this.comment,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'userName': userName,
      'rating': rating,
      'date': date,
      'comment': comment,
    };
  }

  factory BookReview.fromMap(Map<String, dynamic> map) {
    return BookReview(
      id: map['id']?.toString() ?? '',
      bookId: map['bookId']?.toString() ?? '',
      userName: map['userName'] ?? 'Белгісіз оқырман',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      date: map['date'] ?? 'Бүгін',
      comment: map['comment'] ?? '',
    );
  }
}

/// 1. Author Entity / Model
class Author {
  final String id;
  final String fullName;
  final String biography;
  final int birthYear;
  final String country;
  final String? photoUrl;
  final int booksCount;

  Author({
    required this.id,
    required this.fullName,
    required this.biography,
    required this.birthYear,
    required this.country,
    this.photoUrl,
    this.booksCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'biography': biography,
      'birthYear': birthYear,
      'country': country,
      'photoUrl': photoUrl,
      'booksCount': booksCount,
    };
  }

  factory Author.fromMap(Map<String, dynamic> map) {
    return Author(
      id: map['id']?.toString() ?? '',
      fullName: map['fullName'] ?? '',
      biography: map['biography'] ?? '',
      birthYear: (map['birthYear'] as num?)?.toInt() ?? 1900,
      country: map['country'] ?? 'Қазақстан',
      photoUrl: map['photoUrl'],
      booksCount: (map['booksCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 2. BookCategory Entity / Model
class BookCategory {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final int bookCount;

  BookCategory({
    required this.id,
    required this.name,
    required this.description,
    this.iconName = 'book',
    this.bookCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconName': iconName,
      'bookCount': bookCount,
    };
  }

  factory BookCategory.fromMap(Map<String, dynamic> map) {
    return BookCategory(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      iconName: map['iconName'] ?? 'book',
      bookCount: (map['bookCount'] as num?)?.toInt() ?? 0,
    );
  }
}

typedef Category = BookCategory;

/// 3. Reader / User Entity / Model
class Reader {
  final String id;
  final String ticketNumber; // Оқырман билеті №
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final DateTime registeredAt;
  final bool isActive;

  Reader({
    required this.id,
    required this.ticketNumber,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.registeredAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ticketNumber': ticketNumber,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'registeredAt': registeredAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Reader.fromMap(Map<String, dynamic> map) {
    return Reader(
      id: map['id']?.toString() ?? '',
      ticketNumber: map['ticketNumber'] ?? 'LIB-0000',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      avatarUrl: map['avatarUrl'],
      registeredAt: map['registeredAt'] != null
          ? DateTime.tryParse(map['registeredAt']) ?? DateTime.now()
          : DateTime.now(),
      isActive: map['isActive'] == 1 || map['isActive'] == true,
    );
  }
}

/// 4. Loan / BorrowRecord Entity / Model (M-to-N transaction between Reader and Book)
class Loan {
  final String id;
  final String bookId;
  final String readerId;
  final String bookTitle;
  final String readerName;
  final DateTime borrowDate;
  final DateTime dueDate;
  final DateTime? returnDate;
  final String status; // 'active', 'reserved', 'returned', 'overdue'
  final String qrCode;

  Loan({
    required this.id,
    required this.bookId,
    required this.readerId,
    required this.bookTitle,
    required this.readerName,
    required this.borrowDate,
    required this.dueDate,
    this.returnDate,
    this.status = 'active',
    required this.qrCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'readerId': readerId,
      'bookTitle': bookTitle,
      'readerName': readerName,
      'borrowDate': borrowDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'returnDate': returnDate?.toIso8601String(),
      'status': status,
      'qrCode': qrCode,
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id']?.toString() ?? '',
      bookId: map['bookId']?.toString() ?? '',
      readerId: map['readerId']?.toString() ?? '',
      bookTitle: map['bookTitle'] ?? '',
      readerName: map['readerName'] ?? '',
      borrowDate: map['borrowDate'] != null
          ? DateTime.tryParse(map['borrowDate']) ?? DateTime.now()
          : DateTime.now(),
      dueDate: map['dueDate'] != null
          ? DateTime.tryParse(map['dueDate']) ??
                DateTime.now().add(const Duration(days: 14))
          : DateTime.now().add(const Duration(days: 14)),
      returnDate: map['returnDate'] != null
          ? DateTime.tryParse(map['returnDate'])
          : null,
      status: map['status'] ?? 'active',
      qrCode: map['qrCode'] ?? '',
    );
  }
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

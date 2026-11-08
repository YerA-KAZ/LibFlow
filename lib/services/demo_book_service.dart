import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/book_model.dart';

class DemoBookService {
  static Book? book;
  static Future<void> initialize() async {
    book = Book.fromMap(
      jsonDecode(await rootBundle.loadString('assets/books/aesop_demo.json'))
          as Map<String, dynamic>,
    );
  }
}

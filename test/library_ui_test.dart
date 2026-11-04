import 'dart:async';

import 'package:provider/provider.dart';
import 'package:libflow/services/auth_provider.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:libflow/main.dart';
import 'package:libflow/models/book_model.dart';
import 'package:libflow/screens/book_form_screen.dart';
import 'package:libflow/services/library_api_service.dart';
import 'package:libflow/services/library_database_service.dart';
import 'package:libflow/services/library_repository.dart';

http.Response jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Directory.systemTemp.createTempSync('libflow_ui_test_');
  setUpAll(() async {
    LibraryDatabaseService.storageDirectoryOverride = directory.path;
    await LibraryDatabaseService().initializeDatabase();
  });
  tearDownAll(() async {
    LibraryDatabaseService.storageDirectoryOverride = null;
    await directory.delete(recursive: true);
  });

  testWidgets('Server CRUD changes are reflected in the catalogue UI', (
    tester,
  ) async {
    final records = <Map<String, dynamic>>[];
    final repo = LibraryRepository(
      api: LibraryApiService(
        client: MockClient((r) async {
          if (r.method == 'GET') return jsonResponse(jsonEncode(records), 200);
          if (r.method == 'DELETE') {
            records.clear();
            return jsonResponse('', 204);
          }
          final record = jsonDecode(r.body) as Map<String, dynamic>;
          records
            ..clear()
            ..add(record);
          return jsonResponse(
            jsonEncode(record),
            r.method == 'POST' ? 201 : 200,
          );
        }),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          home: MainNavigationContainer(
            isDarkMode: false,
            onThemeToggle: (_) {},
            repository: repo,
          ),
        ),
      ),
    );
    for (var i = 0; i < 20 && repo.status == LibraryStatus.loading; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Каталог').last);
    await tester.pumpAndSettle();
    final book = Book.fromMap({
      'id': 'ui',
      'title': 'Unique created title',
      'author': 'Author',
    });
    await tester.runAsync(() => repo.add(book));
    await tester.pumpAndSettle();
    expect(find.text('Unique created title'), findsWidgets);
    await tester.runAsync(
      () => repo.update(book.copyWith(title: 'Unique updated title')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unique updated title'), findsWidgets);
    expect(find.text('Unique created title'), findsNothing);
    await tester.runAsync(() => repo.delete(book.id));
    await tester.pumpAndSettle();
    expect(find.text('Unique updated title'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });

  testWidgets(
    'Form shows loading, retains input on error, and retries successfully',
    (tester) async {
      var pending = Completer<bool>();
      final book = Book.fromMap({
        'id': 'form',
        'description': 'A valid description with enough characters',
        'title': 'Form title',
        'author': 'Author',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => BookFormScreen(
                      book: book,
                      onSave: (_) => pending.future,
                    ),
                  ),
                ),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Сақтау'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.byType(BookFormScreen), findsOneWidget);
      expect(find.textContaining('Сақтау орындалмады'), findsOneWidget);
      pending = Completer<bool>();
      await tester.tap(find.byTooltip('Сақтау'));
      await tester.pump();
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(BookFormScreen), findsNothing);
      expect(find.textContaining('сәтті жаңартылды'), findsOneWidget);
    },
  );
}

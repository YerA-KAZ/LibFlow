import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:libflow/main.dart';
import 'package:libflow/models/book_model.dart';
import 'package:libflow/screens/book_detail_screen.dart';
import 'package:libflow/screens/book_form_screen.dart';
import 'package:libflow/screens/ereader_screen.dart';
import 'package:libflow/screens/library_card_screen.dart';
import 'package:libflow/screens/notifications_screen.dart';
import 'package:libflow/screens/profile_screen.dart';
import 'package:libflow/screens/qr_scanner_screen.dart';
import 'package:libflow/services/auth_provider.dart';
import 'package:libflow/services/library_api_service.dart';
import 'package:libflow/services/library_database_service.dart';
import 'package:libflow/services/library_repository.dart';
import 'package:libflow/widgets/qr_widget.dart';
import 'package:provider/provider.dart';

Book sampleBook() => Book.fromMap({
  'id': 'final_book',
  'title': 'Final acceptance book',
  'author': 'Абай',
  'description': 'Final acceptance description for all navigation checks.',
  'isAvailable': true,
  'availableCopies': 1,
  'totalCopies': 1,
  'hasEBook': true,
  'hasAudio': true,
  'readingContent': 'Бірінші сөз. Оқуға арналған тест мәтіні.',
  'isFavorite': true,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Directory.systemTemp.createTempSync('libflow_final_');
  final cache = LibraryDatabaseService();
  setUpAll(() async {
    LibraryDatabaseService.storageDirectoryOverride = directory.path;
    await cache.initializeDatabase();
  });
  tearDownAll(() async {
    LibraryDatabaseService.storageDirectoryOverride = null;
    await directory.delete(recursive: true);
  });

  Future<AuthProvider> mount(
    WidgetTester tester,
    Widget home, {
    String name = 'Тест Оқырман',
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthProvider()
      ..user = {'name': name, 'email': 'final@test.kz', 'ticket': 'LF-FINAL'};
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(home: home),
      ),
    );
    addTearDown(auth.dispose);
    return auth;
  }

  test('TC-M01 reservation cancellation clears code and timestamp', () {
    final reserved = sampleBook().copyWith(
      isReserved: true,
      reservationCode: 'OLD',
      reservationTime: DateTime.now(),
      availableCopies: 0,
    );
    final cancelled = reserved.copyWith(isReserved: false, availableCopies: 1);
    expect(cancelled.reservationCode, isNull);
    expect(cancelled.reservationTime, isNull);
    expect(cancelled.isAvailable, isTrue);
    expect(cancelled.availableCopies, 1);
  });

  test(
    'TC-M02 last copy becomes unavailable, return restores availability',
    () {
      final last = sampleBook().copyWith(availableCopies: 0);
      expect(last.isAvailable, isFalse);
      expect(last.copyWith(availableCopies: 1).isAvailable, isTrue);
    },
  );

  testWidgets('TC-N01 main tabs and profile favorites navigation', (
    tester,
  ) async {
    await tester.runAsync(() => cache.replaceBooks([sampleBook()]));
    final repository = LibraryRepository(
      api: LibraryApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode([sampleBook().toMap()]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    );
    await mount(
      tester,
      MainNavigationContainer(
        repository: repository,
        isDarkMode: false,
        onThemeToggle: (_) {},
      ),
    );
    for (var i = 0; i < 50 && repository.status == LibraryStatus.loading; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(repository.status, LibraryStatus.success);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Сәлем, Тест!'), findsOneWidget);
    for (final label in ['Каталог', 'Броньдар', 'Профиль']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Таңдаулылар'));
    await tester.tap(find.text('Таңдаулылар'));
    await tester.pumpAndSettle();
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 2);
    expect(find.text('Final acceptance book'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    repository.dispose();
  });

  testWidgets(
    'TC-N02 profile settings, card, notifications and scanner routes',
    (tester) async {
      var dark = false;
      await tester.runAsync(() => cache.replaceBooks([sampleBook()]));
      await mount(
        tester,
        ProfileScreen(
          isDarkMode: false,
          onThemeToggle: (value) => dark = value,
          onLogout: () {},
          onNavigateToFavorites: () {},
          onNavigateToMyBooks: () {},
        ),
      );
      await tester.scrollUntilVisible(find.text('Бронь QR кодын тексеру'), 150);
      await tester.tap(find.text('Бронь QR кодын тексеру'));
      await tester.pumpAndSettle();
      expect(find.byType(QrScannerScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Сандық оқырман билеті'));
      await tester.tap(find.text('Сандық оқырман билеті'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryCardScreen), findsOneWidget);
      expect(find.text('Тест Оқырман'), findsWidgets);
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Баптаулар'));
      await tester.tap(find.text('Баптаулар'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile).last);
      await tester.pumpAndSettle();
      expect(dark, isTrue);
      Navigator.of(tester.element(find.byType(SwitchListTile).last)).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Хабарламалар'));
      await tester.tap(find.text('Хабарламалар'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Жаңа хабарламалар жоқ'), findsOneWidget);
    },
  );

  testWidgets('TC-N03 empty profile name does not crash avatar', (
    tester,
  ) async {
    await mount(
      tester,
      ProfileScreen(
        isDarkMode: false,
        onThemeToggle: (_) {},
        onLogout: () {},
        onNavigateToFavorites: () {},
        onNavigateToMyBooks: () {},
      ),
      name: '',
    );
    expect(find.text('?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TC-N04 book detail opens editor, reader and disables missing audio',
    (tester) async {
      await mount(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BookDetailScreen(
                    book: sampleBook(),
                    staff: true,
                    onBookUpdated: (_) async => true,
                  ),
                ),
              ),
              child: const Text('Open detail'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.byType(BookDetailScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Кітапты өңдеу'));
      await tester.pumpAndSettle();
      expect(find.byType(BookFormScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Оқуды бастау'), 140);
      final readButton = find.widgetWithText(OutlinedButton, 'Оқуды бастау');
      await tester.pumpAndSettle();
      await tester.ensureVisible(readButton);
      await tester.pumpAndSettle();
      await tester.tap(readButton.hitTestable());
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(EReaderScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Аудио тыңдау'));
      final audioButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Аудио тыңдау'),
      );
      expect(audioButton.onPressed, isNull);
    },
  );

  testWidgets('a reservation ticket appears only after a successful save', (
    tester,
  ) async {
    final pending = Completer<bool>();
    Book? update;
    await mount(
      tester,
      BookDetailScreen(
        book: sampleBook(),
        onBookUpdated: (book) {
          update = book;
          return pending.future;
        },
      ),
    );
    await tester.tap(find.text('Дананы брондау'));
    await tester.pump();
    expect(update?.availableCopies, 0);
    expect(find.byType(CustomQrView), findsNothing);

    pending.complete(true);
    await tester.pumpAndSettle();
    expect(update?.hasActiveReservation, isTrue);
    expect(
      tester.widget<CustomQrView>(find.byType(CustomQrView)).data,
      update?.reservationCode,
    );
    expect(find.text('Белсенді бронь'), findsOneWidget);
  });

  testWidgets(
    'external records and legacy reservations cannot produce a new QR',
    (tester) async {
      var writes = 0;
      final book = sampleBook();
      await mount(
        tester,
        BookDetailScreen(
          book: book,
          inCollection: false,
          onBookUpdated: (_) async {
            writes++;
            return true;
          },
        ),
      );
      expect(find.text('Сыртқы каталог'), findsOneWidget);
      expect(find.text('Дананы брондау'), findsNothing);
      expect(find.byType(CustomQrView), findsNothing);
      await tester.pumpWidget(const SizedBox());

      await mount(
        tester,
        BookDetailScreen(
          book: book.copyWith(
            isReserved: true,
            reservationTime: DateTime.now(),
          ),
          onBookUpdated: (_) async {
            writes++;
            return true;
          },
        ),
      );
      await tester.tap(find.text('Бронь билеті'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomQrView), findsNothing);
      expect(find.textContaining('алу коды тіркелмеген'), findsOneWidget);
      expect(writes, 0);
    },
  );

  testWidgets('TC-N05 notifications use real local loans and reservations', (
    tester,
  ) async {
    var opened = false;
    final book = sampleBook().copyWith(
      isBorrowed: true,
      dueDate: DateTime.now().add(const Duration(days: 1)),
    );
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => NotificationsScreen(
                  books: [book],
                  onNavigateToMyBooks: () => opened = true,
                ),
              ),
            ),
            child: const Text('Open notifications'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Қайтару мерзімі'), findsOneWidget);
    await tester.tap(find.text('Барлығын оқылды деу'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Қайтару мерзімі'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(find.byType(NotificationsScreen), findsNothing);
  });
}

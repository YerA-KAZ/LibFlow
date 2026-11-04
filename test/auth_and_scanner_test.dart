import 'dart:convert';
import 'dart:io';

import 'package:libflow/models/book_model.dart';
import 'package:libflow/services/library_database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:libflow/services/auth_provider.dart';
import 'package:libflow/services/scanner_access.dart';
import 'package:libflow/screens/auth_screen.dart';
import 'package:libflow/screens/qr_scanner_screen.dart';
import 'package:libflow/main.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MemoryStore implements AuthStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Registration, duplicate, wrong password, login, restart, logout and expiry', () async {
    final store = MemoryStore();
    final auth = AuthProvider(store: store, iterations: 10);
    expect(await auth.submit(email: 'bad', password: '123'), isFalse);
    expect(
      await auth.submit(
        email: 'a@test.kz',
        password: 'password123',
        name: 'Айша',
      ),
      isTrue,
    );
    expect(store.values['accounts'], isNot(contains('password123')));
    expect(auth.user!['name'], 'Айша');
    final restarted = AuthProvider(store: store, iterations: 10);
    await restarted.restore();
    expect(restarted.authenticated, isTrue);
    await restarted.logout();
    expect(store.values.containsKey('session'), isFalse);
    expect(
      await restarted.submit(
        email: 'a@test.kz',
        password: 'password123',
        name: 'Айша',
      ),
      isFalse,
    );
    expect(
      await restarted.submit(email: 'a@test.kz', password: 'wrongpassword'),
      isFalse,
    );
    expect(restarted.authenticated, isFalse);
    expect(
      await restarted.submit(email: 'A@test.kz', password: 'password123'),
      isTrue,
    );
    store.values['session'] = jsonEncode({
      'email': 'a@test.kz',
      'expiresAt': '2000-01-01T00:00:00',
    });
    final expired = AuthProvider(store: store);
    await expired.restore();
    expect(expired.authenticated, isFalse);
  });
  for (final entry in {
    PermissionStatus.granted: CameraAccess.granted,
    PermissionStatus.denied: CameraAccess.denied,
    PermissionStatus.permanentlyDenied: CameraAccess.blocked,
  }.entries) {
    test('Camera permission ${entry.key}', () async {
      final service = ScannerAccess(request: () async => entry.key);
      await service.ask();
      expect(service.state, entry.value);
      final restarted = ScannerAccess(request: () async => entry.key);
      expect(restarted.state, CameraAccess.unknown);
      await restarted.ask();
      expect(restarted.state, entry.value);
    });
  }
  test(
    'QR matches active reservation and rejects unknown or expired codes',
    () async {
      final folder = await Directory.systemTemp.createTemp('libflow_qr_test_');
      LibraryDatabaseService.storageDirectoryOverride = folder.path;
      final db = LibraryDatabaseService();
      await db.replaceBooks([
        Book.fromMap({
          'id': 'qr',
          'title': 'Абай жолы',
          'isReserved': 1,
          'reservationCode': 'LIBFLOW-TEST',
          'reservationTime': DateTime.now().toIso8601String(),
        }),
      ]);
      expect(reservationResult('LIBFLOW-TEST', db), contains('Бронь расталды'));
      expect(reservationResult('OTHER', db), contains('табылмады'));
      await db.replaceBooks([
        db.books.single.copyWith(reservationTime: DateTime(2000)),
      ]);
      expect(
        reservationResult('LIBFLOW-TEST', db),
        contains('мерзімі аяқталған'),
      );
      LibraryDatabaseService.storageDirectoryOverride = null;
      await folder.delete(recursive: true);
    },
  );
  testWidgets('Unauthenticated app has login and blocks catalogue', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const LibFlowApp());
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Каталог'), findsNothing);
    await tester.tap(find.text('Кіру'));
    await tester.pumpAndSettle();
    expect(find.text('Email дұрыс емес'), findsOneWidget);
  });
  testWidgets(
    'Restored session opens app and logout closes protected screens',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'accounts': jsonEncode({
          'a@test.kz': {
            'name': 'Айша',
            'email': 'a@test.kz',
            'ticket': 'LF-TEST',
          },
        }),
        'session': jsonEncode({
          'email': 'a@test.kz',
          'expiresAt': DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        }),
      });
      await tester.pumpWidget(const LibFlowApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(MainNavigationContainer), findsOneWidget);
      final auth = tester
          .element(find.byType(MainNavigationContainer))
          .read<AuthProvider>();
      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(MainNavigationContainer), findsNothing);
    },
  );
  testWidgets('Scanner route rejects unauthenticated users', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(store: MemoryStore()),
        child: const MaterialApp(home: QrScannerScreen()),
      ),
    );
    expect(find.text('Алдымен жүйеге кіріңіз.'), findsOneWidget);
  });
}

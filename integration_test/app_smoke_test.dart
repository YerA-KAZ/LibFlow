import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:libflow/main.dart' as app;
import 'package:libflow/screens/auth_screen.dart';
import 'package:libflow/screens/profile_screen.dart';
import 'package:libflow/screens/qr_scanner_screen.dart';
import 'package:libflow/services/auth_provider.dart';
import 'package:provider/provider.dart';

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) fail('Device scenario timed out');
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android registration, navigation, REST/realtime, scanner and login/logout',
    (tester) async {
      await app.main();
      await waitFor(
        tester,
        () =>
            find.byType(AuthScreen).evaluate().isNotEmpty ||
            find.byType(app.MainNavigationContainer).evaluate().isNotEmpty,
      );
      if (find.byType(app.MainNavigationContainer).evaluate().isNotEmpty) {
        await tester
            .element(find.byType(app.MainNavigationContainer))
            .read<AuthProvider>()
            .logout();
        await waitFor(
          tester,
          () => find.byType(AuthScreen).evaluate().isNotEmpty,
        );
      }
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      final email = 'device_$suffix@test.kz';
      const password = 'DeviceTest123!';
      await tester.tap(find.text('Аккаунт жасау'));
      await tester.pump();
      for (final entry in [
        'Құрылғы Тесті',
        email,
        password,
        password,
      ].asMap().entries) {
        await tester.enterText(
          find.byType(TextFormField).at(entry.key),
          entry.value,
        );
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await waitFor(
        tester,
        () => find.text('Сәлем, Құрылғы!').evaluate().isNotEmpty,
      );
      expect(find.byType(app.MainNavigationContainer), findsOneWidget);
      await waitFor(
        tester,
        () =>
            find.text('Нақты уақыттағы байланыс қосылды').evaluate().isNotEmpty,
      );

      await tester.tap(find.text('Каталог').last);
      await tester.pumpAndSettle();
      final api = const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8000',
      );
      final id = 'device_$suffix';
      final title = 'Device realtime $suffix';
      final payload = {
        'id': id,
        'title': title,
        'author': 'Device test',
        'totalCopies': 1,
        'availableCopies': 1,
      };
      try {
        final created = await http.post(
          Uri.parse('$api/api/books'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        expect(created.statusCode, 201);
        await waitFor(tester, () => find.text(title).evaluate().isNotEmpty);
        expect(find.text(title), findsWidgets);
        final updated = await http.put(
          Uri.parse('$api/api/books/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({...payload, 'title': '$title updated'}),
        );
        expect(updated.statusCode, 200);
        await waitFor(
          tester,
          () => find.text('$title updated').evaluate().isNotEmpty,
        );
        final deleted = await http.delete(Uri.parse('$api/api/books/$id'));
        expect(deleted.statusCode, 204);
        await waitFor(
          tester,
          () => find.text('$title updated').evaluate().isEmpty,
        );
      } finally {
        await http.delete(Uri.parse('$api/api/books/$id'));
      }

      await tester.tap(find.text('Профиль').last);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.tap(find.text('Бронь QR кодын тексеру'));
      await tester.pumpAndSettle();
      expect(find.byType(QrScannerScreen), findsOneWidget);
      expect(find.text('Камераға рұқсат беру'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      final auth = tester
          .element(find.byType(app.MainNavigationContainer))
          .read<AuthProvider>();
      await auth.logout();
      await waitFor(
        tester,
        () => find.byType(AuthScreen).evaluate().isNotEmpty,
      );
      await tester.enterText(find.byType(TextFormField).at(0), email);
      await tester.enterText(find.byType(TextFormField).at(1), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(FilledButton));
      await waitFor(
        tester,
        () => find.text('Сәлем, Құрылғы!').evaluate().isNotEmpty,
      );
      expect(find.byType(app.MainNavigationContainer), findsOneWidget);
      final signedIn = tester
          .element(find.byType(app.MainNavigationContainer))
          .read<AuthProvider>();
      expect(signedIn.user!['email'], email);
      await signedIn.logout();
      await waitFor(
        tester,
        () => find.byType(AuthScreen).evaluate().isNotEmpty,
      );
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

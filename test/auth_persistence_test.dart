import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:libflow/services/auth_provider.dart';

class CheckedStore implements AuthStore {
  final values = <String, String>{};
  bool dropWrites = false, failReads = false;
  int writes = 0;
  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('storage unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (!dropWrites) values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  test(
    'registration is not reported successful when storage drops writes',
    () async {
      final store = CheckedStore()..dropWrites = true;
      final auth = AuthProvider(store: store, iterations: 10);
      expect(
        await auth.submit(
          email: 'a@test.kz',
          password: 'password123',
          name: 'Айша',
        ),
        isFalse,
      );
      expect(auth.authenticated, isFalse);
      expect(auth.error, contains('қауіпсіз сақтау'));
      expect(store.values['session'], isNull);
      auth.dispose();
    },
  );
  test(
    'unreadable account storage is never overwritten by registration',
    () async {
      final store = CheckedStore()..values['accounts'] = '{broken';
      final auth = AuthProvider(store: store, iterations: 10);
      expect(
        await auth.submit(
          email: 'a@test.kz',
          password: 'password123',
          name: 'Айша',
        ),
        isFalse,
      );
      expect(store.writes, 0);
      expect(store.values['accounts'], '{broken');
      expect(auth.error, contains('қауіпсіз сақтау'));
      auth.dispose();
    },
  );
  test('restore storage error preserves session and explains account is not missing', () async {
    final store = CheckedStore()
      ..values['session'] = 'preserve'
      ..failReads = true;
    final auth = AuthProvider(store: store, iterations: 10);
    await auth.restore();
    expect(auth.initialized, isTrue);
    expect(auth.authenticated, isFalse);
    expect(store.values['session'], 'preserve');
    expect(auth.error, contains('аккаунт жоқ дегенді білдірмейді'));
    auth.dispose();
  });
  test(
    'new provider restores session, logout keeps account and login works',
    () async {
      final store = CheckedStore();
      final first = AuthProvider(store: store, iterations: 10);
      expect(
        await first.submit(
          email: 'A@test.kz',
          password: 'password123',
          name: 'Айша',
        ),
        isTrue,
      );
      first.dispose();
      final reopened = AuthProvider(store: store, iterations: 10);
      await reopened.restore();
      expect(reopened.user!['email'], 'a@test.kz');
      await reopened.logout();
      expect(store.values['accounts'], isNotNull);
      expect(
        await reopened.submit(email: ' a@test.kz ', password: 'password123'),
        isTrue,
      );
      reopened.dispose();
    },
  );
  test('restore clears stale in-memory user when session expires', () async {
    final store = CheckedStore();
    final auth = AuthProvider(store: store, iterations: 10);
    await auth.submit(
      email: 'a@test.kz',
      password: 'password123',
      name: 'Айша',
    );
    store.values['session'] = jsonEncode({
      'email': 'a@test.kz',
      'expiresAt': '2000-01-01',
    });
    await auth.restore();
    expect(auth.authenticated, isFalse);
    expect(store.values['accounts'], isNotNull);
    auth.dispose();
  });
}

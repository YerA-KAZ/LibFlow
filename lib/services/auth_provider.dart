import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAuthStore implements AuthStore {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class AuthProvider extends ChangeNotifier {
  final AuthStore store;
  final int iterations;
  Map<String, dynamic>? user;
  bool initialized = false;
  bool busy = false;
  String? error;
  bool get authenticated => user != null;
  AuthProvider({AuthStore? store, this.iterations = 210000})
    : store = store ?? SecureAuthStore();

  Future<Map<String, dynamic>> _accounts() async =>
      jsonDecode(await store.read('accounts') ?? '{}') as Map<String, dynamic>;

  Future<void> restore() async {
    try {
      final session = await store.read('session');
      if (session != null) {
        final data = jsonDecode(session) as Map<String, dynamic>;
        if (DateTime.parse(data['expiresAt'] as String)
            .isAfter(DateTime.now())) {
          final account = (await _accounts())[data['email']];
          if (account != null) {
            user = _profile(Map<String, dynamic>.from(account as Map));
          }
        }
        if (user == null) await store.delete('session');
      }
    } catch (_) {
      error = 'Сақталған сессия оқылмады. Қайта кіріңіз.';
    }
    initialized = true;
    notifyListeners();
  }

  Map<String, dynamic> _profile(Map<String, dynamic> account) => {
    'name': account['name'],
    'email': account['email'],
    'ticket': account['ticket'],
  };
  Future<String> _hash(String password, List<int> salt, int rounds) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: rounds,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    return base64Encode(await key.extractBytes());
  }

  Future<bool> submit({
    required String email,
    required String password,
    String? name,
  }) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      email = email.trim().toLowerCase();
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        throw const FormatException('Email мекенжайын дұрыс енгізіңіз.');
      }
      if (password.length < 8) {
        throw const FormatException('Құпиясөз кемінде 8 таңба болуы керек.');
      }
      final accounts = await _accounts();
      Map<String, dynamic> account;
      if (name != null) {
        if (name.trim().length < 2) {
          throw const FormatException('Аты-жөніңізді енгізіңіз.');
        }
        if (accounts.containsKey(email)) {
          throw const FormatException('Бұл email бұрын тіркелген.');
        }
        final random = Random.secure();
        final salt = List<int>.generate(16, (_) => random.nextInt(256));
        account = {
          'name': name.trim(),
          'email': email,
          'ticket': 'LF-${DateTime.now().microsecondsSinceEpoch}',
          'salt': base64Encode(salt),
          'iterations': iterations,
          'hash': await _hash(password, salt, iterations),
        };
        accounts[email] = account;
        await store.write('accounts', jsonEncode(accounts));
      } else {
        final record = accounts[email];
        if (record == null) {
          throw const FormatException('Email немесе құпиясөз қате.');
        }
        account = Map<String, dynamic>.from(record as Map);
        final hash = await _hash(
          password,
          base64Decode(account['salt'] as String),
          account['iterations'] as int,
        );
        final expected = account['hash'] as String;
        var difference = hash.length ^ expected.length;
        for (var i = 0; i < hash.length && i < expected.length; i++) {
          difference |= hash.codeUnitAt(i) ^ expected.codeUnitAt(i);
        }
        if (difference != 0) {
          throw const FormatException('Email немесе құпиясөз қате.');
        }
      }
      await store.write(
        'session',
        jsonEncode({
          'email': email,
          'expiresAt': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
        }),
      );
      user = _profile(account); 
      return true;
    } on FormatException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Қауіпсіз сақтау қолжетімсіз. Қайта көріңіз.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await store.delete('session');
      user = null;
      error = null;
    } catch (_) {
      error = 'Сессияны өшіру орындалмады. Қайта көріңіз.';
    }
    notifyListeners();
  }
}

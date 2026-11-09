import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_log.dart';
import 'library_api_service.dart';

class AuthStorageException implements Exception {
  const AuthStorageException();
}

abstract class AuthStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAuthStore implements AuthStore {
  // Keep the existing default namespace so previously registered accounts remain readable.
  // Never silently erase accounts when Android reports a key/decryption error.
  final FlutterSecureStorage storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
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
  final LibraryApiService? api;
  String get role => user?['role'] as String? ?? 'reader';
  bool get isAdmin => role == 'admin';
  bool get isStaff => isAdmin || role == 'librarian';
  Map<String, dynamic>? user;
  bool initialized = false;
  bool busy = false;
  String? error;
  bool _disposed = false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  bool get authenticated => user != null;
  AuthProvider({AuthStore? store, this.iterations = 210000, this.api})
    : store = store ?? SecureAuthStore();

  Future<Map<String, dynamic>> _accounts() async {
    try {
      return jsonDecode(await store.read('accounts') ?? '{}')
          as Map<String, dynamic>;
    } catch (failure) {
      AppLog.event('auth.accounts_read_failed', error: failure);
      throw const AuthStorageException();
    }
  }

  Future<void> _writeVerified(String key, String value) async {
    await store.write(key, value);
    if (await store.read(key) != value) throw const AuthStorageException();
  }

  Future<void> restore() async {
    user = null;
    error = null;
    try {
      final remote = api;
      if (remote != null) {
        remote.sessionToken = await store.read('server_session');
        if (remote.sessionToken != null) {
          try {
            user = Map<String, dynamic>.from(
              await remote.request('GET', '/api/auth/me') as Map,
            );
          } on LibraryApiException catch (failure) {
            remote.sessionToken = null;
            if (failure.status == 401) {
              await store.delete('server_session');
            } else {
              error = failure.message;
            }
          }
        }
        return;
      }
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
    } catch (failure) {
      AppLog.event('auth.restore_failed', error: failure);
      error = 'Құрылғыдағы аккаунт деректері оқылмады. Бұл қате аккаунт жоқ дегенді білдірмейді. Қолданба деректерін өшірмей, қайта көріңіз.';
    } finally {
      initialized = true;
      _changed();
    }
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

  Future<Map<String, dynamic>?> _verifiedLocalAccount(
    String email,
    String password,
  ) async {
    final record = (await _accounts())[email];
    if (record == null) return null;
    final account = Map<String, dynamic>.from(record as Map);
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
    return difference == 0 ? account : null;
  }

  Future<Map> _remoteSignIn(
    LibraryApiService remote,
    String email,
    String password,
    String? name,
  ) async {
    final credentials = {'email': email, 'password': password};
    if (name != null) {
      return await remote.request(
        'POST',
        '/api/auth/register',
        body: {...credentials, 'name': name.trim()},
      ) as Map;
    }
    try {
      return await remote.request('POST', '/api/auth/login', body: credentials)
          as Map;
    } on LibraryApiException catch (error) {
      if (error.status != 401) rethrow;
      final old = await _verifiedLocalAccount(email, password);
      if (old == null) rethrow;
      try {
        return await remote.request(
          'POST',
          '/api/auth/register',
          body: {...credentials, 'name': old['name']},
        ) as Map;
      } on LibraryApiException catch (registrationError) {
        if (registrationError.status == 409) throw error;
        rethrow;
      }
    }
  }

  Future<bool> submit({
    required String email,
    required String password,
    String? name,
  }) async {
    if (_disposed || busy) return false;
    busy = true;
    error = null;
    _changed();
    try {
      email = email.trim().toLowerCase();
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        throw const FormatException('Email мекенжайын дұрыс енгізіңіз.');
      }
      if (password.length < 8) {
        throw const FormatException('Құпиясөз кемінде 8 таңба болуы керек.');
      }
      final remote = api;
      if (remote != null) {
        final result = await _remoteSignIn(remote, email, password, name);
        final token = result['token'] as String;
        await _writeVerified('server_session', token);
        remote.sessionToken = token;
        user = Map<String, dynamic>.from(result['user'] as Map);
        return true;
      }
      Map<String, dynamic> account;
      if (name != null) {
        final accounts = await _accounts();
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
        await _writeVerified('accounts', jsonEncode(accounts));
      } else {
        final verified = await _verifiedLocalAccount(email, password);
        if (verified == null) {
          throw const FormatException('Email немесе құпиясөз қате.');
        }
        account = verified;
      }
      await _writeVerified(
        'session',
        jsonEncode({
          'email': email,
          'expiresAt': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
        }),
      );
      user = _profile(account);
      AppLog.event(
        name == null ? 'auth.login_succeeded' : 'auth.registration_saved',
      );
      return true;
    } on LibraryApiException catch (e) {
      error = e.message;
      return false;
    } on FormatException catch (e) {
      error = e.message;
      return false;
    } catch (failure) {
      AppLog.event('auth.storage_failed', error: failure);
      error = 'Аккаунтты қауіпсіз сақтау немесе оқу орындалмады. Қолданба деректерін өшірмей, қайта көріңіз.';
      return false;
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> logout() async {
    try {
      final remote = api;
      if (remote != null) {
        await remote.request('POST', '/api/auth/logout');
        await store.delete('server_session');
        remote.sessionToken = null;
      } else {
        await store.delete('session');
      }
      user = null;
      error = null;
    } catch (_) {
      error = 'Сессияны өшіру орындалмады. Қайта көріңіз.';
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    api?.close();
    super.dispose();
  }
}

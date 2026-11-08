// Diagnostic entrypoint: uses isolated secure keys, never real account/session keys.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:libflow/services/auth_provider.dart';

class ProbeStore implements AuthStore {
  final storage = SecureAuthStore();
  @override
  Future<String?> read(String key) => storage.read('restart_probe_$key');
  @override
  Future<void> write(String key, String value) =>
      storage.write('restart_probe_$key', value);
  @override
  Future<void> delete(String key) => storage.delete('restart_probe_$key');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final folder = await getApplicationSupportDirectory();
  final marker = File('${folder.path}/auth_restart_probe_phase');
  final result = File('${folder.path}/auth_restart_probe_result.json');
  final store = ProbeStore();
  final auth = AuthProvider(store: store);
  final output = <String, dynamic>{};
  try {
    if (!await marker.exists()) {
      await store.delete('accounts');
      await store.delete('session');
      output['phase'] = 'write';
      output['registered'] = await auth.submit(
        email: 'restart-probe@test.invalid',
        password: 'RestartProbeOnly123!',
        name: 'Persistence probe',
      );
      output['readBack'] = await store.read('accounts') != null;
      await marker.writeAsString('read', flush: true);
    } else {
      output['phase'] = 'read';
      await auth.restore();
      output['restored'] = auth.authenticated;
      await auth.logout();
      output['loginAfterLogout'] = await auth.submit(
        email: 'restart-probe@test.invalid',
        password: 'RestartProbeOnly123!',
      );
      output['readBack'] = await store.read('accounts') != null;
      await store.delete('session');
      await store.delete('accounts');
      await marker.delete();
    }
    output['error'] = auth.error;
  } catch (failure) {
    output['failureType'] = failure.runtimeType.toString();
  }
  await result.writeAsString(jsonEncode(output), flush: true);
  auth.dispose();
  runApp(
    MaterialApp(
      home: Scaffold(body: Center(child: Text(jsonEncode(output)))),
    ),
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'library_database_service.dart';

/// Separate from the catalogue: REST refresh never overwrites reading positions.
class MediaProgressStore {
  static final instance = MediaProgressStore();
  final Future<Directory> Function() directory;
  Future<void> _writes = Future.value();

  MediaProgressStore({Future<Directory> Function()? directory})
    : directory =
          directory ??
          (() async => LibraryDatabaseService.storageDirectoryOverride != null
              ? Directory(LibraryDatabaseService.storageDirectoryOverride!)
              : getApplicationSupportDirectory());

  Future<File> _file() async {
    final folder = await directory();
    await folder.create(recursive: true);
    return File('${folder.path}/media_progress.json');
  }

  Future<Map<String, dynamic>> _read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    return Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
  }

  Future<Map<String, dynamic>> load(String bookId) async {
    // Recover the queue after a failed write; surface read errors to the caller.
    await _writes.catchError((Object _) {});
    return Map<String, dynamic>.from((await _read())[bookId] as Map? ?? {});
  }

  Future<void> save(String bookId, Map<String, dynamic> fields) {
    final operation = _writes.catchError((Object _) {}).then((_) async {
      final all = await _read();
      all[bookId] = {
        ...Map<String, dynamic>.from(all[bookId] as Map? ?? {}),
        ...fields,
      };
      final file = await _file();
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(all), flush: true);
      await temporary.rename(file.path);
    });
    _writes = operation;
    return operation;
  }
}

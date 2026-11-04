import 'dart:developer' as developer;

/// Event names and exception types only: never credentials or book payloads.
class AppLog {
  static void event(String name, {Object? error}) {
    developer.log(
      name,
      name: 'libflow',
      level: error == null ? 800 : 1000,
      error: error?.runtimeType.toString(),
    );
  }
}

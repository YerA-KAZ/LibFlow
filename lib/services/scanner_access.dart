import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraAccess { unknown, granted, denied, blocked }

class ScannerAccess extends ChangeNotifier {
  final Future<PermissionStatus> Function() request;
  bool _disposed = false;
  CameraAccess state = CameraAccess.unknown;
  ScannerAccess({Future<PermissionStatus> Function()? request})
    : request = request ?? (() => Permission.camera.request());
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> ask() async {
    try {
      final result = await request();
      state = result.isGranted
          ? CameraAccess.granted
          : (result.isPermanentlyDenied || result.isRestricted
                ? CameraAccess.blocked
                : CameraAccess.denied);
    } catch (_) {
      state = CameraAccess.denied;
    }
    if (!_disposed) notifyListeners();
  }
}

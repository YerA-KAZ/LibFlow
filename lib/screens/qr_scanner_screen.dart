import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../services/scanner_access.dart';
import '../services/library_database_service.dart';

String reservationResult(String code, LibraryDatabaseService database) {
  for (final book in database.books) {
    if (book.reservationCode == code && book.isReserved) {
      final time = book.reservationTime;
      if (time == null ||
          DateTime.now().difference(time) > const Duration(hours: 24)) {
        return 'Бронь мерзімі аяқталған.';
      }
      return 'Бронь расталды: ${book.title} — ${book.author}';
    }
  }
  return 'Бұл кодқа сәйкес белсенді бронь табылмады.';
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final access = ScannerAccess();
  MobileScannerController? camera;
  bool processing = false;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      camera?.stop();
    }
  }

  Future<void> _resume() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    if (status.isGranted) {
      try {
        await camera?.start();
      } catch (_) {
        /* The preview reports camera errors. */
      }
    } else {
      setState(() {
        camera?.dispose();
        camera = null;
        access.state = CameraAccess.denied;
      });
    }
  }

  Future<void> _ask() async {
    await access.ask();
    if (!mounted) return;
    setState(() {
      if (access.state == CameraAccess.granted) {
        camera ??= MobileScannerController(formats: [BarcodeFormat.qrCode]);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    camera?.dispose();
    access.dispose();
    super.dispose();
  }

  Future<void> _detect(BarcodeCapture capture) async {
    if (processing || !context.read<AuthProvider>().authenticated) return;
    final codes = capture.barcodes.where(
      (b) => b.rawValue != null && b.rawValue!.isNotEmpty,
    );
    if (codes.isEmpty) return;
    processing = true;
    final message = reservationResult(
      codes.first.rawValue!,
      LibraryDatabaseService(),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Бронь тексерісі'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Жабу'),
          ),
        ],
      ),
    );
    processing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().authenticated) {
      return const Scaffold(
        body: Center(child: Text('Алдымен жүйеге кіріңіз.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Бронь QR сканері')),
      body: !supported
          ? const Center(
              child: Text('QR камерасы Android/iOS құрылғысында қолжетімді.'),
            )
          : camera != null
          ? MobileScanner(
              controller: camera!,
              onDetect: _detect,
              errorBuilder: (_, error) => Center(
                child: Text('Камера ашылмады: ${error.errorCode.name}'),
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 72),
                    const Text(
                      'Бронь QR кодын оқу үшін камераға рұқсат беріңіз.',
                    ),
                    if (access.state == CameraAccess.denied)
                      const Text('Рұқсат берілмеді. Қайта сұрауға болады.'),
                    if (access.state == CameraAccess.blocked)
                      const Text(
                        'Камераға рұқсатты құрылғы баптауларынан қосыңыз.',
                      ),
                    FilledButton(
                      onPressed: _ask,
                      child: const Text('Камераға рұқсат беру'),
                    ),
                    if (access.state == CameraAccess.blocked)
                      TextButton(
                        onPressed: openAppSettings,
                        child: const Text('Баптауларды ашу'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

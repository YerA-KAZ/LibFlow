import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../models/book_model.dart';
import '../services/scanner_access.dart';
import '../services/library_database_service.dart';

String reservationResult(String code, LibraryDatabaseService database) {
  for (final book in database.books) {
    if (book.reservationCode == code && book.isReserved) {
      if (!book.hasActiveReservation) {
        return 'Бронь мерзімі аяқталған.';
      }
      return 'Бронь расталды: ${book.title} — ${book.author}';
    }
  }
  return 'Бұл кодқа сәйкес белсенді бронь табылмады.';
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, this.onBookUpdated, this.onCheck});
  final Future<bool> Function(Book)? onBookUpdated;
  final Future<void> Function(String)? onCheck;
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final access = ScannerAccess();
  final _code = TextEditingController();
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
    if (!supported || camera == null) return;
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
    _code.dispose();
    super.dispose();
  }

  Future<void> _check(String raw) async {
    final code = raw.trim();
    if (processing ||
        code.isEmpty ||
        !context.read<AuthProvider>().authenticated) {
      return;
    }
    processing = true;
    if (widget.onCheck != null) {
      try {
        await widget.onCheck!(code);
      } finally {
        processing = false;
      }
      return;
    }
    final database = LibraryDatabaseService();
    final book = database.books
        .where(
          (book) => book.isReserved && book.reservationCode?.trim() == code,
        )
        .firstOrNull;
    try {
      final issue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Бронь тексерісі'),
          content: Text(reservationResult(code, database)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Жабу'),
            ),
            if (book != null &&
                book.hasActiveReservation &&
                !book.isBorrowed &&
                widget.onBookUpdated != null)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Кітапты беру'),
              ),
          ],
        ),
      );
      if (!mounted || issue != true || book == null) return;
      final now = DateTime.now();
      final due = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        initialDate: now.add(const Duration(days: 14)),
        helpText: 'Қайтару күнін таңдаңыз',
      );
      if (!mounted || due == null) return;
      final current = database.getBookById(book.id);
      if (current == null ||
          !current.hasActiveReservation ||
          current.isBorrowed ||
          current.reservationCode != book.reservationCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бұл бронь енді белсенді емес.')),
        );
        return;
      }
      final saved = await widget.onBookUpdated!(
        current.copyWith(
          isReserved: false,
          reservationCode: null,
          isBorrowed: true,
          dueDate: DateTime(due.year, due.month, due.day, 23, 59, 59),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Кітап берілді.' : 'Өзгеріс сақталмады. Қайта көріңіз.',
          ),
        ),
      );
    } finally {
      processing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().authenticated) {
      return const Scaffold(
        body: Center(child: Text('Алдымен жүйеге кіріңіз.')),
      );
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Бронь QR сканері')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text('Броньды тексеру', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Броньды QR арқылы немесе кодты енгізіп тексеріңіз.'),
              const SizedBox(height: 16),
              if (camera != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1.35,
                    child: MobileScanner(
                      controller: camera!,
                      onDetect: (capture) {
                        final code = capture.barcodes
                            .map((barcode) => barcode.rawValue)
                            .whereType<String>()
                            .where((code) => code.isNotEmpty)
                            .firstOrNull;
                        if (code != null) _check(code);
                      },
                      errorBuilder: (_, error) => Center(
                        child: Text('Камера ашылмады: ${error.errorCode.name}'),
                      ),
                    ),
                  ),
                )
              else if (supported)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: theme.colorScheme.primary,
                          size: 52,
                        ),
                        if (access.state == CameraAccess.denied)
                          const Text('Рұқсат берілмеді. Қайта сұрауға болады.'),
                        if (access.state == CameraAccess.blocked)
                          const Text(
                            'Камераға рұқсатты құрылғы баптауларынан қосыңыз.',
                          ),
                        const SizedBox(height: 8),
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
                )
              else
                const Text('QR камерасы Android/iOS құрылғысында қолжетімді.'),
              const SizedBox(height: 20),
              TextField(
                controller: _code,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: _check,
                decoration: const InputDecoration(
                  labelText: 'Бронь коды',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _check(_code.text),
                child: const Text('Кодты тексеру'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

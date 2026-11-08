import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:libflow/screens/ereader_screen.dart';
import 'package:libflow/services/audio_playback_controller.dart';
import 'package:libflow/services/demo_book_service.dart';
import 'package:libflow/services/media_progress_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android decodes bundled MP3, plays, seeks, resumes and reads chapters offline',
    (tester) async {
      await DemoBookService.initialize();
      final book = DemoBookService.book!;
      final folder = await (await getTemporaryDirectory()).createTemp(
        'media_native_',
      );
      final store = MediaProgressStore(directory: () async => folder);
      final player = AudioPlaybackController(book: book, store: store);
      AudioPlaybackController? reopened;
      try {
        await player.initialize();
        expect(player.error, isNull);
        expect(player.duration.inSeconds, inInclusiveRange(40, 60));
        await player.play();
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (player.position.inMilliseconds < 1200 &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(player.playing, isTrue);
        expect(player.position.inMilliseconds, greaterThanOrEqualTo(1200));
        await player.pause();
        expect(player.playing, isFalse);
        await player.seek(const Duration(seconds: 10));
        await player.changeSpeed(1.5);
        expect(player.speed, 1.5);
        await player.pause();
        player.dispose();
        await store.load(book.id);
        reopened = AudioPlaybackController(book: book, store: store);
        await reopened.initialize();
        expect(reopened.resumePosition!.inSeconds, 10);
        await reopened.resume();
        await tester.pump(const Duration(milliseconds: 500));
        expect(reopened.position.inSeconds, greaterThanOrEqualTo(10));
        await reopened.pause();

        await tester.pumpWidget(
          MaterialApp(
            home: EReaderScreen(book: book, store: store),
          ),
        );
        for (
          var i = 0;
          i < 30 && find.byKey(const Key('reader-chapters')).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text(book.chapters.first.text), findsOneWidget);
        await tester.tap(find.byTooltip('Келесі тарау'));
        for (
          var i = 0;
          i < 20 && find.text(book.chapters[1].text).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text(book.chapters[1].text), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await store.load(book.id);
        expect((await store.load(book.id))['chapterId'], book.chapters[1].id);
      } finally {
        await tester.pumpWidget(const SizedBox());
        player.dispose();
        reopened?.dispose();
        await store.load('flush');
        await folder.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

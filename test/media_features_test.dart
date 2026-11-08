import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:libflow/models/book_model.dart';
import 'package:libflow/screens/ereader_screen.dart';
import 'package:libflow/services/audio_playback_controller.dart';
import 'package:libflow/services/media_progress_store.dart';
import 'package:libflow/widgets/audio_player_sheet.dart';

class FakeAudioEngine implements AudioEngine {
  final positionEvents = StreamController<Duration>.broadcast(sync: true);
  final durationEvents = StreamController<Duration?>.broadcast(sync: true);
  final stateEvents = StreamController<PlayerState>.broadcast(sync: true);
  bool failLoad = false, paused = true, disposed = false;
  double speed = 1;
  @override
  Duration position = Duration.zero;
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<Duration?> get durations => durationEvents.stream;
  @override
  Stream<PlayerState> get states => stateEvents.stream;
  @override
  Future<void> load(String source) async {
    if (failLoad) throw StateError('missing file');
    durationEvents.add(const Duration(seconds: 60));
    stateEvents.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> play() async {
    paused = false;
    stateEvents.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> pause() async {
    paused = true;
    stateEvents.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> seek(Duration target) async {
    position = target;
    positionEvents.add(target);
  }

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await positionEvents.close();
    await durationEvents.close();
    await stateEvents.close();
  }
}

class MemoryProgressStore extends MediaProgressStore {
  final Map<String, Map<String, dynamic>> values = {};
  @override
  Future<Map<String, dynamic>> load(String id) async =>
      Map.of(values[id] ?? {});
  @override
  Future<void> save(String id, Map<String, dynamic> fields) async {
    values[id] = {...?values[id], ...fields};
  }
}

Book mediaBook({
  String id = 'media',
  String? source = 'https://example.org/book.mp3',
}) => Book.fromMap({
  'id': id,
  'title': 'Media test',
  'author': 'Author',
  'hasEBook': true,
  'hasAudio': true,
  'audioUrl': source,
  'chapters': [
    {
      'id': 'one',
      'title': 'Бірінші тарау',
      'text': List.filled(100, 'Бірінші тараудың ұзын мәтіні.').join('\n\n'),
    },
    {'id': 'two', 'title': 'Екінші тарау', 'text': 'Екінші тараудың мәтіні.'},
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late MediaProgressStore store;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('libflow_media_');
    store = MediaProgressStore(directory: () async => folder);
  });
  tearDown(() async {
    await store.load('flush');
    folder.deleteSync(recursive: true);
  });

  test(
    'chapters/audio survive JSON roundtrip, copy and explicit audio removal',
    () {
      final book = Book.fromMap(
        jsonDecode(jsonEncode(mediaBook().toMap())) as Map<String, dynamic>,
      );
      expect(book.chapters.length, 2);
      expect(book.copyWith(title: 'Changed').chapters.first.id, 'one');
      expect(book.canRead, isTrue);
      expect(book.canListen, isTrue);
      expect(book.copyWith(audioUrl: null).canListen, isFalse);
    },
  );
  test(
    'legacy content falls back to one chapter; empty book cannot read/listen',
    () {
      final old = Book.fromMap({
        'id': 'old',
        'hasEBook': true,
        'readingContent': 'Full legacy text',
      });
      expect(old.readableChapters.single.text, 'Full legacy text');
      expect(old.canRead, isTrue);
      expect(Book.fromMap({'id': 'empty'}).canRead, isFalse);
      expect(mediaBook(source: null).canListen, isFalse);
    },
  );
  test(
    'progress survives restart, merges reading/audio and isolates book IDs',
    () async {
      await Future.wait([
        store.save('a', {'chapterId': 'two', 'scrollFraction': 0.6}),
        store.save('a', {'audioMs': 10000}),
        store.save('b', {'audioMs': 3000}),
      ]);
      final restarted = MediaProgressStore(directory: () async => folder);
      expect((await restarted.load('a'))['chapterId'], 'two');
      expect((await restarted.load('a'))['audioMs'], 10000);
      expect((await restarted.load('b'))['audioMs'], 3000);
    },
  );
  test(
    'corrupt progress reports an error instead of silently replacing data',
    () async {
      await File('${folder.path}/media_progress.json')
          .writeAsString('{invalid');
      await expectLater(store.load('a'), throwsFormatException);
      await expectLater(store.save('a', {'audioMs': 1}), throwsFormatException);
      expect(
        await File('${folder.path}/media_progress.json').readAsString(),
        '{invalid',
      );
      await File('${folder.path}/media_progress.json').writeAsString('{}');
    },
  );
  test('audio plays, pauses, clamps seeks and changes speed', () async {
    final engine = FakeAudioEngine();
    final player = AudioPlaybackController(
      book: mediaBook(),
      engine: engine,
      store: store,
    );
    await player.initialize();
    expect(player.duration.inSeconds, 60);
    await player.play();
    expect(player.playing, isTrue);
    await player.seek(const Duration(seconds: 100));
    expect(player.position.inSeconds, 60);
    await player.seek(const Duration(seconds: -10));
    expect(player.position, Duration.zero);
    await player.changeSpeed(1.5);
    expect(engine.speed, 1.5);
    await player.pause();
    expect(engine.paused, isTrue);
    player.dispose();
  });
  test(
    'audio offers persisted resume and ignores position for changed source',
    () async {
      await store.save('media', {
        'audioMs': 12000,
        'audioSource': 'https://example.org/book.mp3',
      });
      final player = AudioPlaybackController(
        book: mediaBook(),
        engine: FakeAudioEngine(),
        store: store,
      );
      await player.initialize();
      expect(player.resumePosition!.inSeconds, 12);
      await player.resume();
      expect(player.position.inSeconds, 12);
      player.dispose();
      await store.load('flush');
      final changed = AudioPlaybackController(
        book: mediaBook(source: 'https://example.org/new.mp3'),
        engine: FakeAudioEngine(),
        store: store,
      );
      await changed.initialize();
      expect(changed.resumePosition, isNull);
      changed.dispose();
    },
  );
  test(
    'completed audio restarts at zero and new book pauses previous player',
    () async {
      final firstEngine = FakeAudioEngine();
      final first = AudioPlaybackController(
        book: mediaBook(),
        engine: firstEngine,
        store: store,
      );
      await first.initialize();
      await first.play();
      firstEngine.stateEvents.add(PlayerState(true, ProcessingState.completed));
      expect(first.completed, isTrue);
      await first.play();
      expect(first.position, Duration.zero);
      final second = AudioPlaybackController(
        book: mediaBook(id: 'other'),
        engine: FakeAudioEngine(),
        store: store,
      );
      await second.initialize();
      expect(firstEngine.paused, isTrue);
      first.dispose();
      second.dispose();
    },
  );
  test(
    'audio load/network and stream errors have readable recovery state',
    () async {
      final engine = FakeAudioEngine()..failLoad = true;
      final player = AudioPlaybackController(
        book: mediaBook(),
        engine: engine,
        store: store,
      );
      await player.initialize();
      expect(player.error, contains('интернетті'));
      expect(player.loading, isFalse);
      engine.failLoad = false;
      await player.initialize();
      expect(player.error, isNull);
      engine.positionEvents.addError(StateError('connection lost'));
      expect(player.error, isNotNull);
      player.dispose();
    },
  );

  Future<void> settleDisk(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('reader changes chapters and restores chapter after reopening', (
    tester,
  ) async {
    store = MemoryProgressStore();
    await tester.pumpWidget(
      MaterialApp(
        home: EReaderScreen(book: mediaBook(), store: store),
      ),
    );
    await settleDisk(tester);
    expect(find.text('1 / 2 тарау · 0%'), findsOneWidget);
    await tester.tap(find.byTooltip('Келесі тарау'));
    await settleDisk(tester);
    expect(find.text('Екінші тараудың мәтіні.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settleDisk(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EReaderScreen(book: mediaBook(), store: store),
      ),
    );
    await settleDisk(tester);
    expect(find.text('Екінші тараудың мәтіні.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settleDisk(tester);
  });
  testWidgets(
    'reader restores scroll/font/theme; missing chapter resets safely',
    (tester) async {
      store = MemoryProgressStore();
      await tester.runAsync(
        () => store.save('media', {
          'chapterId': 'one',
          'scrollFraction': 0.5,
          'fontSize': 22,
          'readerTheme': 'dark',
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EReaderScreen(book: mediaBook(), store: store),
        ),
      );
      await settleDisk(tester);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scroll.controller!.offset,
        closeTo(scroll.controller!.position.maxScrollExtent * 0.5, 2),
      );
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .style!
            .fontSize,
        22,
      );
      await tester.pumpWidget(const SizedBox());
      await settleDisk(tester);
      await tester.runAsync(
        () => store.save('media', {
          'chapterId': 'deleted',
          'scrollFraction': 0.9,
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EReaderScreen(book: mediaBook(), store: store),
        ),
      );
      await settleDisk(tester);
      expect(find.text('1 / 2 тарау · 0%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await settleDisk(tester);
    },
  );
  testWidgets('audio sheet exposes real duration and error retry', (
    tester,
  ) async {
    store = MemoryProgressStore();
    final engine = FakeAudioEngine()..failLoad = true;
    final player = AudioPlaybackController(
      book: mediaBook(),
      engine: engine,
      store: store,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioPlayerSheet(book: mediaBook(), controller: player),
        ),
      ),
    );
    await settleDisk(tester);
    expect(find.byKey(const Key('audio-error')), findsOneWidget);
    engine.failLoad = false;
    await tester.tap(find.text('Қайта көру'));
    await settleDisk(tester);
    expect(find.text('0:00 / 1:00'), findsOneWidget);
    await tester.tap(find.byTooltip('Ойнату'));
    await tester.pump();
    expect(find.byTooltip('Кідірту'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settleDisk(tester);
  });
}

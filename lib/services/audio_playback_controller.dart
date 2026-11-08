import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/book_model.dart';
import 'app_log.dart';
import 'media_progress_store.dart';

abstract class AudioEngine {
  Stream<Duration> get positions;
  Stream<Duration?> get durations;
  Stream<PlayerState> get states;
  Duration get position;
  Future<void> load(String source);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  final AudioPlayer _player = AudioPlayer();
  @override
  Stream<Duration> get positions => _player.positionStream;
  @override
  Stream<Duration?> get durations => _player.durationStream;
  @override
  Stream<PlayerState> get states => _player.playerStateStream;
  @override
  Duration get position => _player.position;
  @override
  Future<void> load(String source) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    if (source == 'asset:assets/audio/aesop_fox_grapes.mp3') {
      await _player.setAsset('assets/audio/aesop_fox_grapes.mp3');
    } else {
      final uri = Uri.tryParse(source);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Expected HTTPS audio URL');
      }
      await _player.setUrl(source).timeout(const Duration(seconds: 25));
    }
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> dispose() => _player.dispose();
}

class AudioPlaybackController extends ChangeNotifier {
  static AudioPlaybackController? _active;
  final Book book;
  final AudioEngine engine;
  final MediaProgressStore store;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool loading = true, playing = false, completed = false;
  bool _disposed = false, _ready = false;
  String? error, progressError;
  Duration position = Duration.zero, duration = Duration.zero;
  Duration? resumePosition;
  double speed = 1;
  int _lastSavedSecond = -1;

  AudioPlaybackController({
    required this.book,
    AudioEngine? engine,
    MediaProgressStore? store,
  }) : engine = engine ?? JustAudioEngine(),
       store = store ?? MediaProgressStore.instance;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _fail(Object failure) {
    if (_disposed) return;
    loading = false;
    playing = false;
    error = 'Аудионы ашу немесе ойнату орындалмады. Файл мен интернетті тексеріп, қайта көріңіз.';
    AppLog.event('audio.failed', error: failure);
    unawaited(
      engine.pause().catchError(
        (Object e) => AppLog.event('audio.pause_failed', error: e),
      ),
    );
    _changed();
  }

  Future<void> _claim() async {
    final previous = _active;
    if (previous != null && previous != this && !previous._disposed) {
      await previous.pause();
    }
    if (!_disposed) _active = this;
  }

  Future<void> initialize() async {
    loading = true;
    _ready = false;
    resumePosition = null;
    error = null;
    _changed();
    if (_subscriptions.isEmpty) {
      _subscriptions.add(
        engine.positions.listen((value) {
          if (_disposed) return;
          position = value;
          if (_ready &&
              resumePosition == null &&
              position.inSeconds ~/ 5 != _lastSavedSecond) {
            _lastSavedSecond = position.inSeconds ~/ 5;
            unawaited(_persist());
          }
          _changed();
        }, onError: _fail),
      );
      _subscriptions.add(
        engine.durations.listen((value) {
          duration = value ?? Duration.zero;
          _changed();
        }, onError: _fail),
      );
      _subscriptions.add(
        engine.states.listen((value) {
          if (_disposed) return;
          completed = value.processingState == ProcessingState.completed;
          playing = value.playing && !completed;
          loading =
              value.processingState == ProcessingState.loading ||
              value.processingState == ProcessingState.buffering;
          if (completed) {
            position = duration;
            unawaited(_persist());
          }
          _changed();
        }, onError: _fail),
      );
    }
    try {
      if (!book.canListen) throw const FormatException('No audio');
      await _claim();
      if (_disposed) return;
      await engine.load(book.audioUrl!);
      if (_disposed) return;
      try {
        final saved = await store.load(book.id);
        final milliseconds = (saved['audioMs'] as num?)?.toInt() ?? 0;
        if (saved['audioSource'] == book.audioUrl &&
            milliseconds > 0 &&
            milliseconds < duration.inMilliseconds) {
          resumePosition = Duration(milliseconds: milliseconds);
        }
      } catch (failure) {
        _progressFailed(failure);
      }
      loading = false;
      _ready = true;
      AppLog.event('audio.loaded');
      _changed();
    } catch (failure) {
      _fail(failure);
    }
  }

  Future<void> play() async {
    if (_disposed || !_ready || loading || error != null) return;
    try {
      await _claim();
      if (_disposed) return;
      resumePosition = null;
      if (completed) await seek(Duration.zero);
      // just_audio play completes only when paused/completed; never await it in UI.
      unawaited(engine.play().catchError(_fail));
      AppLog.event('audio.play');
    } catch (failure) {
      _fail(failure);
    }
  }

  Future<void> pause() async {
    if (_disposed) return;
    try {
      await engine.pause();
      await _persist();
    } catch (failure) {
      _fail(failure);
    }
  }

  Future<void> seek(Duration target) async {
    if (_disposed) return;
    resumePosition = null;
    final ms = target.inMilliseconds.clamp(0, duration.inMilliseconds);
    try {
      await engine.seek(Duration(milliseconds: ms));
      position = Duration(milliseconds: ms);
      completed = duration > Duration.zero && position >= duration;
      await _persist();
      _changed();
    } catch (failure) {
      _fail(failure);
    }
  }

  Future<void> resume() async {
    final saved = resumePosition;
    resumePosition = null;
    if (saved != null) await seek(saved);
    await play();
  }

  Future<void> changeSpeed(double value) async {
    try {
      await engine.setSpeed(value);
      speed = value;
      _changed();
    } catch (failure) {
      _fail(failure);
    }
  }

  void _progressFailed(Object failure) {
    progressError = 'Тыңдау орны құрылғыға сақталмады.';
    AppLog.event('audio.progress_failed', error: failure);
    _changed();
  }

  Future<void> _persist() async {
    if (!_ready || resumePosition != null) return;
    try {
      await store.save(book.id, {
        'audioMs': position.inMilliseconds,
        'audioSource': book.audioUrl,
      });
    } catch (failure) {
      _progressFailed(failure);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    position = completed ? duration : engine.position;
    _disposed = true;
    if (_active == this) _active = null;
    unawaited(_persist());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(
      engine.dispose().catchError(
        (Object failure) =>
            AppLog.event('audio.dispose_failed', error: failure),
      ),
    );
    super.dispose();
  }
}

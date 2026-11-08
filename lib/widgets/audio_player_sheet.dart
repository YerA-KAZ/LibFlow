import 'dart:async';

import 'package:flutter/material.dart';

import '../models/book_model.dart';
import '../services/audio_playback_controller.dart';

class AudioPlayerSheet extends StatefulWidget {
  final Book book;
  final AudioPlaybackController? controller;
  const AudioPlayerSheet({super.key, required this.book, this.controller});
  @override
  State<AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<AudioPlayerSheet>
    with WidgetsBindingObserver {
  late final AudioPlaybackController player;
  String time(Duration v) =>
      '${v.inMinutes}:${(v.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    player = widget.controller ?? AudioPlaybackController(book: widget.book);
    unawaited(player.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(player.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: player,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.headphones_rounded, size: 48),
            Text(
              widget.book.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(widget.book.author),
            if (player.loading) const LinearProgressIndicator(),
            if (player.error != null) ...[
              Text(player.error!, key: const Key('audio-error')),
              TextButton(
                onPressed: player.initialize,
                child: const Text('Қайта көру'),
              ),
            ],
            if (player.progressError != null) Text(player.progressError!),
            if (player.resumePosition != null)
              FilledButton.tonal(
                onPressed: player.resume,
                child: Text(
                  '${time(player.resumePosition!)} жерінен жалғастыру',
                ),
              ),
            Slider(
              key: const Key('audio-seek'),
              value: player.position.inMilliseconds.toDouble().clamp(
                0,
                player.duration.inMilliseconds.toDouble(),
              ),
              max: player.duration.inMilliseconds > 0
                  ? player.duration.inMilliseconds.toDouble()
                  : 1,
              onChanged:
                  player.loading ||
                      player.error != null ||
                      player.duration == Duration.zero
                  ? null
                  : (value) =>
                        player.seek(Duration(milliseconds: value.round())),
            ),
            Text(
              '${time(player.position)} / ${time(player.duration)}',
              key: const Key('audio-time'),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: '10 секунд артқа',
                  icon: const Icon(Icons.replay_10),
                  onPressed: player.loading || player.error != null
                      ? null
                      : () => player.seek(
                          player.position - const Duration(seconds: 10),
                        ),
                ),
                IconButton.filled(
                  tooltip: player.playing ? 'Кідірту' : 'Ойнату',
                  icon: Icon(player.playing ? Icons.pause : Icons.play_arrow),
                  iconSize: 38,
                  onPressed: player.loading || player.error != null
                      ? null
                      : () => player.playing ? player.pause() : player.play(),
                ),
                IconButton(
                  tooltip: '10 секунд алға',
                  icon: const Icon(Icons.forward_10),
                  onPressed: player.loading || player.error != null
                      ? null
                      : () => player.seek(
                          player.position + const Duration(seconds: 10),
                        ),
                ),
                DropdownButton<double>(
                  value: player.speed,
                  items: [0.75, 1.0, 1.25, 1.5, 2.0]
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text('${s}x')),
                      )
                      .toList(),
                  onChanged: player.loading || player.error != null
                      ? null
                      : (v) => player.changeSpeed(v!),
                ),
              ],
            ),
            if (player.completed)
              const Text('Аудио аяқталды. Қайта тыңдау үшін Ойнату басыңыз.'),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Жабу'),
            ),
          ],
        ),
      ),
    ),
  );
}

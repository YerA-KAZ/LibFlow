import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../utils/constants.dart';

class AudioPlayerSheet extends StatefulWidget {
  final Book book;

  const AudioPlayerSheet({super.key, required this.book});

  @override
  State<AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<AudioPlayerSheet> {
  bool _isPlaying = true;
  double _currentSeconds = 120;
  final double _totalSeconds = 1800; // 30 minutes sample chapter
  double _speed = 1.0;

  String _formatTime(double seconds) {
    final int minutes = (seconds / 60).floor();
    final int remainingSeconds = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Album art / Cover
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.book.coverGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.book.coverGradient.first.withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.headphones_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Book Title & Author
          Text(
            widget.book.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.book.author,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),

          // Chapter tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(isDark ? 50 : 25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '1-тарау • Дыбысталуы: 14 сағ 20 мин',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryLight,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: Colors.grey.withAlpha(80),
              thumbColor: AppColors.accent,
            ),
            child: Slider(
              value: _currentSeconds,
              min: 0,
              max: _totalSeconds,
              onChanged: (value) {
                setState(() {
                  _currentSeconds = value;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(_currentSeconds),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  _formatTime(_totalSeconds),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Speed button
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_speed == 1.0) {
                      _speed = 1.25;
                    } else if (_speed == 1.25) {
                      _speed = 1.5;
                    } else if (_speed == 1.5) {
                      _speed = 2.0;
                    } else {
                      _speed = 1.0;
                    }
                  });
                },
                child: Text(
                  '${_speed}x',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),

              // Replay 15s
              IconButton(
                iconSize: 32,
                icon: const Icon(Icons.replay_10_rounded),
                onPressed: () {
                  setState(() {
                    _currentSeconds = (_currentSeconds - 10).clamp(0, _totalSeconds);
                  });
                },
              ),

              // Play / Pause FAB
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.accent, Colors.orangeAccent],
                  ),
                ),
                child: IconButton(
                  iconSize: 40,
                  color: Colors.white,
                  icon: Icon(_isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  onPressed: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                  },
                ),
              ),

              // Forward 15s
              IconButton(
                iconSize: 32,
                icon: const Icon(Icons.forward_10_rounded),
                onPressed: () {
                  setState(() {
                    _currentSeconds = (_currentSeconds + 10).clamp(0, _totalSeconds);
                  });
                },
              ),

              // Bookmark
              IconButton(
                iconSize: 24,
                icon: const Icon(Icons.bookmark_add_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Бетбелгі сақталды!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

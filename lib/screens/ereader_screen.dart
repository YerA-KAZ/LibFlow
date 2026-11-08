import 'dart:async';

import 'package:flutter/material.dart';

import '../models/book_model.dart';
import '../services/app_log.dart';
import '../services/media_progress_store.dart';

enum ReaderTheme { white, sepia, dark }

class EReaderScreen extends StatefulWidget {
  final Book book;
  final MediaProgressStore? store;
  const EReaderScreen({super.key, required this.book, this.store});
  @override
  State<EReaderScreen> createState() => _EReaderScreenState();
}

class _EReaderScreenState extends State<EReaderScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  late final MediaProgressStore _store;
  late final List<BookChapter> _chapters;
  int _chapter = 0;
  double _fontSize = 18, _fraction = 0;
  ReaderTheme _theme = ReaderTheme.white;
  bool _loading = true, _restoring = true;
  Timer? _timer;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = widget.store ?? MediaProgressStore.instance;
    _chapters = widget.book.readableChapters;
    _scroll.addListener(() {
      if (_restoring || !_scroll.hasClients) return;
      final extent = _scroll.position.maxScrollExtent;
      setState(
        () =>
            _fraction = extent > 0 ? (_scroll.offset / extent).clamp(0, 1) : 0,
      );
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 350), _save);
    });
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final data = await _store.load(widget.book.id);
      if (!mounted) return;
      final index = _chapters.indexWhere((c) => c.id == data['chapterId']);
      _chapter = index < 0 ? 0 : index;
      _fraction = index < 0
          ? 0
          : ((data['scrollFraction'] as num?)?.toDouble() ?? 0).clamp(0, 1);
      _fontSize = ((data['fontSize'] as num?)?.toDouble() ?? 18).clamp(12, 28);
      _theme = ReaderTheme.values.firstWhere(
        (t) => t.name == data['readerTheme'],
        orElse: () => ReaderTheme.white,
      );
    } catch (e) {
      _report(e);
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _restoreScroll();
  }

  void _restoreScroll() {
    _restoring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent * _fraction);
      }
      _restoring = false;
    });
  }

  void _report(Object e) {
    AppLog.event('reader.progress_failed', error: e);
    if (mounted) {
      setState(
        () => _error = 'Оқу орнын сақтау немесе қалпына келтіру орындалмады.',
      );
    }
  }

  Future<void> _save() async {
    if (_loading || _chapters.isEmpty) return;
    try {
      await _store.save(widget.book.id, {
        'chapterId': _chapters[_chapter].id,
        'scrollFraction': _fraction,
        'fontSize': _fontSize,
        'readerTheme': _theme.name,
      });
    } catch (e) {
      _report(e);
    }
  }

  Future<void> _select(int index) async {
    _timer?.cancel();
    await _save();
    if (!mounted) return;
    setState(() {
      _chapter = index;
      _fraction = 0;
      _restoring = true;
    });
    _restoreScroll();
    await _save();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_save());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_save());
    _scroll.dispose();
    super.dispose();
  }

  void _settings() => showModalBottomSheet<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Оқу баптаулары'),
              const Text('Қаріп өлшемі'),
              Slider(
                value: _fontSize,
                min: 12,
                max: 28,
                divisions: 16,
                label: '${_fontSize.round()}',
                onChanged: (size) {
                  setState(() => _fontSize = size);
                  update(() {});
                  _restoreScroll();
                  unawaited(_save());
                },
              ),
              Wrap(
                spacing: 8,
                children: ReaderTheme.values
                    .map(
                      (theme) => ChoiceChip(
                        label: Text(switch (theme) {
                          ReaderTheme.white => 'Ашық',
                          ReaderTheme.sepia => 'Сепия',
                          ReaderTheme.dark => 'Қараңғы',
                        }),
                        selected: _theme == theme,
                        onSelected: (_) {
                          setState(() => _theme = theme);
                          update(() {});
                          unawaited(_save());
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final bg = switch (_theme) {
      ReaderTheme.white => const Color(0xFFF9F7F2),
      ReaderTheme.sepia => const Color(0xFFF5EFDB),
      ReaderTheme.dark => const Color(0xFF131A16),
    };
    final fg = _theme == ReaderTheme.dark
        ? Colors.white
        : const Color(0xFF1E2320);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        title: Text(widget.book.title),
        actions: [
          IconButton(
            tooltip: 'Оқу баптаулары',
            onPressed: _settings,
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chapters.isEmpty
          ? const Center(child: Text('Танысуға арналған мәтін жоқ.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'ТАНЫСУ ҮЗІНДІСІ',
                    style: TextStyle(
                      color: fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                if (_error != null) Text(_error!, style: TextStyle(color: fg)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButton<int>(
                    key: const Key('reader-chapters'),
                    isExpanded: true,
                    value: _chapter,
                    dropdownColor: bg,
                    style: TextStyle(color: fg),
                    items: _chapters
                        .asMap()
                        .entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) unawaited(_select(v));
                    },
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: SelectableText(
                          _chapters[_chapter].text,
                          key: ValueKey(_chapters[_chapter].id),
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: _fontSize,
                            height: 1.8,
                            color: fg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Алдыңғы тарау',
                          color: fg,
                          onPressed: _chapter == 0
                              ? null
                              : () => _select(_chapter - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '${_chapter + 1} / ${_chapters.length} тарау · ${((_chapter + _fraction) / _chapters.length * 100).round()}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: fg),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Келесі тарау',
                          color: fg,
                          onPressed: _chapter == _chapters.length - 1
                              ? null
                              : () => _select(_chapter + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

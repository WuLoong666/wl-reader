import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/book_dao.dart';
import '../database/chapter_dao.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/reading_progress_service.dart';

class NovelReaderPage extends StatefulWidget {
  const NovelReaderPage({
    super.key,
    required this.bookId,
  });

  final int bookId;

  @override
  State<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends State<NovelReaderPage> {
  final _bookDao = BookDao();
  final _chapterDao = ChapterDao();
  final _progressService = ReadingProgressService();
  final _scrollController = ScrollController();

  Book? _book;
  List<Chapter> _chapters = const [];
  int _chapterIndex = 0;
  bool _loading = true;
  String? _error;
  double _fontSize = 18;
  double _lineHeight = 1.7;
  bool _nightMode = false;
  bool _restoredPosition = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveProgress();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    final chapter = _currentChapter;
    final colors = _ReaderColors.fromNightMode(_nightMode);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        title: Text(book?.title ?? '阅读'),
        actions: [
          IconButton(
            tooltip: '减小字号',
            onPressed: () => _updateFontSize(_fontSize - 1),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: '增大字号',
            onPressed: () => _updateFontSize(_fontSize + 1),
            icon: const Icon(Icons.text_increase),
          ),
          IconButton(
            tooltip: '夜间模式',
            onPressed: _toggleNightMode,
            icon: Icon(_nightMode ? Icons.dark_mode : Icons.light_mode),
          ),
        ],
      ),
      body: _buildBody(context, colors, chapter),
      bottomNavigationBar: _loading || chapter == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _chapterIndex <= 0
                            ? null
                            : () => _goToChapter(_chapterIndex - 1),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('上一章'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _chapterIndex >= _chapters.length - 1
                            ? null
                            : () => _goToChapter(_chapterIndex + 1),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('下一章'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    _ReaderColors colors,
    Chapter? chapter,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (chapter == null) {
      return const Center(child: Text('没有章节内容'));
    }

    _restoreScrollPositionIfNeeded();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 40.0 : 20.0;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: colors.foreground,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    chapter.content,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: _fontSize,
                      height: _lineHeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Chapter? get _currentChapter {
    if (_chapters.isEmpty || _chapterIndex < 0 || _chapterIndex >= _chapters.length) {
      return null;
    }
    return _chapters[_chapterIndex];
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final book = await _bookDao.getById(widget.bookId);
      if (book == null) {
        throw StateError('找不到这本书');
      }

      final chapters = await _chapterDao.getByBookId(widget.bookId);
      final chapterIndex = chapters.isEmpty
          ? 0
          : book.currentChapter.clamp(0, chapters.length - 1).toInt();

      if (!mounted) {
        return;
      }

      setState(() {
        _book = book;
        _chapters = chapters;
        _chapterIndex = chapterIndex;
        _fontSize = preferences.getDouble('reader_font_size') ?? 18;
        _lineHeight = preferences.getDouble('reader_line_height') ?? 1.7;
        _nightMode = preferences.getBool('reader_night_mode') ?? false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _restoreScrollPositionIfNeeded() {
    if (_restoredPosition) {
      return;
    }
    _restoredPosition = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final book = _book;
      if (!mounted || book == null || !_scrollController.hasClients) {
        return;
      }
      if (book.currentChapter != _chapterIndex || book.currentPosition <= 0) {
        return;
      }
      final maxOffset = _scrollController.position.maxScrollExtent;
      final target = math.min(book.currentPosition.toDouble(), maxOffset);
      _scrollController.jumpTo(target);
    });
  }

  Future<void> _goToChapter(int targetIndex) async {
    if (targetIndex < 0 || targetIndex >= _chapters.length) {
      return;
    }

    await _saveProgress();
    setState(() {
      _chapterIndex = targetIndex;
      _restoredPosition = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(0);
      await _saveProgress(positionOverride: 0);
    });
  }

  Future<void> _saveProgress({int? positionOverride}) async {
    final book = _book;
    if (book == null || book.id == null || _chapters.isEmpty) {
      return;
    }

    final position = positionOverride ??
        (_scrollController.hasClients ? _scrollController.offset.round() : 0);
    final progress = _calculateProgress(position);
    await _progressService.saveProgress(
      book: book,
      currentChapter: _chapterIndex,
      currentPosition: position,
      progress: progress,
    );

    _book = book.copyWith(
      currentChapter: _chapterIndex,
      currentPosition: position,
      progress: progress,
      lastReadTime: DateTime.now(),
    );
  }

  double _calculateProgress(int position) {
    if (_chapters.isEmpty) {
      return 0;
    }

    var chapterFraction = 0.0;
    if (_scrollController.hasClients) {
      final maxOffset = _scrollController.position.maxScrollExtent;
      if (maxOffset > 0) {
        chapterFraction = (position / maxOffset).clamp(0, 1).toDouble();
      }
    }
    return ((_chapterIndex + chapterFraction) / _chapters.length)
        .clamp(0, 1)
        .toDouble();
  }

  Future<void> _updateFontSize(double value) async {
    final nextValue = value.clamp(14, 30).toDouble();
    setState(() => _fontSize = nextValue);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('reader_font_size', nextValue);
  }

  Future<void> _toggleNightMode() async {
    setState(() => _nightMode = !_nightMode);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('reader_night_mode', _nightMode);
  }
}

class _ReaderColors {
  const _ReaderColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  factory _ReaderColors.fromNightMode(bool nightMode) {
    return nightMode
        ? const _ReaderColors(
            background: Color(0xFF151515),
            foreground: Color(0xFFE6E1D8),
          )
        : const _ReaderColors(
            background: Color(0xFFFFFDF7),
            foreground: Color(0xFF242424),
          );
  }
}

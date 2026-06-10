import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/book_dao.dart';
import '../database/chapter_dao.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/epub_content_block.dart';
import '../models/reader_mode.dart';
import '../services/reading_progress_service.dart';
import '../services/reading_time_service.dart';
import '../utils/epub_html_block_parser.dart';
import '../utils/text_paginator.dart';
import '../widgets/reader_bottom_menu.dart';
import '../widgets/reader_top_menu.dart';

class NovelReaderPage extends StatefulWidget {
  const NovelReaderPage({
    super.key,
    required this.bookId,
  });

  final int bookId;

  @override
  State<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends State<NovelReaderPage>
    with WidgetsBindingObserver {
  static const _fontSizeKey = 'reader_font_size';
  static const _lineHeightKey = 'reader_line_height';
  static const _pageVerticalPaddingKey = 'reader_page_vertical_padding';
  static const _pageHorizontalPaddingKey = 'reader_page_horizontal_padding';
  static const _nightModeKey = 'reader_night_mode';
  static const _backgroundIndexKey = 'reader_background_index';
  static const _readerModeKey = 'reader_mode';
  static const _legacyReaderDirectionKey = 'reader_direction';
  static const _defaultFontSize = 18.0;
  static const _defaultLineHeight = 1.6;
  static const _defaultPageVerticalPadding = 32.0;
  static const _defaultPageHorizontalPadding = 32.0;
  static const _minLineHeight = 1.2;
  static const _maxLineHeight = 2.2;
  static const _lineHeightStep = 0.1;
  static const _minPageVerticalPadding = 16.0;
  static const _maxPageVerticalPadding = 80.0;
  static const _minPageHorizontalPadding = 16.0;
  static const _maxPageHorizontalPadding = 64.0;
  static const _pagePaddingStep = 4.0;
  static const _darkBackgroundIndex = 3;
  static const _edgeTapRatio = 0.22;
  static const _wheelTurnCooldown = Duration(milliseconds: 180);

  final _bookDao = BookDao();
  final _chapterDao = ChapterDao();
  final _progressService = ReadingProgressService();
  final _readingTimeService = ReadingTimeService();
  final _pageController = PageController();
  final _scrollController = ScrollController();

  Book? _book;
  List<Chapter> _chapters = const [];
  List<String> _currentPages = const [''];
  int _chapterIndex = 0;
  int _currentPageIndex = 0;
  bool _loading = true;
  String? _error;
  double _fontSize = _defaultFontSize;
  double _lineHeight = _defaultLineHeight;
  double _pageVerticalPadding = _defaultPageVerticalPadding;
  double _pageHorizontalPadding = _defaultPageHorizontalPadding;
  bool _showReaderMenu = false;
  bool _nightMode = false;
  int _backgroundIndex = 0;
  ReaderMode _readerMode = ReaderMode.horizontalPage;
  int? _paginationHash;
  double? _pendingChapterFraction;
  double? _pendingScrollOffset;
  double? _pendingScrollFraction;
  int? _queuedPageJump;
  bool _queuedProgressSave = false;
  bool _queuedScrollRestore = false;
  DateTime? _lastWheelTurnAt;
  DateTime? _readingSessionStartedAt;
  Timer? _scrollSaveDebounce;
  Timer? _readingTimeFlushTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScrollChanged);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollSaveDebounce?.cancel();
    _readingTimeFlushTimer?.cancel();
    unawaited(_flushReadingTime(stopSession: true));
    unawaited(_saveProgress());
    _scrollController.removeListener(_handleScrollChanged);
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startReadingTimeSession();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushReadingTime(stopSession: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _currentChapter;
    final colors = _ReaderColors.resolve(
      backgroundIndex: _backgroundIndex,
      nightMode: _nightMode,
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: _buildBody(context, colors, chapter),
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
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: colors.foreground),
        ),
      );
    }

    if (chapter == null) {
      return Center(
        child: Text(
          '没有章节内容',
          style: TextStyle(color: colors.foreground),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final pageMetrics = _ReaderPageMetrics.resolve(
          constraints: constraints,
          mediaQuery: mediaQuery,
          pageVerticalPadding: _pageVerticalPadding,
          pageHorizontalPadding: _pageHorizontalPadding,
        );
        final pageTextStyle = DefaultTextStyle.of(context).style.merge(
              TextStyle(
                color: colors.foreground,
                fontSize: _fontSize,
                height: _lineHeight,
              ),
            );

        final isHorizontalPage = _readerMode == ReaderMode.horizontalPage;
        if (isHorizontalPage) {
          _ensurePagination(
            chapter: chapter,
            maxWidth: pageMetrics.textWidth,
            maxHeight: pageMetrics.textHeight,
            textStyle: pageTextStyle,
          );
        } else {
          _ensureVerticalScrollRestore();
        }

        final pages = _currentPages.isEmpty ? const [''] : _currentPages;
        final safePageIndex =
            _currentPageIndex.clamp(0, pages.length - 1).toInt();
        final progressText = isHorizontalPage
            ? '${safePageIndex + 1} / ${pages.length}'
            : '${(_currentScrollFraction() * 100).round()}%';
        final bodySize = Size(constraints.maxWidth, constraints.maxHeight);

        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              _handleReaderTap(details.localPosition, bodySize);
            },
            child: Stack(
              children: [
                if (isHorizontalPage)
                  PageView.builder(
                    key: ValueKey(_readerMode),
                    controller: _pageController,
                    scrollDirection: Axis.horizontal,
                    itemCount: pages.length,
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (context, index) {
                      return _ReaderPageContent(
                        text: pages[index],
                        textStyle: pageTextStyle,
                        metrics: pageMetrics,
                      );
                    },
                  )
                else
                  _ReaderScrollContent(
                    controller: _scrollController,
                    chapterTitle: chapter.title,
                    content: chapter.content,
                    htmlContent: chapter.htmlContent,
                    foregroundColor: colors.foreground,
                    fontSize: _fontSize,
                    lineHeight: _lineHeight,
                    pageVerticalPadding: _pageVerticalPadding,
                    pageHorizontalPadding: _pageHorizontalPadding,
                    hasNextChapter: _chapterIndex < _chapters.length - 1,
                    onNextChapter: () {
                      unawaited(_goToChapter(_chapterIndex + 1));
                    },
                  ),
                if (!_showReaderMenu)
                  _ReaderMinimalHeader(
                    title: chapter.title,
                    foregroundColor: colors.foreground,
                  ),
                if (!_showReaderMenu && isHorizontalPage)
                  _ReaderPageIndicator(
                    currentPageIndex: safePageIndex,
                    pageCount: pages.length,
                    foregroundColor: colors.foreground,
                  ),
                if (!_showReaderMenu && !isHorizontalPage)
                  _ReaderScrollIndicator(
                    progressText: progressText,
                    foregroundColor: colors.foreground,
                  ),
                if (_showReaderMenu)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: ReaderTopMenu(
                        title: chapter.title,
                        backgroundColor: colors.menuBackground,
                        foregroundColor: colors.menuForeground,
                        onBack: _handleBack,
                        onMore: () => _showSnackBar('更多功能暂未开放'),
                      ),
                    ),
                  ),
                if (_showReaderMenu)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: ReaderBottomMenu(
                        backgroundColor: colors.menuBackground,
                        foregroundColor: colors.menuForeground,
                        currentChapterIndex: _chapterIndex,
                        chapterCount: _chapters.length,
                        progressText: progressText,
                        fontSize: _fontSize,
                        isDarkMode: _nightMode,
                        readerMode: _readerMode,
                        pageVerticalPadding: _pageVerticalPadding,
                        pageHorizontalPadding: _pageHorizontalPadding,
                        lineHeight: _lineHeight,
                        onPreviousChapter: () {
                          unawaited(_goToChapter(_chapterIndex - 1));
                        },
                        onNextChapter: () {
                          unawaited(_goToChapter(_chapterIndex + 1));
                        },
                        onDecreaseFont: () {
                          unawaited(_updateFontSize(_fontSize - 1));
                        },
                        onIncreaseFont: () {
                          unawaited(_updateFontSize(_fontSize + 1));
                        },
                        onDecreasePageVerticalPadding: () {
                          unawaited(
                            _updatePageVerticalPadding(
                              _pageVerticalPadding - _pagePaddingStep,
                            ),
                          );
                        },
                        onIncreasePageVerticalPadding: () {
                          unawaited(
                            _updatePageVerticalPadding(
                              _pageVerticalPadding + _pagePaddingStep,
                            ),
                          );
                        },
                        onDecreasePageHorizontalPadding: () {
                          unawaited(
                            _updatePageHorizontalPadding(
                              _pageHorizontalPadding - _pagePaddingStep,
                            ),
                          );
                        },
                        onIncreasePageHorizontalPadding: () {
                          unawaited(
                            _updatePageHorizontalPadding(
                              _pageHorizontalPadding + _pagePaddingStep,
                            ),
                          );
                        },
                        onDecreaseLineHeight: () {
                          unawaited(
                            _updateLineHeight(_lineHeight - _lineHeightStep),
                          );
                        },
                        onIncreaseLineHeight: () {
                          unawaited(
                            _updateLineHeight(_lineHeight + _lineHeightStep),
                          );
                        },
                        onCycleBackground: () {
                          unawaited(_cycleBackground());
                        },
                        onToggleNightMode: () {
                          unawaited(_toggleNightMode());
                        },
                        onModeChanged: (mode) {
                          unawaited(_updateReaderMode(mode));
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Chapter? get _currentChapter {
    if (_chapters.isEmpty ||
        _chapterIndex < 0 ||
        _chapterIndex >= _chapters.length) {
      return null;
    }
    return _chapters[_chapterIndex];
  }

  String get _readerModeStorageKey => 'reader_mode_book_${widget.bookId}';

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
      var nightMode = preferences.getBool(_nightModeKey) ?? false;
      var backgroundIndex = preferences.getInt(_backgroundIndexKey) ??
          (nightMode ? _darkBackgroundIndex : 0);
      backgroundIndex =
          backgroundIndex.clamp(0, _ReaderColors.paletteCount - 1).toInt();
      if (backgroundIndex == _darkBackgroundIndex) {
        nightMode = true;
      }
      final readerMode = readerModeFromString(
        preferences.getString(_readerModeStorageKey) ??
            preferences.getString(_readerModeKey) ??
            preferences.getString(_legacyReaderDirectionKey),
      );
      final chapterProgress = chapters.isEmpty
          ? 0.0
          : (book.progress * chapters.length - chapterIndex)
              .clamp(0.0, 1.0)
              .toDouble();

      if (!mounted) {
        return;
      }

      setState(() {
        _book = book;
        _chapters = chapters;
        _chapterIndex = chapterIndex;
        _currentPageIndex =
            readerMode == ReaderMode.horizontalPage ? book.currentPosition : 0;
        _fontSize = (preferences.getDouble(_fontSizeKey) ?? _defaultFontSize)
            .clamp(14.0, 30.0)
            .toDouble();
        _lineHeight = _roundLineHeight(
          preferences.getDouble(_lineHeightKey) ?? _defaultLineHeight,
        );
        _pageVerticalPadding = _clampPageVerticalPadding(
          preferences.getDouble(_pageVerticalPaddingKey) ??
              _defaultPageVerticalPadding,
        );
        _pageHorizontalPadding = _clampPageHorizontalPadding(
          preferences.getDouble(_pageHorizontalPaddingKey) ??
              _defaultPageHorizontalPadding,
        );
        _nightMode = nightMode;
        _backgroundIndex = backgroundIndex;
        _readerMode = readerMode;
        _pendingScrollOffset = readerMode == ReaderMode.verticalScroll
            ? book.currentPosition.toDouble()
            : null;
        _pendingScrollFraction =
            readerMode == ReaderMode.verticalScroll && book.currentPosition <= 0
                ? chapterProgress
                : null;
        _loading = false;
      });
      _startReadingTimeSession();
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

  void _ensurePagination({
    required Chapter chapter,
    required double maxWidth,
    required double maxHeight,
    required TextStyle textStyle,
  }) {
    final paginationHash = Object.hash(
      chapter.id,
      chapter.chapterIndex,
      chapter.content.length,
      maxWidth.round(),
      maxHeight.round(),
      _fontSize,
      _lineHeight,
      _pageVerticalPadding,
      _pageHorizontalPadding,
    );

    if (_paginationHash == paginationHash && _currentPages.isNotEmpty) {
      return;
    }

    final previousPageCount = _currentPages.isEmpty ? 1 : _currentPages.length;
    final previousFraction = _pageFraction(
      pageIndex: _currentPageIndex,
      pageCount: previousPageCount,
    );
    final pages = TextPaginator.paginateText(
      content: chapter.content,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      textStyle: textStyle,
    );

    var targetPage = _currentPageIndex;
    final pendingFraction = _pendingChapterFraction;
    if (pendingFraction != null) {
      targetPage = ((pages.length - 1) * pendingFraction).round();
      _pendingChapterFraction = null;
    } else if (_paginationHash != null && previousPageCount != pages.length) {
      targetPage = ((pages.length - 1) * previousFraction).round();
    } else if (targetPage >= pages.length) {
      targetPage = _migratedPageIndexFromBookProgress(pages.length);
    }

    targetPage = targetPage.clamp(0, pages.length - 1).toInt();
    _currentPages = pages;
    _currentPageIndex = targetPage;
    _paginationHash = paginationHash;
    _queuePageJump(targetPage);
    _queueProgressSave();
  }

  Future<void> _goToChapter(
    int targetIndex, {
    double? initialPageFraction,
    double? initialScrollFraction,
  }) async {
    if (targetIndex < 0) {
      _showSnackBar('已经是第一章');
      return;
    }
    if (targetIndex >= _chapters.length) {
      _showSnackBar('已经是最后一章');
      return;
    }

    await _saveProgress();
    setState(() {
      _chapterIndex = targetIndex;
      _currentPageIndex = 0;
      _currentPages = const [''];
      _paginationHash = null;
      _pendingChapterFraction = initialPageFraction;
      _pendingScrollOffset = initialScrollFraction == null ? 0 : null;
      _pendingScrollFraction = initialScrollFraction;
    });

    if (_readerMode == ReaderMode.verticalScroll) {
      _ensureVerticalScrollRestore();
      if (initialScrollFraction == null) {
        await _saveProgress(scrollOffsetOverride: 0);
      }
      return;
    }

    if (initialPageFraction == null) {
      _queuePageJump(0);
      await _saveProgress(pageIndexOverride: 0);
    } else {
      _queueProgressSave();
    }
  }

  Future<void> _saveProgress({
    int? pageIndexOverride,
    double? scrollOffsetOverride,
  }) async {
    final book = _book;
    if (book == null || book.id == null || _chapters.isEmpty) {
      return;
    }

    final isVerticalScroll = _readerMode == ReaderMode.verticalScroll;
    final position = isVerticalScroll
        ? (scrollOffsetOverride ?? _currentScrollOffset()).round()
        : (pageIndexOverride ?? _currentPageIndex);
    final progress = isVerticalScroll
        ? _calculateScrollProgress(scrollOffsetOverride)
        : _calculatePageProgress(pageIndexOverride ?? _currentPageIndex);
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

  double _calculatePageProgress(int pageIndex) {
    if (_chapters.isEmpty) {
      return 0;
    }

    final pageCount = _currentPages.isEmpty ? 1 : _currentPages.length;
    final safePageIndex = pageIndex.clamp(0, pageCount - 1).toInt();
    final chapterFraction = pageCount <= 0 ? 0 : safePageIndex / pageCount;
    return ((_chapterIndex + chapterFraction) / _chapters.length)
        .clamp(0, 1)
        .toDouble();
  }

  double _calculateScrollProgress(double? scrollOffsetOverride) {
    if (_chapters.isEmpty) {
      return 0;
    }

    final chapterFraction = _currentScrollFraction(
      scrollOffsetOverride: scrollOffsetOverride,
    );
    return ((_chapterIndex + chapterFraction) / _chapters.length)
        .clamp(0, 1)
        .toDouble();
  }

  Future<void> _updateFontSize(double value) async {
    final nextValue = value.clamp(14, 30).toDouble();
    if ((nextValue - _fontSize).abs() < 0.1) {
      return;
    }

    final currentFraction = _currentReadingFraction();
    setState(() {
      _fontSize = nextValue;
      _markLayoutForReflow(currentFraction);
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_fontSizeKey, nextValue);
  }

  Future<void> _updateLineHeight(double value) async {
    final nextValue = _roundLineHeight(value);
    if ((nextValue - _lineHeight).abs() < 0.01) {
      return;
    }

    final currentFraction = _currentReadingFraction();
    setState(() {
      _lineHeight = nextValue;
      _markLayoutForReflow(currentFraction);
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_lineHeightKey, nextValue);
  }

  Future<void> _updatePageVerticalPadding(double value) async {
    final nextValue = _clampPageVerticalPadding(value);
    if ((nextValue - _pageVerticalPadding).abs() < 0.1) {
      return;
    }

    final currentFraction = _currentReadingFraction();
    setState(() {
      _pageVerticalPadding = nextValue;
      _markLayoutForReflow(currentFraction);
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_pageVerticalPaddingKey, nextValue);
  }

  Future<void> _updatePageHorizontalPadding(double value) async {
    final nextValue = _clampPageHorizontalPadding(value);
    if ((nextValue - _pageHorizontalPadding).abs() < 0.1) {
      return;
    }

    final currentFraction = _currentReadingFraction();
    setState(() {
      _pageHorizontalPadding = nextValue;
      _markLayoutForReflow(currentFraction);
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_pageHorizontalPaddingKey, nextValue);
  }

  double _roundLineHeight(double value) {
    final clamped = value.clamp(_minLineHeight, _maxLineHeight).toDouble();
    return (clamped * 10).roundToDouble() / 10;
  }

  double _clampPageVerticalPadding(double value) {
    return value
        .clamp(_minPageVerticalPadding, _maxPageVerticalPadding)
        .toDouble();
  }

  double _clampPageHorizontalPadding(double value) {
    return value
        .clamp(_minPageHorizontalPadding, _maxPageHorizontalPadding)
        .toDouble();
  }

  double _currentReadingFraction() {
    if (_readerMode == ReaderMode.verticalScroll) {
      return _currentScrollFraction();
    }
    return _pageFraction(
      pageIndex: _currentPageIndex,
      pageCount: _currentPages.length,
    );
  }

  void _markLayoutForReflow(double currentFraction) {
    if (_readerMode == ReaderMode.verticalScroll) {
      _pendingScrollOffset = null;
      _pendingScrollFraction = currentFraction;
    } else {
      _pendingChapterFraction = currentFraction;
    }
    _paginationHash = null;
  }

  Future<void> _toggleNightMode() async {
    setState(() {
      _nightMode = !_nightMode;
      _backgroundIndex = _nightMode ? _darkBackgroundIndex : 0;
    });
    await _saveAppearance();
  }

  Future<void> _cycleBackground() async {
    final nextIndex = (_backgroundIndex + 1) % _ReaderColors.paletteCount;
    setState(() {
      _backgroundIndex = nextIndex;
      _nightMode = nextIndex == _darkBackgroundIndex;
    });
    await _saveAppearance();
  }

  Future<void> _updateReaderMode(ReaderMode mode) async {
    if (mode == _readerMode) {
      return;
    }

    _scrollSaveDebounce?.cancel();
    if (mode == ReaderMode.verticalScroll) {
      final currentFraction = _pageFraction(
        pageIndex: _currentPageIndex,
        pageCount: _currentPages.length,
      );
      setState(() {
        _readerMode = mode;
        _pendingScrollOffset = null;
        _pendingScrollFraction = currentFraction;
      });
    } else {
      final currentFraction = _currentScrollFraction();
      setState(() {
        _readerMode = mode;
        _pendingChapterFraction = currentFraction;
        _paginationHash = null;
      });
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_readerModeKey, mode.storageValue);
    await preferences.setString(_readerModeStorageKey, mode.storageValue);

    if (mode == ReaderMode.verticalScroll) {
      _ensureVerticalScrollRestore();
    } else {
      _queueProgressSave();
    }
  }

  Future<void> _saveAppearance() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_backgroundIndexKey, _backgroundIndex);
    await preferences.setBool(_nightModeKey, _nightMode);
  }

  void _handlePageChanged(int index) {
    if (index == _currentPageIndex) {
      return;
    }

    setState(() => _currentPageIndex = index);
    unawaited(_saveProgress(pageIndexOverride: index));
  }

  void _handleScrollChanged() {
    if (_readerMode != ReaderMode.verticalScroll) {
      return;
    }

    _scrollSaveDebounce?.cancel();
    _scrollSaveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveProgress());
    });
  }

  void _ensureVerticalScrollRestore() {
    if (_queuedScrollRestore ||
        (_pendingScrollOffset == null && _pendingScrollFraction == null)) {
      return;
    }

    _queuedScrollRestore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queuedScrollRestore = false;
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      final maxOffset = position.maxScrollExtent;
      final target =
          (_pendingScrollOffset ?? maxOffset * (_pendingScrollFraction ?? 0))
              .clamp(0.0, maxOffset)
              .toDouble();
      _pendingScrollOffset = null;
      _pendingScrollFraction = null;
      _scrollController.jumpTo(target);
      unawaited(_saveProgress(scrollOffsetOverride: target));
    });
  }

  double _currentScrollOffset() {
    if (!_scrollController.hasClients) {
      return _pendingScrollOffset ?? 0;
    }
    return _scrollController.offset;
  }

  double _currentScrollFraction({double? scrollOffsetOverride}) {
    final pendingFraction = _pendingScrollFraction;
    if (!_scrollController.hasClients) {
      return pendingFraction ?? 0;
    }

    final maxOffset = _scrollController.position.maxScrollExtent;
    if (maxOffset <= 0) {
      return 0;
    }

    final offset = scrollOffsetOverride ?? _scrollController.offset;
    return (offset / maxOffset).clamp(0.0, 1.0).toDouble();
  }

  void _scrollVerticalByScreen(int direction) {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final delta = position.viewportDimension * 0.86 * direction;
    final target = (position.pixels + delta)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 1) {
      if (direction > 0 && _chapterIndex >= _chapters.length - 1) {
        _showSnackBar('已经是最后一章');
      } else if (direction < 0 && _chapterIndex <= 0) {
        _showSnackBar('已经是第一章');
      }
      return;
    }

    unawaited(
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      ),
    );
    unawaited(_saveProgress(scrollOffsetOverride: target));
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        _showReaderMenu ||
        _readerMode != ReaderMode.horizontalPage) {
      return;
    }
    final scrollDeltaY = event.scrollDelta.dy;
    if (scrollDeltaY == 0) {
      return;
    }
    final now = DateTime.now();
    final lastWheelTurnAt = _lastWheelTurnAt;
    if (lastWheelTurnAt != null &&
        now.difference(lastWheelTurnAt) < _wheelTurnCooldown) {
      return;
    }
    _lastWheelTurnAt = now;

    if (scrollDeltaY > 0) {
      _goToNextPage();
    } else if (scrollDeltaY < 0) {
      _goToPreviousPage();
    }
  }

  void _handleReaderTap(Offset position, Size size) {
    if (_showReaderMenu) {
      _toggleReaderMenu();
      return;
    }

    if (_isPreviousEdgeTap(position, size)) {
      if (_readerMode == ReaderMode.verticalScroll) {
        _scrollVerticalByScreen(-1);
      } else {
        _goToPreviousPage();
      }
      return;
    }
    if (_isNextEdgeTap(position, size)) {
      if (_readerMode == ReaderMode.verticalScroll) {
        _scrollVerticalByScreen(1);
      } else {
        _goToNextPage();
      }
      return;
    }

    _toggleReaderMenu();
  }

  bool _isPreviousEdgeTap(Offset position, Size size) {
    if (_readerMode == ReaderMode.verticalScroll) {
      return position.dy <= size.height * _edgeTapRatio;
    }
    return position.dx <= size.width * _edgeTapRatio;
  }

  bool _isNextEdgeTap(Offset position, Size size) {
    if (_readerMode == ReaderMode.verticalScroll) {
      return position.dy >= size.height * (1 - _edgeTapRatio);
    }
    return position.dx >= size.width * (1 - _edgeTapRatio);
  }

  void _goToPreviousPage() {
    if (_currentPageIndex <= 0) {
      if (_chapterIndex <= 0) {
        _showSnackBar('已经是第一章');
        return;
      }
      unawaited(_goToChapter(_chapterIndex - 1, initialPageFraction: 1));
      return;
    }
    _jumpToPage(_currentPageIndex - 1);
  }

  void _goToNextPage() {
    final pageCount = _currentPages.isEmpty ? 1 : _currentPages.length;
    if (_currentPageIndex >= pageCount - 1) {
      if (_chapterIndex >= _chapters.length - 1) {
        _showSnackBar('已经是最后一章');
        return;
      }
      unawaited(_goToChapter(_chapterIndex + 1));
      return;
    }
    _jumpToPage(_currentPageIndex + 1);
  }

  void _jumpToPage(int pageIndex) {
    final pageCount = _currentPages.isEmpty ? 1 : _currentPages.length;
    final safePageIndex = pageIndex.clamp(0, pageCount - 1).toInt();
    if (safePageIndex == _currentPageIndex) {
      return;
    }
    if (_pageController.hasClients) {
      unawaited(
        _pageController.animateToPage(
          safePageIndex,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    } else {
      _queuePageJump(safePageIndex);
    }
    setState(() => _currentPageIndex = safePageIndex);
    unawaited(_saveProgress(pageIndexOverride: safePageIndex));
  }

  void _handleBack() {
    unawaited(_flushReadingTime(stopSession: true));
    unawaited(_saveProgress());
    unawaited(Navigator.of(context).maybePop());
  }

  void _startReadingTimeSession() {
    if (_book == null) {
      return;
    }
    _readingSessionStartedAt ??= DateTime.now();
    _readingTimeFlushTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        unawaited(_flushReadingTime());
      },
    );
  }

  Future<void> _flushReadingTime({bool stopSession = false}) async {
    final startedAt = _readingSessionStartedAt;
    if (startedAt == null) {
      return;
    }

    final now = DateTime.now();
    _readingSessionStartedAt = stopSession ? null : now;
    await _readingTimeService.addElapsed(
      now.difference(startedAt),
      bookId: _book?.id,
    );
  }

  void _toggleReaderMenu() {
    setState(() => _showReaderMenu = !_showReaderMenu);
  }

  void _queuePageJump(int pageIndex) {
    if (_queuedPageJump == pageIndex) {
      return;
    }
    _queuedPageJump = pageIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _queuedPageJump;
      _queuedPageJump = null;
      if (!mounted || target == null || !_pageController.hasClients) {
        return;
      }
      final pageCount = _currentPages.isEmpty ? 1 : _currentPages.length;
      final safeTarget = target.clamp(0, pageCount - 1).toInt();
      _pageController.jumpToPage(safeTarget);
    });
  }

  void _queueProgressSave() {
    if (_queuedProgressSave) {
      return;
    }
    _queuedProgressSave = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queuedProgressSave = false;
      if (!mounted) {
        return;
      }
      unawaited(_saveProgress());
    });
  }

  int _migratedPageIndexFromBookProgress(int pageCount) {
    final book = _book;
    if (book == null ||
        book.currentChapter != _chapterIndex ||
        book.progress <= 0 ||
        _chapters.isEmpty) {
      return _currentPageIndex;
    }

    final chapterProgress = (book.progress * _chapters.length - _chapterIndex)
        .clamp(0.0, 1.0)
        .toDouble();
    return (chapterProgress * pageCount).floor();
  }

  double _pageFraction({
    required int pageIndex,
    required int pageCount,
  }) {
    if (pageCount <= 1) {
      return 0;
    }
    return (pageIndex / (pageCount - 1)).clamp(0, 1).toDouble();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ReaderColors {
  const _ReaderColors({
    required this.background,
    required this.foreground,
    required this.menuBackground,
    required this.menuForeground,
  });

  static const _palettes = [
    _ReaderPalette(
      background: Color(0xFFFFFDF7),
      foreground: Color(0xFF242424),
      menuBackground: Color(0xFFFFFDF7),
      menuForeground: Color(0xFF242424),
    ),
    _ReaderPalette(
      background: Color(0xFFFFF3D6),
      foreground: Color(0xFF2B2418),
      menuBackground: Color(0xFFFFF3D6),
      menuForeground: Color(0xFF2B2418),
    ),
    _ReaderPalette(
      background: Color(0xFFEAF6EA),
      foreground: Color(0xFF1F2B20),
      menuBackground: Color(0xFFEAF6EA),
      menuForeground: Color(0xFF1F2B20),
    ),
    _ReaderPalette(
      background: Color(0xFF151515),
      foreground: Color(0xFFE6E1D8),
      menuBackground: Color(0xFF202020),
      menuForeground: Color(0xFFE6E1D8),
    ),
  ];

  static int get paletteCount => _palettes.length;

  final Color background;
  final Color foreground;
  final Color menuBackground;
  final Color menuForeground;

  factory _ReaderColors.resolve({
    required int backgroundIndex,
    required bool nightMode,
  }) {
    final palette = nightMode
        ? _palettes[_NovelReaderPageState._darkBackgroundIndex]
        : _palettes[backgroundIndex.clamp(0, _palettes.length - 1).toInt()];
    return _ReaderColors(
      background: palette.background,
      foreground: palette.foreground,
      menuBackground: palette.menuBackground,
      menuForeground: palette.menuForeground,
    );
  }
}

class _ReaderPalette {
  const _ReaderPalette({
    required this.background,
    required this.foreground,
    required this.menuBackground,
    required this.menuForeground,
  });

  final Color background;
  final Color foreground;
  final Color menuBackground;
  final Color menuForeground;
}

class _ReaderPageMetrics {
  const _ReaderPageMetrics({
    required this.readerWidth,
    required this.viewportHeight,
    required this.contentPadding,
  });

  static const _maxReaderWidth = 880.0;
  static const _minTextWidth = 120.0;
  static const _minTextHeight = 160.0;

  final double readerWidth;
  final double viewportHeight;
  final EdgeInsets contentPadding;

  double get textWidth => math.max(
        _minTextWidth,
        readerWidth - contentPadding.left - contentPadding.right,
      );

  double get textHeight => math.max(
        _minTextHeight,
        viewportHeight - contentPadding.top - contentPadding.bottom,
      );

  factory _ReaderPageMetrics.resolve({
    required BoxConstraints constraints,
    required MediaQueryData mediaQuery,
    required double pageVerticalPadding,
    required double pageHorizontalPadding,
  }) {
    final readerWidth = math.min(constraints.maxWidth, _maxReaderWidth);
    final topPadding = mediaQuery.padding.top + pageVerticalPadding + 16;
    final bottomPadding = mediaQuery.padding.bottom + pageVerticalPadding + 48;

    return _ReaderPageMetrics(
      readerWidth: readerWidth,
      viewportHeight: constraints.maxHeight,
      contentPadding: EdgeInsets.fromLTRB(
        pageHorizontalPadding,
        topPadding,
        pageHorizontalPadding,
        bottomPadding,
      ),
    );
  }
}

class _ReaderPageContent extends StatelessWidget {
  const _ReaderPageContent({
    required this.text,
    required this.textStyle,
    required this.metrics,
  });

  final String text;
  final TextStyle textStyle;
  final _ReaderPageMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: metrics.readerWidth),
        child: Padding(
          padding: metrics.contentPadding,
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              text,
              style: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderScrollContent extends StatelessWidget {
  const _ReaderScrollContent({
    required this.controller,
    required this.chapterTitle,
    required this.content,
    required this.htmlContent,
    required this.foregroundColor,
    required this.fontSize,
    required this.lineHeight,
    required this.pageVerticalPadding,
    required this.pageHorizontalPadding,
    required this.hasNextChapter,
    required this.onNextChapter,
  });

  final ScrollController controller;
  final String chapterTitle;
  final String content;
  final String htmlContent;
  final Color foregroundColor;
  final double fontSize;
  final double lineHeight;
  final double pageVerticalPadding;
  final double pageHorizontalPadding;
  final bool hasNextChapter;
  final VoidCallback onNextChapter;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final blocks = EpubHtmlBlockParser.parse(
      html: htmlContent,
      fallbackPlainText: content,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            pageHorizontalPadding,
            mediaQuery.padding.top + pageVerticalPadding + 24,
            pageHorizontalPadding,
            mediaQuery.padding.bottom + pageVerticalPadding + 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapterTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 18),
              for (final block in blocks)
                _EpubContentBlockView(
                  block: block,
                  foregroundColor: foregroundColor,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                ),
              const SizedBox(height: 28),
              _ChapterEndPanel(
                foregroundColor: foregroundColor,
                hasNextChapter: hasNextChapter,
                onNextChapter: onNextChapter,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpubContentBlockView extends StatelessWidget {
  const _EpubContentBlockView({
    required this.block,
    required this.foregroundColor,
    required this.fontSize,
    required this.lineHeight,
  });

  final EpubContentBlock block;
  final Color foregroundColor;
  final double fontSize;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      EpubContentBlockType.heading => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 14),
          child: Text(
            block.content,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
          ),
        ),
      EpubContentBlockType.image => _EpubImageBlock(
          path: block.content,
          foregroundColor: foregroundColor,
        ),
      EpubContentBlockType.divider => Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Divider(color: foregroundColor.withAlpha(80)),
        ),
      EpubContentBlockType.text => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.content,
            style: TextStyle(
              color: foregroundColor,
              fontSize: fontSize,
              height: lineHeight,
            ),
          ),
        ),
    };
  }
}

class _EpubImageBlock extends StatelessWidget {
  const _EpubImageBlock({
    required this.path,
    required this.foregroundColor,
  });

  final String path;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return _MissingEpubImagePlaceholder(foregroundColor: foregroundColor);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Image.file(
          file,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _MissingEpubImagePlaceholder(
              foregroundColor: foregroundColor,
            );
          },
        ),
      ),
    );
  }
}

class _MissingEpubImagePlaceholder extends StatelessWidget {
  const _MissingEpubImagePlaceholder({
    required this.foregroundColor,
  });

  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        border: Border.all(color: foregroundColor.withAlpha(80)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: foregroundColor.withAlpha(150),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            '图片无法显示',
            style: TextStyle(
              color: foregroundColor.withAlpha(170),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterEndPanel extends StatelessWidget {
  const _ChapterEndPanel({
    required this.foregroundColor,
    required this.hasNextChapter,
    required this.onNextChapter,
  });

  final Color foregroundColor;
  final bool hasNextChapter;
  final VoidCallback onNextChapter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 72),
        child: Column(
          children: [
            Text(
              hasNextChapter ? '本章已结束' : '已经是最后一章',
              style: TextStyle(
                color: foregroundColor.withAlpha(170),
                fontSize: 14,
              ),
            ),
            if (hasNextChapter) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onNextChapter,
                icon: const Icon(Icons.arrow_downward),
                label: const Text('下一章'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReaderMinimalHeader extends StatelessWidget {
  const _ReaderMinimalHeader({
    required this.title,
    required this.foregroundColor,
  });

  final String title;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foregroundColor.withAlpha(170),
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderPageIndicator extends StatelessWidget {
  const _ReaderPageIndicator({
    required this.currentPageIndex,
    required this.pageCount,
    required this.foregroundColor,
  });

  final int currentPageIndex;
  final int pageCount;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              '${currentPageIndex + 1} / $pageCount',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foregroundColor.withAlpha(160),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderScrollIndicator extends StatelessWidget {
  const _ReaderScrollIndicator({
    required this.progressText,
    required this.foregroundColor,
  });

  final String progressText;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              '连续阅读 $progressText',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foregroundColor.withAlpha(160),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

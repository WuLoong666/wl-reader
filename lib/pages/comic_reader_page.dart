import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/book_dao.dart';
import '../models/book.dart';
import '../models/reader_mode.dart';
import '../services/reading_progress_service.dart';
import '../services/reading_time_service.dart';
import '../utils/natural_sort.dart';
import '../widgets/reader_top_menu.dart';

class ComicReaderPage extends StatefulWidget {
  const ComicReaderPage({
    super.key,
    required this.bookId,
  });

  final int bookId;

  @override
  State<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends State<ComicReaderPage>
    with WidgetsBindingObserver {
  static const _nightModeKey = 'reader_night_mode';
  static const _backgroundIndexKey = 'reader_background_index';
  static const _readerModeKey = 'reader_mode';
  static const _legacyReaderDirectionKey = 'reader_direction';
  static const _darkBackgroundIndex = 3;
  static const _wheelTurnCooldown = Duration(milliseconds: 180);
  static const _pageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
  };

  final _bookDao = BookDao();
  final _progressService = ReadingProgressService();
  final _readingTimeService = ReadingTimeService();
  final _pageController = PageController();
  final _scrollController = ScrollController();

  Book? _book;
  List<String> _pagePaths = const [];
  List<GlobalKey> _pageKeys = const [];
  int _currentPageIndex = 0;
  bool _loading = true;
  String? _error;
  bool _showReaderMenu = false;
  bool _nightMode = false;
  int _backgroundIndex = 0;
  ReaderMode _readerMode = ReaderMode.horizontalPage;
  int? _queuedPageJump;
  bool _queuedVerticalRestore = false;
  DateTime? _lastWheelTurnAt;
  DateTime? _readingSessionStartedAt;
  Timer? _scrollSaveDebounce;
  Timer? _readingTimeFlushTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleVerticalScrollChanged);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollSaveDebounce?.cancel();
    _readingTimeFlushTimer?.cancel();
    unawaited(_flushReadingTime(stopSession: true));
    unawaited(_saveProgress());
    _scrollController.removeListener(_handleVerticalScrollChanged);
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
    final colors = _ComicReaderColors.resolve(
      backgroundIndex: _backgroundIndex,
      nightMode: _nightMode,
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(_ComicReaderColors colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.foreground),
          ),
        ),
      );
    }

    if (_pagePaths.isEmpty) {
      return Center(
        child: Text(
          '没有可阅读的漫画图片',
          style: TextStyle(color: colors.foreground),
        ),
      );
    }

    final title = _book?.title ?? '漫画';
    final pageCount = _pagePaths.length;
    final safePageIndex = _safePageIndex(_currentPageIndex);

    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleReaderMenu,
        child: Stack(
          children: [
            if (_readerMode == ReaderMode.horizontalPage)
              _buildHorizontalReader(colors)
            else
              _buildVerticalReader(colors),
            if (!_showReaderMenu)
              _ComicMinimalHeader(
                title: title,
                foregroundColor: colors.foreground,
              ),
            if (!_showReaderMenu)
              _ComicPageIndicator(
                currentPageIndex: safePageIndex,
                pageCount: pageCount,
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
                    title: title,
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
                  child: _ComicBottomMenu(
                    backgroundColor: colors.menuBackground,
                    foregroundColor: colors.menuForeground,
                    currentPageIndex: safePageIndex,
                    pageCount: pageCount,
                    readerMode: _readerMode,
                    isDarkMode: _nightMode,
                    onPreviousPage: _goToPreviousPage,
                    onNextPage: _goToNextPage,
                    onPreviewPage: _previewPageFromSlider,
                    onJumpToPage: _jumpToPage,
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
  }

  Widget _buildHorizontalReader(_ComicReaderColors colors) {
    return PageView.builder(
      key: const ValueKey('comic-horizontal-reader'),
      controller: _pageController,
      itemCount: _pagePaths.length,
      onPageChanged: _handleHorizontalPageChanged,
      itemBuilder: (context, index) {
        return _ComicPageImage(
          filePath: _pagePaths[index],
          backgroundColor: colors.background,
        );
      },
    );
  }

  Widget _buildVerticalReader(_ComicReaderColors colors) {
    final mediaQuery = MediaQuery.of(context);
    return ListView.builder(
      key: const ValueKey('comic-vertical-reader'),
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        0,
        mediaQuery.padding.top + 8,
        0,
        mediaQuery.padding.bottom + 96,
      ),
      itemCount: _pagePaths.length,
      itemBuilder: (context, index) {
        return KeyedSubtree(
          key: _pageKeys[index],
          child: _ComicStripImage(
            filePath: _pagePaths[index],
            backgroundColor: colors.background,
          ),
        );
      },
    );
  }

  String get _readerModeStorageKey => 'reader_mode_book_${widget.bookId}';

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final book = await _bookDao.getById(widget.bookId);
      if (book == null) {
        throw StateError('找不到这本漫画');
      }
      if (book.bookType != BookType.comic) {
        throw StateError('这本书不是漫画类型');
      }

      final pagePaths = await _loadComicPages(book);
      if (pagePaths.isEmpty) {
        throw StateError('漫画目录中没有可阅读的图片');
      }

      var nightMode = preferences.getBool(_nightModeKey) ?? false;
      var backgroundIndex = preferences.getInt(_backgroundIndexKey) ??
          (nightMode ? _darkBackgroundIndex : 0);
      backgroundIndex =
          backgroundIndex.clamp(0, _ComicReaderColors.paletteCount - 1).toInt();
      if (backgroundIndex == _darkBackgroundIndex) {
        nightMode = true;
      }
      final readerMode = readerModeFromString(
        preferences.getString(_readerModeStorageKey) ??
            preferences.getString(_readerModeKey) ??
            preferences.getString(_legacyReaderDirectionKey),
      );
      final pageIndex =
          book.currentPosition.clamp(0, pagePaths.length - 1).toInt();

      if (!mounted) {
        return;
      }

      setState(() {
        _book = book;
        _pagePaths = pagePaths;
        _pageKeys = List.generate(pagePaths.length, (_) => GlobalKey());
        _currentPageIndex = pageIndex;
        _nightMode = nightMode;
        _backgroundIndex = backgroundIndex;
        _readerMode = readerMode;
        _loading = false;
      });

      if (readerMode == ReaderMode.horizontalPage) {
        _queuePageJump(pageIndex);
      } else {
        _queueVerticalRestore(pageIndex);
      }
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

  Future<List<String>> _loadComicPages(Book book) async {
    final directory = Directory(book.filePath);
    if (!await directory.exists()) {
      throw FileSystemException('漫画文件目录不存在', book.filePath);
    }

    final pageFiles = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && _isSupportedPageFile(entity)) {
        pageFiles.add(entity);
      }
    }

    pageFiles.sort(
      (left, right) => naturalCompare(
        p.basename(left.path),
        p.basename(right.path),
      ),
    );
    return pageFiles.map((file) => file.path).toList(growable: false);
  }

  bool _isSupportedPageFile(File file) {
    final name = p.basename(file.path);
    if (name.startsWith('.') || name == '.DS_Store') {
      return false;
    }
    return _pageExtensions.contains(p.extension(name).toLowerCase());
  }

  Future<void> _saveProgress({int? pageIndexOverride}) async {
    final book = _book;
    if (book == null || book.id == null || _pagePaths.isEmpty) {
      return;
    }

    final pageIndex = _safePageIndex(pageIndexOverride ?? _currentPageIndex);
    final progress = _calculatePageProgress(pageIndex);
    await _progressService.saveProgress(
      book: book,
      currentChapter: 0,
      currentPosition: pageIndex,
      progress: progress,
    );

    _book = book.copyWith(
      currentChapter: 0,
      currentPosition: pageIndex,
      progress: progress,
      lastReadTime: DateTime.now(),
    );
  }

  double _calculatePageProgress(int pageIndex) {
    if (_pagePaths.isEmpty) {
      return 0;
    }
    if (_pagePaths.length <= 1) {
      return 1;
    }
    return (pageIndex / (_pagePaths.length - 1)).clamp(0, 1).toDouble();
  }

  Future<void> _updateReaderMode(ReaderMode mode) async {
    if (mode == _readerMode) {
      return;
    }

    _scrollSaveDebounce?.cancel();
    final pageIndex = _safePageIndex(_currentPageIndex);
    setState(() => _readerMode = mode);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_readerModeKey, mode.storageValue);
    await preferences.setString(_readerModeStorageKey, mode.storageValue);

    if (mode == ReaderMode.horizontalPage) {
      _queuePageJump(pageIndex);
    } else {
      _queueVerticalRestore(pageIndex);
    }
    unawaited(_saveProgress(pageIndexOverride: pageIndex));
  }

  Future<void> _toggleNightMode() async {
    setState(() {
      _nightMode = !_nightMode;
      _backgroundIndex = _nightMode ? _darkBackgroundIndex : 0;
    });
    await _saveAppearance();
  }

  Future<void> _cycleBackground() async {
    final nextIndex = (_backgroundIndex + 1) % _ComicReaderColors.paletteCount;
    setState(() {
      _backgroundIndex = nextIndex;
      _nightMode = nextIndex == _darkBackgroundIndex;
    });
    await _saveAppearance();
  }

  Future<void> _saveAppearance() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_backgroundIndexKey, _backgroundIndex);
    await preferences.setBool(_nightModeKey, _nightMode);
  }

  void _handleHorizontalPageChanged(int index) {
    if (index == _currentPageIndex) {
      return;
    }

    setState(() => _currentPageIndex = index);
    unawaited(_saveProgress(pageIndexOverride: index));
  }

  void _handleVerticalScrollChanged() {
    if (_readerMode != ReaderMode.verticalScroll) {
      return;
    }

    final visiblePageIndex = _visibleVerticalPageIndex();
    if (visiblePageIndex != null && visiblePageIndex != _currentPageIndex) {
      setState(() => _currentPageIndex = visiblePageIndex);
    }

    _scrollSaveDebounce?.cancel();
    _scrollSaveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveProgress());
    });
  }

  int? _visibleVerticalPageIndex() {
    if (!mounted || _pageKeys.isEmpty) {
      return null;
    }

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final viewportCenter = viewportHeight / 2;
    var bestDistance = double.infinity;
    int? bestIndex;

    for (var index = 0; index < _pageKeys.length; index += 1) {
      final pageContext = _pageKeys[index].currentContext;
      final renderObject = pageContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }

      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      if (bottom < 0 || top > viewportHeight) {
        continue;
      }

      final center = top + renderObject.size.height / 2;
      final distance = (center - viewportCenter).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }

    return bestIndex;
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
    } else {
      _goToPreviousPage();
    }
  }

  void _previewPageFromSlider(int pageIndex) {
    setState(() => _currentPageIndex = _safePageIndex(pageIndex));
  }

  void _goToPreviousPage() {
    if (_currentPageIndex <= 0) {
      _showSnackBar('已经是第一页');
      return;
    }
    _jumpToPage(_currentPageIndex - 1);
  }

  void _goToNextPage() {
    if (_currentPageIndex >= _pagePaths.length - 1) {
      _showSnackBar('已经是最后一页');
      return;
    }
    _jumpToPage(_currentPageIndex + 1);
  }

  void _jumpToPage(int pageIndex) {
    final safePageIndex = _safePageIndex(pageIndex);
    if (_readerMode == ReaderMode.horizontalPage) {
      _jumpHorizontalToPage(safePageIndex);
    } else {
      _jumpVerticalToPage(safePageIndex);
    }
  }

  void _jumpHorizontalToPage(int pageIndex) {
    if (_pageController.hasClients) {
      unawaited(
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    } else {
      _queuePageJump(pageIndex);
    }
    setState(() => _currentPageIndex = pageIndex);
    unawaited(_saveProgress(pageIndexOverride: pageIndex));
  }

  void _jumpVerticalToPage(int pageIndex, {bool saveProgress = true}) {
    final pageContext = _pageKeys[pageIndex].currentContext;
    if (pageContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          pageContext,
          alignment: 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    } else if (_scrollController.hasClients) {
      final maxOffset = _scrollController.position.maxScrollExtent;
      final target = _pagePaths.length <= 1
          ? 0.0
          : maxOffset * pageIndex / (_pagePaths.length - 1);
      unawaited(
        _scrollController.animateTo(
          target.clamp(0.0, maxOffset).toDouble(),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    } else {
      _queueVerticalRestore(pageIndex);
    }

    setState(() => _currentPageIndex = pageIndex);
    if (saveProgress) {
      unawaited(_saveProgress(pageIndexOverride: pageIndex));
    }
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
      _pageController.jumpToPage(_safePageIndex(target));
    });
  }

  void _queueVerticalRestore(int pageIndex) {
    if (_queuedVerticalRestore) {
      return;
    }

    _queuedVerticalRestore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queuedVerticalRestore = false;
      if (!mounted || _readerMode != ReaderMode.verticalScroll) {
        return;
      }
      _jumpVerticalToPage(_safePageIndex(pageIndex), saveProgress: false);

      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted || _readerMode != ReaderMode.verticalScroll) {
          return;
        }
        _jumpVerticalToPage(_safePageIndex(pageIndex), saveProgress: false);
      });
    });
  }

  int _safePageIndex(int pageIndex) {
    if (_pagePaths.isEmpty) {
      return 0;
    }
    return pageIndex.clamp(0, _pagePaths.length - 1).toInt();
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

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ComicReaderColors {
  const _ComicReaderColors({
    required this.background,
    required this.foreground,
    required this.menuBackground,
    required this.menuForeground,
  });

  static const _palettes = [
    _ComicReaderPalette(
      background: Color(0xFFFFFDF7),
      foreground: Color(0xFF242424),
      menuBackground: Color(0xFFFFFDF7),
      menuForeground: Color(0xFF242424),
    ),
    _ComicReaderPalette(
      background: Color(0xFFFFF3D6),
      foreground: Color(0xFF2B2418),
      menuBackground: Color(0xFFFFF3D6),
      menuForeground: Color(0xFF2B2418),
    ),
    _ComicReaderPalette(
      background: Color(0xFFEAF6EA),
      foreground: Color(0xFF1F2B20),
      menuBackground: Color(0xFFEAF6EA),
      menuForeground: Color(0xFF1F2B20),
    ),
    _ComicReaderPalette(
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

  factory _ComicReaderColors.resolve({
    required int backgroundIndex,
    required bool nightMode,
  }) {
    final palette = nightMode
        ? _palettes[_ComicReaderPageState._darkBackgroundIndex]
        : _palettes[backgroundIndex.clamp(0, _palettes.length - 1).toInt()];
    return _ComicReaderColors(
      background: palette.background,
      foreground: palette.foreground,
      menuBackground: palette.menuBackground,
      menuForeground: palette.menuForeground,
    );
  }
}

class _ComicReaderPalette {
  const _ComicReaderPalette({
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

class _ComicPageImage extends StatelessWidget {
  const _ComicPageImage({
    required this.filePath,
    required this.backgroundColor,
  });

  final String filePath;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const _ComicImageError(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComicStripImage extends StatelessWidget {
  const _ComicStripImage({
    required this.filePath,
    required this.backgroundColor,
  });

  final String filePath;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            constrained: false,
            minScale: 1,
            maxScale: 4,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Image.file(
                file,
                width: constraints.maxWidth,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, __, ___) => const _ComicImageError(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComicImageError extends StatelessWidget {
  const _ComicImageError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Icon(Icons.broken_image_outlined, size: 40),
      ),
    );
  }
}

class _ComicMinimalHeader extends StatelessWidget {
  const _ComicMinimalHeader({
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

class _ComicPageIndicator extends StatelessWidget {
  const _ComicPageIndicator({
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

class _ComicBottomMenu extends StatelessWidget {
  const _ComicBottomMenu({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.currentPageIndex,
    required this.pageCount,
    required this.readerMode,
    required this.isDarkMode,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPreviewPage,
    required this.onJumpToPage,
    required this.onCycleBackground,
    required this.onToggleNightMode,
    required this.onModeChanged,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final int currentPageIndex;
  final int pageCount;
  final ReaderMode readerMode;
  final bool isDarkMode;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final ValueChanged<int> onPreviewPage;
  final ValueChanged<int> onJumpToPage;
  final VoidCallback onCycleBackground;
  final VoidCallback onToggleNightMode;
  final ValueChanged<ReaderMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final sliderMax = math.max(1, pageCount - 1).toDouble();
    final sliderValue =
        currentPageIndex.toDouble().clamp(0.0, sliderMax).toDouble();

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: isDarkMode
            ? const ColorScheme.dark(primary: Color(0xFFE6E1D8))
            : const ColorScheme.light(primary: Color(0xFF2F6F6D)),
      ),
      child: Container(
        color: backgroundColor.withAlpha(238),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '上一页',
                      color: foregroundColor,
                      onPressed: currentPageIndex <= 0 ? null : onPreviousPage,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${currentPageIndex + 1} / $pageCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: foregroundColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '下一页',
                      color: foregroundColor,
                      onPressed:
                          currentPageIndex >= pageCount - 1 ? null : onNextPage,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Slider(
                  min: 0,
                  max: sliderMax,
                  divisions: pageCount > 1 ? pageCount - 1 : null,
                  value: sliderValue,
                  label: '${currentPageIndex + 1}',
                  onChanged: pageCount > 1
                      ? (value) => onPreviewPage(value.round())
                      : null,
                  onChangeEnd: pageCount > 1
                      ? (value) => onJumpToPage(value.round())
                      : null,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<ReaderMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ReaderMode.horizontalPage,
                            icon: Icon(Icons.view_carousel_outlined),
                            label: Text('横向'),
                          ),
                          ButtonSegment(
                            value: ReaderMode.verticalScroll,
                            icon: Icon(Icons.view_stream_outlined),
                            label: Text('竖向'),
                          ),
                        ],
                        selected: {readerMode},
                        onSelectionChanged: (selection) {
                          onModeChanged(selection.first);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '背景',
                      color: foregroundColor,
                      onPressed: onCycleBackground,
                      icon: const Icon(Icons.palette_outlined),
                    ),
                    IconButton(
                      tooltip: isDarkMode ? '关闭夜间模式' : '夜间模式',
                      color: foregroundColor,
                      onPressed: onToggleNightMode,
                      icon: Icon(
                        isDarkMode
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

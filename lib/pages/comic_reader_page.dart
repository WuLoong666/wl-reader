import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/book_dao.dart';
import '../models/book.dart';
import '../models/comic_display_page.dart';
import '../models/reader_mode.dart';
import '../services/comic_page_splitter.dart';
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
  static const _comicReaderModeKey = 'comic_reader_mode';
  static const _comicAutoSplitWidePagesKey = 'comic_auto_split_wide_pages';
  static const _comicReadingDirectionKey = 'comic_reading_direction';
  static const _darkBackgroundIndex = 3;
  static const _wheelTurnCooldown = Duration(milliseconds: 180);
  static const _verticalPageSpacing = 4.0;
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
  final _pageController = PageController(viewportFraction: 1.0);
  final _scrollController = ScrollController();

  Book? _book;
  List<String> _pagePaths = const [];
  List<ComicDisplayPage> _displayPages = const [];
  List<GlobalKey> _pageKeys = const [];
  Directory? _splitCacheDir;
  int _currentPageIndex = 0;
  bool _loading = true;
  String? _error;
  bool _showReaderMenu = false;
  bool _nightMode = false;
  int _backgroundIndex = 0;
  ReaderMode _readerMode = ReaderMode.horizontalPage;
  bool _autoSplitWidePages = false;
  ComicReadingDirection _comicReadingDirection =
      ComicReadingDirection.rightToLeft;
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

    if (_displayPages.isEmpty) {
      return Center(
        child: Text(
          '没有可阅读的漫画图片',
          style: TextStyle(color: colors.foreground),
        ),
      );
    }

    final title = _book?.title ?? '漫画';
    final pageCount = _displayPages.length;
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
                    autoSplitWidePages: _autoSplitWidePages,
                    readingDirection: _comicReadingDirection,
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
                    onAutoSplitWidePagesChanged: (value) {
                      unawaited(_updateAutoSplitWidePages(value));
                    },
                    onReadingDirectionChanged: (direction) {
                      unawaited(_updateComicReadingDirection(direction));
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
      physics: const PageScrollPhysics(),
      pageSnapping: true,
      allowImplicitScrolling: false,
      clipBehavior: Clip.hardEdge,
      itemCount: _displayPages.length,
      onPageChanged: _handleHorizontalPageChanged,
      itemBuilder: (context, index) {
        return _ComicPageImage(
          filePath: _displayPages[index].imagePath,
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
      itemCount: _displayPages.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                index == _displayPages.length - 1 ? 0 : _verticalPageSpacing,
          ),
          child: KeyedSubtree(
            key: _pageKeys[index],
            child: _ComicStripImage(
              filePath: _displayPages[index].imagePath,
              backgroundColor: colors.background,
            ),
          ),
        );
      },
    );
  }

  String get _readerModeStorageKey => 'comic_reader_mode_book_${widget.bookId}';

  String get _legacyReaderModeStorageKey => 'reader_mode_book_${widget.bookId}';

  _ComicReaderPreferences _loadReaderPreferences(
    SharedPreferences preferences,
  ) {
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
          preferences.getString(_comicReaderModeKey) ??
          preferences.getString(_legacyReaderModeStorageKey),
    );
    final autoSplitWidePages =
        preferences.getBool(_comicAutoSplitWidePagesKey) ?? false;
    final comicReadingDirection = comicReadingDirectionFromString(
      preferences.getString(_comicReadingDirectionKey),
    );

    return _ComicReaderPreferences(
      nightMode: nightMode,
      backgroundIndex: backgroundIndex,
      readerMode: readerMode,
      autoSplitWidePages: autoSplitWidePages,
      comicReadingDirection: comicReadingDirection,
    );
  }

  Future<void> _saveReaderModePreference(ReaderMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_comicReaderModeKey, mode.storageValue);
    await preferences.setString(_readerModeStorageKey, mode.storageValue);
  }

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

      final readerPreferences = _loadReaderPreferences(preferences);
      final splitCacheDir = await _splitCacheDirFor(book);
      final displayPages = await ComicPageSplitter.buildDisplayPages(
        imagePaths: pagePaths,
        cacheDir: splitCacheDir,
        autoSplitWidePages: readerPreferences.autoSplitWidePages,
        readingDirection: readerPreferences.comicReadingDirection,
      );
      if (displayPages.isEmpty) {
        throw StateError('漫画目录中没有可阅读的图片');
      }

      final pageIndex =
          book.currentPosition.clamp(0, displayPages.length - 1).toInt();

      if (!mounted) {
        return;
      }

      setState(() {
        _book = book;
        _pagePaths = pagePaths;
        _displayPages = displayPages;
        _pageKeys = List.generate(displayPages.length, (_) => GlobalKey());
        _splitCacheDir = splitCacheDir;
        _currentPageIndex = pageIndex;
        _nightMode = readerPreferences.nightMode;
        _backgroundIndex = readerPreferences.backgroundIndex;
        _readerMode = readerPreferences.readerMode;
        _autoSplitWidePages = readerPreferences.autoSplitWidePages;
        _comicReadingDirection = readerPreferences.comicReadingDirection;
        _loading = false;
      });

      _restorePageForMode(readerPreferences.readerMode, pageIndex);
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

  Future<Directory> _splitCacheDirFor(Book book) async {
    final appDir = await getApplicationSupportDirectory();
    final bookId = book.id ?? widget.bookId;
    // TODO: Delete this cache directory when the owning comic is deleted.
    return Directory(
      p.join(appDir.path, 'wl_reader', 'comic_split_cache', '$bookId'),
    );
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
    if (book == null || book.id == null || _displayPages.isEmpty) {
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
    if (_displayPages.isEmpty) {
      return 0;
    }
    if (_displayPages.length <= 1) {
      return 1;
    }
    return (pageIndex / (_displayPages.length - 1)).clamp(0, 1).toDouble();
  }

  Future<void> _updateReaderMode(ReaderMode mode) async {
    if (mode == _readerMode) {
      return;
    }

    _scrollSaveDebounce?.cancel();
    final pageIndex = _safePageIndex(_currentPageIndex);
    setState(() => _readerMode = mode);

    await _saveReaderModePreference(mode);

    _restorePageForMode(mode, pageIndex);
    unawaited(_saveProgress(pageIndexOverride: pageIndex));
  }

  Future<void> _updateAutoSplitWidePages(bool enabled) async {
    if (enabled == _autoSplitWidePages) {
      return;
    }

    await _updateDisplayPageSettings(autoSplitWidePages: enabled);
  }

  Future<void> _updateComicReadingDirection(
    ComicReadingDirection direction,
  ) async {
    if (direction == _comicReadingDirection) {
      return;
    }

    await _updateDisplayPageSettings(readingDirection: direction);
  }

  Future<void> _updateDisplayPageSettings({
    bool? autoSplitWidePages,
    ComicReadingDirection? readingDirection,
  }) async {
    final splitCacheDir = _splitCacheDir;
    if (splitCacheDir == null || _pagePaths.isEmpty) {
      return;
    }

    final nextAutoSplitWidePages = autoSplitWidePages ?? _autoSplitWidePages;
    final nextReadingDirection = readingDirection ?? _comicReadingDirection;
    final currentPage = _currentDisplayPage;

    try {
      final nextDisplayPages = await ComicPageSplitter.buildDisplayPages(
        imagePaths: _pagePaths,
        cacheDir: splitCacheDir,
        autoSplitWidePages: nextAutoSplitWidePages,
        readingDirection: nextReadingDirection,
      );
      if (nextDisplayPages.isEmpty) {
        return;
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(
        _comicAutoSplitWidePagesKey,
        nextAutoSplitWidePages,
      );
      await preferences.setString(
        _comicReadingDirectionKey,
        nextReadingDirection.storageValue,
      );

      if (!mounted) {
        return;
      }

      final nextPageIndex = _displayPageIndexNear(
        nextDisplayPages,
        sourceIndex:
            currentPage?.sourceIndex ?? _safePageIndex(_currentPageIndex),
        preferredPart: currentPage?.part,
      );

      setState(() {
        _displayPages = nextDisplayPages;
        _pageKeys = List.generate(nextDisplayPages.length, (_) => GlobalKey());
        _currentPageIndex = nextPageIndex;
        _autoSplitWidePages = nextAutoSplitWidePages;
        _comicReadingDirection = nextReadingDirection;
      });

      _restorePageForMode(_readerMode, nextPageIndex);
      unawaited(_saveProgress(pageIndexOverride: nextPageIndex));
    } catch (_) {
      _showSnackBar('更新漫画显示设置失败');
    }
  }

  ComicDisplayPage? get _currentDisplayPage {
    if (_displayPages.isEmpty) {
      return null;
    }
    return _displayPages[_safePageIndex(_currentPageIndex)];
  }

  int _displayPageIndexNear(
    List<ComicDisplayPage> pages, {
    required int sourceIndex,
    ComicPagePart? preferredPart,
  }) {
    if (pages.isEmpty) {
      return 0;
    }

    if (preferredPart != null) {
      final exactPartIndex = pages.indexWhere(
        (page) => page.sourceIndex == sourceIndex && page.part == preferredPart,
      );
      if (exactPartIndex >= 0) {
        return exactPartIndex;
      }
    }

    final sameSourceIndex = pages.indexWhere(
      (page) => page.sourceIndex == sourceIndex,
    );
    if (sameSourceIndex >= 0) {
      return sameSourceIndex;
    }

    return sourceIndex.clamp(0, pages.length - 1).toInt();
  }

  void _restorePageForMode(ReaderMode mode, int pageIndex) {
    if (mode == ReaderMode.horizontalPage) {
      _queuePageJump(pageIndex);
      return;
    }
    _queueVerticalRestore(pageIndex);
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
    if (_currentPageIndex >= _displayPages.length - 1) {
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
      final target = _displayPages.length <= 1
          ? 0.0
          : maxOffset * pageIndex / (_displayPages.length - 1);
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
    if (_displayPages.isEmpty) {
      return 0;
    }
    return pageIndex.clamp(0, _displayPages.length - 1).toInt();
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

class _ComicReaderPreferences {
  const _ComicReaderPreferences({
    required this.nightMode,
    required this.backgroundIndex,
    required this.readerMode,
    required this.autoSplitWidePages,
    required this.comicReadingDirection,
  });

  final bool nightMode;
  final int backgroundIndex;
  final ReaderMode readerMode;
  final bool autoSplitWidePages;
  final ComicReadingDirection comicReadingDirection;
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
          return Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Center(
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => const _ComicImageError(),
                  ),
                ),
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
      child: Image.file(
        file,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => const _ComicImageError(),
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
    required this.autoSplitWidePages,
    required this.readingDirection,
    required this.isDarkMode,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPreviewPage,
    required this.onJumpToPage,
    required this.onCycleBackground,
    required this.onToggleNightMode,
    required this.onModeChanged,
    required this.onAutoSplitWidePagesChanged,
    required this.onReadingDirectionChanged,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final int currentPageIndex;
  final int pageCount;
  final ReaderMode readerMode;
  final bool autoSplitWidePages;
  final ComicReadingDirection readingDirection;
  final bool isDarkMode;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final ValueChanged<int> onPreviewPage;
  final ValueChanged<int> onJumpToPage;
  final VoidCallback onCycleBackground;
  final VoidCallback onToggleNightMode;
  final ValueChanged<ReaderMode> onModeChanged;
  final ValueChanged<bool> onAutoSplitWidePagesChanged;
  final ValueChanged<ComicReadingDirection> onReadingDirectionChanged;

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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.58,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '上一页',
                        color: foregroundColor,
                        onPressed:
                            currentPageIndex <= 0 ? null : onPreviousPage,
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
                        onPressed: currentPageIndex >= pageCount - 1
                            ? null
                            : onNextPage,
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: math
                              .min(
                                260,
                                MediaQuery.sizeOf(context).width - 112,
                              )
                              .clamp(180, 260)
                              .toDouble(),
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
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.splitscreen_outlined,
                      color: foregroundColor,
                    ),
                    title: Text(
                      '自动拆分双页图',
                      style: TextStyle(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: autoSplitWidePages,
                    onChanged: onAutoSplitWidePagesChanged,
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '拆页方向',
                      style: TextStyle(
                        color: foregroundColor.withAlpha(210),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ComicReadingDirection>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ComicReadingDirection.rightToLeft,
                          icon: Icon(Icons.chevron_left),
                          label: Text('从右到左'),
                        ),
                        ButtonSegment(
                          value: ComicReadingDirection.leftToRight,
                          icon: Icon(Icons.chevron_right),
                          label: Text('从左到右'),
                        ),
                      ],
                      selected: {readingDirection},
                      onSelectionChanged: (selection) {
                        onReadingDirectionChanged(selection.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

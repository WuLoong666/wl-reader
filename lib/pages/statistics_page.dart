import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/reading_progress_service.dart';
import '../services/reading_time_service.dart';
import '../utils/time_format.dart';
import '../widgets/book_detail_sheet.dart';
import '../widgets/local_image_view.dart';
import 'comic_reader_page.dart';
import 'novel_reader_page.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  static const _pageBackground = Color(0xFFF8F5FB);
  static const _panelColor = Color(0xFFFFFCF7);
  static const _softBlue = Color(0xFFEAF2FF);
  static const _softPurple = Color(0xFFF1E8FF);
  static const _softCream = Color(0xFFFFF3D9);
  static const _softMint = Color(0xFFE9F7F1);
  static const _textColor = Color(0xFF2F2B3A);
  static const _mutedTextColor = Color(0xFF716B7D);

  final _readingTimeService = ReadingTimeService();

  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  Map<String, int> _dailyStats = const {};
  Map<int, int> _bookSeconds = const {};
  String _loadedStatsSignature = '';
  String? _pendingStatsSignature;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final books = store.allBooks;
    _ensureStatsLoaded(books);

    final totalDailySeconds =
        _dailyStats.values.fold(0, (total, seconds) => total + seconds);
    final totalBookSeconds =
        _bookSeconds.values.fold(0, (total, seconds) => total + seconds);
    final totalReadingSeconds =
        totalBookSeconds > 0 ? totalBookSeconds : totalDailySeconds;
    final readingDays =
        _dailyStats.values.where((seconds) => seconds > 0).length;
    final averageSeconds =
        readingDays == 0 ? 0 : totalDailySeconds ~/ readingDays;
    final readBookCount = books.where((book) => book.progress >= 0.99).length;
    final recentBooks = _recentBooks(books);

    return ColoredBox(
      color: _pageBackground,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(loading: _loadingStats),
                          const SizedBox(height: 14),
                          _ReadingCalendarCard(
                            month: _visibleMonth,
                            selectedDate: _selectedDate,
                            dailyStats: _dailyStats,
                            onPreviousMonth: () => _changeMonth(-1),
                            onNextMonth: () => _changeMonth(1),
                            onDateSelected: (date) {
                              setState(() => _selectedDate = date);
                            },
                          ),
                          const SizedBox(height: 14),
                          _MetricGrid(
                            metrics: [
                              _MetricData(
                                title: '书籍数量',
                                value: '${books.length} 本',
                                icon: Icons.local_library_outlined,
                                color: _softBlue,
                              ),
                              _MetricData(
                                title: '已读书籍',
                                value: '$readBookCount 本',
                                icon: Icons.done_all_rounded,
                                color: _softMint,
                              ),
                              _MetricData(
                                title: '累计时间',
                                value: formatDuration(totalReadingSeconds),
                                icon: Icons.timer_outlined,
                                color: _softPurple,
                              ),
                              _MetricData(
                                title: '平均时间',
                                value: formatDuration(averageSeconds),
                                icon: Icons.insights_outlined,
                                color: _softCream,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _RecentBooksPanel(
                            books: recentBooks,
                            bookSeconds: _bookSeconds,
                            onBookTap: (book) => _showBookDetail(context, book),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(BuildContext context) async {
    final store = context.read<LibraryStore>();
    await store.loadLibrary();
    if (!mounted) {
      return;
    }
    final books = store.allBooks;
    await _reloadStatsForBooks(books);
  }

  void _ensureStatsLoaded(List<Book> books) {
    final signature = _statsSignatureFor(books);
    if (_loadedStatsSignature == signature ||
        _pendingStatsSignature == signature) {
      return;
    }

    _pendingStatsSignature = signature;
    unawaited(Future<void>.microtask(
      () => _loadStatsForBooks(books, signature),
    ));
  }

  Future<void> _loadStatsForBooks(
    List<Book> books,
    String signature,
  ) async {
    if (mounted && !_loadingStats) {
      setState(() => _loadingStats = true);
    }

    final dailyStats = await _readingTimeService.dailyReadingSeconds();
    final bookIds = books
        .map((book) => book.id)
        .whereType<int>()
        .where((id) => id > 0)
        .toList(growable: false);
    final bookSeconds =
        await _readingTimeService.bookReadingSecondsById(bookIds);

    if (!mounted || _pendingStatsSignature != signature) {
      return;
    }

    setState(() {
      _dailyStats = dailyStats;
      _bookSeconds = bookSeconds;
      _loadedStatsSignature = signature;
      _pendingStatsSignature = null;
      _loadingStats = false;
    });
  }

  String _statsSignatureFor(List<Book> books) {
    return books
        .map(
          (book) => [
            book.id ?? 0,
            book.lastReadAt?.millisecondsSinceEpoch ?? 0,
            (book.progress * 10000).round(),
          ].join(':'),
        )
        .join('|');
  }

  List<Book> _recentBooks(List<Book> books) {
    final recent =
        books.where((book) => book.lastReadAt != null).toList(growable: false);
    recent.sort((left, right) => right.lastReadAt!.compareTo(left.lastReadAt!));
    return recent.take(8).toList(growable: false);
  }

  void _changeMonth(int offset) {
    final nextMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + offset,
    );
    final now = DateTime.now();
    setState(() {
      _visibleMonth = nextMonth;
      _selectedDate = nextMonth.year == now.year && nextMonth.month == now.month
          ? DateTime(now.year, now.month, now.day)
          : nextMonth;
    });
  }

  Future<void> _showBookDetail(BuildContext context, Book book) async {
    final shouldOpen = await showBookDetailSheet(
      context: context,
      book: book,
    );
    if (shouldOpen != true || !context.mounted) {
      return;
    }

    await _openBook(context, book);
  }

  Future<void> _openBook(BuildContext context, Book book) async {
    final id = book.id;
    if (id == null) {
      return;
    }

    final store = context.read<LibraryStore>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => book.bookType == BookType.comic
            ? ComicReaderPage(bookId: id)
            : NovelReaderPage(bookId: id),
      ),
    );
    if (!mounted) {
      return;
    }

    await store.loadLibrary();
    if (!mounted) {
      return;
    }
    final books = store.allBooks;
    await _reloadStatsForBooks(books);
  }

  Future<void> _reloadStatsForBooks(List<Book> books) async {
    final signature = _statsSignatureFor(books);
    _pendingStatsSignature = signature;
    await _loadStatsForBooks(books, signature);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '统计',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _StatisticsPageState._textColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        SizedBox.square(
          dimension: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFE7EEFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.query_stats,
                      color: Color(0xFF526DB7),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadingCalendarCard extends StatelessWidget {
  const _ReadingCalendarCard({
    required this.month,
    required this.selectedDate,
    required this.dailyStats,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDateSelected,
  });

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  final DateTime month;
  final DateTime selectedDate;
  final Map<String, int> dailyStats;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final selectedSeconds = dailyStats[_dateKey(selectedDate)] ?? 0;
    final cells = _calendarCells(month);

    return _SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '阅读日历',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _StatisticsPageState._textColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                tooltip: '上个月',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                _monthLabel(month),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              IconButton(
                tooltip: '下个月',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final day in _weekdays)
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _StatisticsPageState._mutedTextColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: constraints.maxWidth < 360 ? 0.9 : 1.12,
                ),
                itemBuilder: (context, index) {
                  final date = cells[index];
                  if (date == null) {
                    return const SizedBox.shrink();
                  }
                  return _CalendarDayCell(
                    date: date,
                    seconds: dailyStats[_dateKey(date)] ?? 0,
                    selected: _isSameDate(date, selectedDate),
                    today: _isSameDate(date, DateTime.now()),
                    onTap: () => onDateSelected(date),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                '${_shortDateLabel(selectedDate)} 阅读 ${formatDuration(selectedSeconds)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _StatisticsPageState._textColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime?> _calendarCells(DateTime month) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = firstDay.weekday - 1;
    final cells = <DateTime?>[
      for (var i = 0; i < leadingEmpty; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  String _monthLabel(DateTime month) {
    return '${month.year}.${month.month.toString().padLeft(2, '0')}';
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _shortDateLabel(DateTime date) {
    return '${date.month} 月 ${date.day} 日';
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.seconds,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime date;
  final int seconds;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasRecord = seconds > 0;
    final colorScheme = Theme.of(context).colorScheme;
    final fillColor = selected
        ? colorScheme.primary.withAlpha(42)
        : hasRecord
            ? const Color(0xFFEAF2FF)
            : Colors.white;
    final borderColor = selected
        ? colorScheme.primary
        : today
            ? const Color(0xFF8E7CC3)
            : const Color(0xFFE6E0EA);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: selected || today ? 1.4 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _StatisticsPageState._textColor,
                        fontWeight: today ? FontWeight.w900 : FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCompactDuration(seconds),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 4 ? 1.65 : 1.35,
          ),
          itemBuilder: (context, index) {
            return _MetricCard(data: metrics[index]);
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(190)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  data.icon,
                  color: const Color(0xFF526079),
                  size: 22,
                ),
                const Spacer(),
              ],
            ),
            const Spacer(),
            Text(
              data.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _StatisticsPageState._textColor,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _StatisticsPageState._mutedTextColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _RecentBooksPanel extends StatelessWidget {
  const _RecentBooksPanel({
    required this.books,
    required this.bookSeconds,
    required this.onBookTap,
  });

  final List<Book> books;
  final Map<int, int> bookSeconds;
  final ValueChanged<Book> onBookTap;

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '最近阅读书籍',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _StatisticsPageState._textColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (books.isEmpty)
            const _RecentEmptyState()
          else
            for (var index = 0; index < books.length; index++) ...[
              _RecentBookTile(
                book: books[index],
                seconds: bookSeconds[books[index].id] ?? 0,
                onTap: () => onBookTap(books[index]),
              ),
              if (index < books.length - 1)
                const Divider(height: 1, color: Color(0xFFE7E0EA)),
            ],
        ],
      ),
    );
  }
}

class _RecentBookTile extends StatelessWidget {
  const _RecentBookTile({
    required this.book,
    required this.seconds,
    required this.onTap,
  });

  final Book book;
  final int seconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progressText = '${(book.progress * 100).clamp(0, 100).round()}%';
    final author = book.author.trim().isEmpty ? '作者未记录' : book.author.trim();
    final lastReadAt = book.lastReadAt;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 74,
                  child: _RecentCover(book: book),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _StatisticsPageState._textColor,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _StatisticsPageState._mutedTextColor,
                          ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: book.progress.clamp(0, 1),
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '进度 $progressText · ${lastReadAt == null ? '未记录时间' : _formatDateTime(lastReadAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _StatisticsPageState._mutedTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 86),
                child: Text(
                  formatDuration(seconds),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _StatisticsPageState._textColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month.$day $hour:$minute';
  }
}

class _RecentCover extends StatelessWidget {
  const _RecentCover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    if (book.coverPath.isNotEmpty) {
      return ColoredBox(
        color: const Color(0xFFF1F2F2),
        child: LocalImageView(
          path: book.coverPath,
          fit: BoxFit.contain,
          fallbackBuilder: (_) => _FallbackCover(title: book.title),
          unsupportedBuilder: (_) => _FallbackCover(title: book.title),
        ),
      );
    }
    return _FallbackCover(title: book.title);
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEAE2F0),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF4B3B63),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentEmptyState extends StatelessWidget {
  const _RecentEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            '还没有最近阅读记录',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _StatisticsPageState._textColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _StatisticsPageState._panelColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(210)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/reading_progress_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../utils/book_sorter.dart';
import '../utils/library_filter.dart';
import '../widgets/anime_background.dart';
import '../widgets/book_cover_card.dart';
import '../widgets/book_detail_sheet.dart';
import '../widgets/book_sort_sheet.dart';
import '../widgets/library_filter_chips.dart';
import '../widgets/recent_reading_card.dart';
import '../widgets/today_progress_card.dart';
import 'comic_reader_page.dart';
import 'novel_reader_page.dart';

class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  LibraryFilter _currentFilter = LibraryFilter.all;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final width = MediaQuery.sizeOf(context).width;
    final allBooks = store.allBooks;
    final filterCounts = countBooksByLibrarySection(allBooks);
    final sectionBooks = filterBooksByLibrarySection(allBooks, _currentFilter);
    final books = store.sortLibraryBooks(sectionBooks);

    return AnimeBackground(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<LibraryStore>().loadLibrary(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ShelfHeader(
                    importing: store.importing,
                    onImport: () => _importBook(context),
                    sortType: store.sortType,
                    sortOrder: store.sortOrder,
                    onSort: () => _showSortOptions(context),
                    bookCount: allBooks.length,
                    recentBook: store.recentBook,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: TodayProgressCard(
                    book: store.recentBook,
                    onContinue: store.recentBook == null
                        ? null
                        : () => _openBook(context, store.recentBook!),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: RecentReadingCard(
                    book: store.recentBook,
                    onTap: store.recentBook == null
                        ? null
                        : () => _showBookDetail(context, store.recentBook!),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: LibraryFilterChips(
                    currentFilter: _currentFilter,
                    counts: filterCounts,
                    onChanged: (filter) {
                      setState(() => _currentFilter = filter);
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '单册书籍',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (store.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (books.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _LibraryEmptyState(
                    filter: _currentFilter,
                    onImport: () => _importBook(context),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridCount(width),
                      mainAxisSpacing: 22,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.55,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final book = books[index];
                        return BookCoverCard(
                          book: book,
                          onTap: () => _showBookDetail(context, book),
                        );
                      },
                      childCount: books.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _gridCount(double width) {
    if (width < 600) {
      return 3;
    }
    if (width < 900) {
      return 4;
    }
    if (width < 1300) {
      return 5;
    }
    return 6;
  }

  Future<void> _importBook(BuildContext context) async {
    try {
      final book = await context.read<LibraryStore>().importBook();
      if (book == null || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入：${book.title}')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyErrorMessage(error))),
      );
    }
  }

  String _friendlyErrorMessage(Object error) {
    if (error is FormatException) {
      return error.message;
    }
    if (error is FileSystemException) {
      return error.message;
    }
    if (error is UnsupportedError) {
      return error.message?.toString() ?? '不支持的文件格式';
    }
    return error.toString();
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

  void _showSortOptions(BuildContext context) {
    final store = context.read<LibraryStore>();
    showBookSortSheet(
      context: context,
      sortType: store.sortType,
      sortOrder: store.sortOrder,
      onChanged: (sortType, sortOrder) {
        context.read<LibraryStore>().updateSort(
              sortType: sortType,
              sortOrder: sortOrder,
            );
      },
    );
  }

  Future<void> _openBook(BuildContext context, Book book) async {
    final id = book.id;
    if (id == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => book.bookType == BookType.comic
            ? ComicReaderPage(bookId: id)
            : NovelReaderPage(bookId: id),
      ),
    );
    if (context.mounted) {
      await context.read<LibraryStore>().loadLibrary();
    }
  }
}

class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({
    required this.importing,
    required this.onImport,
    required this.sortType,
    required this.sortOrder,
    required this.onSort,
    required this.bookCount,
    required this.recentBook,
  });

  final bool importing;
  final VoidCallback onImport;
  final BookSortType sortType;
  final SortOrder sortOrder;
  final VoidCallback onSort;
  final int bookCount;
  final Book? recentBook;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        recentBook == null ? '乌龙茶与魔法书页，等一本轻小说落座' : '最近翻到「${recentBook!.title}」';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.teaGradient,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: AppShadows.glow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          children: [
            const Positioned.fill(child: _ShelfHeaderPattern()),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '书库',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: AppColors.deepPurple,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.teaAmberDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _HeaderIconButton(
                        tooltip: '导入',
                        onPressed: importing ? null : onImport,
                        icon: importing
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.file_upload_outlined),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _HeaderIconButton(
                        tooltip: '更多',
                        onPressed: onSort,
                        icon: const Icon(Icons.sort),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      _HeaderChip(
                        icon: Icons.local_library_outlined,
                        text: '$bookCount 本藏书',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _HeaderChip(
                        icon: Icons.auto_awesome,
                        text: '${sortType.label} · ${sortOrder.label}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.7),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.38),
          foregroundColor: AppColors.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        icon: icon,
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.deepPurple),
            const SizedBox(width: AppSpacing.xs),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.deepPurple,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfHeaderPattern extends StatelessWidget {
  const _ShelfHeaderPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ShelfHeaderPainter());
  }
}

class _ShelfHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pagePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.36);
    final sparklePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4
      ..color = AppColors.deepPurple.withValues(alpha: 0.14);

    final pagePath = Path()
      ..moveTo(size.width * 0.7, size.height * 0.1)
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.02,
        size.width * 0.98,
        size.height * 0.18,
      )
      ..moveTo(size.width * 0.74, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.86,
        size.height * 0.12,
        size.width,
        size.height * 0.3,
      );
    canvas.drawPath(pagePath, pagePaint);

    final points = [
      Offset(size.width * 0.16, size.height * 0.2),
      Offset(size.width * 0.54, size.height * 0.34),
      Offset(size.width * 0.88, size.height * 0.72),
    ];
    for (final point in points) {
      canvas.drawLine(
        point.translate(-4, 0),
        point.translate(4, 0),
        sparklePaint,
      );
      canvas.drawLine(
        point.translate(0, -4),
        point.translate(0, 4),
        sparklePaint,
      );
    }

    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.teaAmberDeep.withValues(alpha: 0.14);
    for (var index = 0; index < 3; index++) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width * 0.08, size.height * 0.88),
          radius: 24 + index * 14,
        ),
        4.8,
        1.8,
        false,
        ripplePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({
    required this.filter,
    required this.onImport,
  });

  final LibraryFilter filter;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final data = _EmptyStateData.resolve(filter);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.parchment.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
            boxShadow: AppShadows.soft,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.sakuraMist,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: const SizedBox.expand(),
                      ),
                      const Positioned(
                        right: 14,
                        top: 14,
                        child: Icon(
                          Icons.auto_awesome,
                          color: AppColors.star,
                          size: 18,
                        ),
                      ),
                      Icon(
                        data.icon,
                        size: 46,
                        color: AppColors.deepPurple,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  data.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (filter != LibraryFilter.wantToRead) ...[
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('导入书籍'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyShelf extends StatelessWidget {
  const EmptyShelf({super.key, required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onImport,
        icon: const Icon(Icons.file_open_outlined),
        label: const Text('导入 TXT / EPUB'),
      ),
    );
  }
}

class _EmptyStateData {
  const _EmptyStateData({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  factory _EmptyStateData.resolve(LibraryFilter filter) {
    return switch (filter) {
      LibraryFilter.all => const _EmptyStateData(
          icon: Icons.auto_stories_outlined,
          message: '书架空空如也，导入一本轻小说开始吧',
        ),
      LibraryFilter.wantToRead => const _EmptyStateData(
          icon: Icons.bookmark_border,
          message: '还没有欲读书籍，把感兴趣的书加入欲读吧',
        ),
      LibraryFilter.novel => const _EmptyStateData(
          icon: Icons.menu_book_outlined,
          message: '还没有小说，导入 TXT 或 EPUB 开始阅读吧',
        ),
      LibraryFilter.comic => const _EmptyStateData(
          icon: Icons.collections_bookmark_outlined,
          message: '还没有漫画，之后可以导入 CBZ 或 ZIP 漫画包',
        ),
    };
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/reading_progress_service.dart';
import '../utils/book_sorter.dart';
import '../utils/library_filter.dart';
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

    return SafeArea(
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
                child: Text(
                  '单册书籍',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                    mainAxisSpacing: 20,
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
  });

  final bool importing;
  final VoidCallback onImport;
  final BookSortType sortType;
  final SortOrder sortOrder;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '书库',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: '导入',
          onPressed: importing ? null : onImport,
          icon: importing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_upload_outlined),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '更多',
          onPressed: onSort,
          icon: const Icon(Icons.sort),
        ),
      ],
    );
  }
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
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              data.icon,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              data.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (filter != LibraryFilter.wantToRead) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('导入书籍'),
              ),
            ],
          ],
        ),
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

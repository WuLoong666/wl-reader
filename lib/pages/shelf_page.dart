import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/reading_progress_service.dart';
import '../widgets/book_cover_card.dart';
import '../widgets/recent_reading_card.dart';
import '../widgets/today_progress_card.dart';
import 'novel_reader_page.dart';

class ShelfPage extends StatelessWidget {
  const ShelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final width = MediaQuery.sizeOf(context).width;
    final books = store.books;

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
                      : () => _openBook(context, store.recentBook!),
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
                child: _EmptyShelf(onImport: () => _importBook(context)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridCount(width),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.55,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final book = books[index];
                      return BookCoverCard(
                        book: book,
                        onTap: () => _openBook(context, book),
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
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _openBook(BuildContext context, Book book) async {
    final id = book.id;
    if (id == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NovelReaderPage(bookId: id),
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
  });

  final bool importing;
  final VoidCallback onImport;

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
          onPressed: () {},
          icon: const Icon(Icons.more_horiz),
        ),
      ],
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onImport});

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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/reading_progress_service.dart';
import '../utils/book_search.dart';
import '../utils/library_filter.dart';
import '../widgets/book_cover_card.dart';
import '../widgets/book_detail_sheet.dart';
import '../widgets/library_filter_chips.dart';
import 'comic_reader_page.dart';
import 'novel_reader_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _keyword = '';
  LibraryFilter _currentFilter = LibraryFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final allBooks = store.allBooks;
    final filterCounts = countBooksByLibrarySection(allBooks);
    final sectionBooks = filterBooksByLibrarySection(allBooks, _currentFilter);
    final filteredBooks = filterBooks(sectionBooks, _keyword);
    final books = store.sortLibraryBooks(filteredBooks);
    final width = MediaQuery.sizeOf(context).width;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => context.read<LibraryStore>().loadLibrary(),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '搜索',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        _SearchField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          keyword: _keyword,
                          onChanged: (value) {
                            setState(() => _keyword = value);
                          },
                          onClear: _clearKeyword,
                        ),
                        const SizedBox(height: 12),
                        LibraryFilterChips(
                          currentFilter: _currentFilter,
                          counts: filterCounts,
                          onChanged: (filter) {
                            setState(() => _currentFilter = filter);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (store.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (store.allBooks.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _SearchEmptyState(
                  icon: Icons.local_library_outlined,
                  title: '书架还没有书籍',
                  message: '导入书籍后可以在这里搜索',
                ),
              )
            else if (sectionBooks.isEmpty && _keyword.trim().isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _SearchEmptyState(
                  icon: _emptyIconForFilter(_currentFilter),
                  title: _emptyTitleForFilter(_currentFilter),
                  message: _emptyMessageForFilter(_currentFilter),
                ),
              )
            else if (books.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _SearchEmptyState(
                  icon: Icons.search_off_outlined,
                  title: '没有找到相关书籍',
                  message: '换个书名、作者或格式试试',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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

  void _clearKeyword() {
    _searchController.clear();
    setState(() => _keyword = '');
    _searchFocusNode.requestFocus();
  }

  IconData _emptyIconForFilter(LibraryFilter filter) {
    return switch (filter) {
      LibraryFilter.all => Icons.auto_stories_outlined,
      LibraryFilter.wantToRead => Icons.bookmark_border,
      LibraryFilter.novel => Icons.menu_book_outlined,
      LibraryFilter.comic => Icons.collections_bookmark_outlined,
    };
  }

  String _emptyTitleForFilter(LibraryFilter filter) {
    return switch (filter) {
      LibraryFilter.all => '书架空空如也',
      LibraryFilter.wantToRead => '还没有欲读书籍',
      LibraryFilter.novel => '还没有小说',
      LibraryFilter.comic => '还没有漫画',
    };
  }

  String _emptyMessageForFilter(LibraryFilter filter) {
    return switch (filter) {
      LibraryFilter.all => '导入一本轻小说开始吧',
      LibraryFilter.wantToRead => '把感兴趣的书加入欲读吧',
      LibraryFilter.novel => '导入 TXT 或 EPUB 开始阅读吧',
      LibraryFilter.comic => '之后可以导入 CBZ 或 ZIP 漫画包',
    };
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.keyword,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String keyword;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索书名、作者或格式',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: keyword.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: '清除',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withAlpha(150),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 46,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

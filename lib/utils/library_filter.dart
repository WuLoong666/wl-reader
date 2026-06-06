import '../models/book.dart';

enum LibraryFilter {
  all,
  wantToRead,
  novel,
  comic,
}

extension LibraryFilterLabel on LibraryFilter {
  String get label {
    return switch (this) {
      LibraryFilter.all => '全部',
      LibraryFilter.wantToRead => '欲读',
      LibraryFilter.novel => '小说',
      LibraryFilter.comic => '漫画',
    };
  }
}

List<Book> filterBooksByLibrarySection(
  List<Book> books,
  LibraryFilter filter,
) {
  return books.where((book) => _matchesFilter(book, filter)).toList(
        growable: false,
      );
}

Map<LibraryFilter, int> countBooksByLibrarySection(List<Book> books) {
  return {
    for (final filter in LibraryFilter.values)
      filter: filterBooksByLibrarySection(books, filter).length,
  };
}

bool _matchesFilter(Book book, LibraryFilter filter) {
  return switch (filter) {
    LibraryFilter.all => true,
    LibraryFilter.wantToRead => book.isWantToRead,
    LibraryFilter.novel => book.bookType == BookType.novel,
    LibraryFilter.comic => book.bookType == BookType.comic,
  };
}

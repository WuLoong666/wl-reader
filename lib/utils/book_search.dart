import 'package:path/path.dart' as p;

import '../models/book.dart';

List<Book> filterBooks(List<Book> books, String keyword) {
  final query = keyword.trim().toLowerCase();
  if (query.isEmpty) {
    return List<Book>.of(books);
  }

  return books
      .where((book) => _matchesBook(book, query))
      .toList(growable: false);
}

bool _matchesBook(Book book, String query) {
  return _searchValues(book).any((value) {
    return value.toLowerCase().contains(query);
  });
}

Iterable<String> _searchValues(Book book) sync* {
  yield book.title;
  yield book.author;
  yield p.basename(book.filePath);
  yield book.format;
  yield book.formatLabel;
  yield book.typeLabel;
  yield book.bookType.storageValue;
  yield switch (book.bookType) {
    BookType.novel => 'novel 小说 轻小说',
    BookType.comic => 'comic cbz zip manga 漫画',
  };
}

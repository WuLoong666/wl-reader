import 'package:flutter_test/flutter_test.dart';
import 'package:wl_reader/models/book.dart';
import 'package:wl_reader/utils/book_sorter.dart';

void main() {
  test('sorts books by title without mutating the original list', () {
    final books = [
      _book(id: 1, title: 'C'),
      _book(id: 2, title: 'A'),
      _book(id: 3, title: 'B'),
    ];

    final sorted = sortBooks(
      books,
      BookSortType.title,
      SortOrder.ascending,
    );

    expect(sorted.map((book) => book.title), ['A', 'B', 'C']);
    expect(books.map((book) => book.title), ['C', 'A', 'B']);
  });

  test('keeps missing authors at the end in both directions', () {
    final books = [
      _book(id: 1, title: 'No Author', author: ''),
      _book(id: 2, title: 'Beta Book', author: 'Beta'),
      _book(id: 3, title: 'Alpha Book', author: 'Alpha'),
    ];

    final ascending = sortBooks(
      books,
      BookSortType.author,
      SortOrder.ascending,
    );
    final descending = sortBooks(
      books,
      BookSortType.author,
      SortOrder.descending,
    );

    expect(ascending.map((book) => book.author), ['Alpha', 'Beta', '']);
    expect(descending.map((book) => book.author), ['Beta', 'Alpha', '']);
  });

  test('keeps unread books last when sorting by last read time', () {
    final books = [
      _book(id: 1, title: 'Unread'),
      _book(id: 2, title: 'Old', lastReadTime: DateTime(2024)),
      _book(id: 3, title: 'New', lastReadTime: DateTime(2026)),
    ];

    final sorted = sortBooks(
      books,
      BookSortType.lastReadAt,
      SortOrder.descending,
    );

    expect(sorted.map((book) => book.title), ['New', 'Old', 'Unread']);
  });
}

Book _book({
  required int id,
  required String title,
  String author = 'Author',
  DateTime? addedTime,
  DateTime? lastReadTime,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    filePath: '',
    coverPath: '',
    format: 'txt',
    totalChapters: 1,
    currentChapter: 0,
    currentPosition: 0,
    progress: 0,
    addedTime: addedTime ?? DateTime(2025, 1, id),
    lastReadTime: lastReadTime,
  );
}

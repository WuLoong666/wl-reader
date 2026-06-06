import 'package:flutter_test/flutter_test.dart';
import 'package:wl_reader/models/book.dart';
import 'package:wl_reader/utils/book_search.dart';

void main() {
  test('returns all books when keyword is empty', () {
    final books = [
      _book(id: 1, title: 'One'),
      _book(id: 2, title: 'Two'),
    ];

    final result = filterBooks(books, '   ');

    expect(result, books);
    expect(identical(result, books), isFalse);
  });

  test('matches title author filename and format case-insensitively', () {
    final books = [
      _book(
        id: 1,
        title: '三体',
        author: '刘慈欣',
        filePath: r'D:\books\santi.epub',
        format: 'epub',
        bookType: BookType.novel,
      ),
      _book(
        id: 2,
        title: 'Plain Text',
        author: '',
        filePath: r'D:\books\notes.txt',
        format: 'txt',
      ),
    ];

    expect(filterBooks(books, '三').map((book) => book.id), [1]);
    expect(filterBooks(books, '刘').map((book) => book.id), [1]);
    expect(filterBooks(books, 'SANTI').map((book) => book.id), [1]);
    expect(filterBooks(books, 'txt').map((book) => book.id), [2]);
  });

  test('matches comic type aliases', () {
    final books = [
      _book(
        id: 1,
        title: 'Comic Sample',
        format: 'cbz',
        bookType: BookType.comic,
      ),
    ];

    expect(filterBooks(books, 'comic').single.id, 1);
    expect(filterBooks(books, 'manga').single.id, 1);
  });
}

Book _book({
  required int id,
  required String title,
  String author = 'Author',
  String filePath = '',
  String format = 'txt',
  BookType bookType = BookType.novel,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    filePath: filePath,
    coverPath: '',
    format: format,
    bookType: bookType,
    totalChapters: 1,
    currentChapter: 0,
    currentPosition: 0,
    progress: 0,
    addedTime: DateTime(2025, 1, id),
  );
}

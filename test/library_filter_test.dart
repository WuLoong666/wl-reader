import 'package:flutter_test/flutter_test.dart';
import 'package:wl_reader/models/book.dart';
import 'package:wl_reader/utils/library_filter.dart';

void main() {
  test('filters by all novel comic and want to read independently', () {
    final books = [
      _book(id: 1, title: 'Novel', isWantToRead: true),
      _book(id: 2, title: 'Comic', bookType: BookType.comic),
      _book(
          id: 3,
          title: 'Wanted Comic',
          bookType: BookType.comic,
          isWantToRead: true),
    ];

    expect(
      filterBooksByLibrarySection(books, LibraryFilter.all)
          .map((book) => book.id),
      [1, 2, 3],
    );
    expect(
      filterBooksByLibrarySection(books, LibraryFilter.novel)
          .map((book) => book.id),
      [1],
    );
    expect(
      filterBooksByLibrarySection(books, LibraryFilter.comic)
          .map((book) => book.id),
      [2, 3],
    );
    expect(
      filterBooksByLibrarySection(books, LibraryFilter.wantToRead)
          .map((book) => book.id),
      [1, 3],
    );
  });
}

Book _book({
  required int id,
  required String title,
  BookType bookType = BookType.novel,
  bool isWantToRead = false,
}) {
  return Book(
    id: id,
    title: title,
    author: '',
    filePath: '',
    coverPath: '',
    format: bookType == BookType.comic ? 'cbz' : 'txt',
    bookType: bookType,
    isWantToRead: isWantToRead,
    totalChapters: 1,
    currentChapter: 0,
    currentPosition: 0,
    progress: 0,
    addedTime: DateTime(2025, 1, id),
  );
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/book_dao.dart';
import '../database/chapter_dao.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../utils/book_sorter.dart';
import 'file_import_service.dart';

class ReadingProgressService {
  ReadingProgressService({BookDao? bookDao}) : _bookDao = bookDao ?? BookDao();

  final BookDao _bookDao;

  Future<void> saveProgress({
    required Book book,
    required int currentChapter,
    required int currentPosition,
    required double progress,
  }) async {
    final bookId = book.id;
    if (bookId == null) {
      return;
    }

    await _bookDao.updateProgress(
      bookId: bookId,
      currentChapter: currentChapter,
      currentPosition: currentPosition,
      progress: progress,
    );
  }
}

class LibraryStore extends ChangeNotifier {
  static const _sortTypeKey = 'library_sort_type';
  static const _sortOrderKey = 'library_sort_order';

  LibraryStore({
    BookDao? bookDao,
    ChapterDao? chapterDao,
    FileImportService? importService,
  })  : _bookDao = bookDao ?? BookDao(),
        _chapterDao = chapterDao ?? ChapterDao(),
        _importService = importService ?? FileImportService();

  final BookDao _bookDao;
  final ChapterDao _chapterDao;
  final FileImportService _importService;

  List<Book> _books = const [];
  BookSortType _sortType = BookSortType.lastReadAt;
  SortOrder _sortOrder = SortOrder.descending;
  bool _sortPreferencesLoaded = false;
  bool _loading = false;
  bool _importing = false;
  String? _errorMessage;

  List<Book> get books => sortLibraryBooks(_books);
  List<Book> get allBooks => List<Book>.unmodifiable(_books);
  BookSortType get sortType => _sortType;
  SortOrder get sortOrder => _sortOrder;
  bool get loading => _loading;
  bool get importing => _importing;
  String? get errorMessage => _errorMessage;

  Book? get recentBook {
    if (_books.isEmpty) {
      return null;
    }
    return sortBooks(
      _books,
      BookSortType.lastReadAt,
      SortOrder.descending,
    ).first;
  }

  Future<void> loadLibrary() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadSortPreferences();
      _books = await _bookDao.getAll();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<Book> sortLibraryBooks(List<Book> books) {
    return sortBooks(books, _sortType, _sortOrder);
  }

  Future<void> updateSort({
    required BookSortType sortType,
    required SortOrder sortOrder,
  }) async {
    _sortType = sortType;
    _sortOrder = sortOrder;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sortTypeKey, sortType.storageValue);
    await preferences.setString(_sortOrderKey, sortOrder.storageValue);
  }

  Future<void> updateWantToRead({
    required Book book,
    required bool isWantToRead,
  }) async {
    final bookId = book.id;
    if (bookId == null) {
      return;
    }

    await _bookDao.updateWantToRead(
      bookId: bookId,
      isWantToRead: isWantToRead,
    );

    _books = _books
        .map(
          (existing) => existing.id == bookId
              ? existing.copyWith(isWantToRead: isWantToRead)
              : existing,
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> updateReadingStatus({
    required Book book,
    required bool isFinished,
  }) async {
    final bookId = book.id;
    if (bookId == null) {
      return;
    }

    final updated = isFinished
        ? book.copyWith(
            currentChapter:
                book.totalChapters <= 0 ? 0 : book.totalChapters - 1,
            currentPosition:
                book.bookType == BookType.comic && book.totalChapters > 0
                    ? book.totalChapters - 1
                    : 0,
            progress: 1,
            lastReadTime: DateTime.now(),
          )
        : book.copyWith(
            currentChapter: 0,
            currentPosition: 0,
            progress: 0,
          );

    await _bookDao.update(updated);
    _books = _books
        .map((existing) => existing.id == bookId ? updated : existing)
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> deleteBook(Book book) async {
    final bookId = book.id;
    if (bookId == null) {
      return;
    }

    await _chapterDao.deleteByBookId(bookId);
    await _bookDao.deleteById(bookId);
    // TODO: Remove copied source files, covers, epub_assets/{bookId}, comic
    // extraction directories, and split caches with explicit safe deletion.
    _books = _books.where((existing) => existing.id != bookId).toList(
          growable: false,
        );
    notifyListeners();
  }

  Future<void> _loadSortPreferences() async {
    if (_sortPreferencesLoaded) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    _sortType = bookSortTypeFromString(preferences.getString(_sortTypeKey));
    _sortOrder = sortOrderFromString(preferences.getString(_sortOrderKey));
    _sortPreferencesLoaded = true;
  }

  Future<Book?> importBook() async {
    _importing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final book = await _importService.importFromPicker();
      await loadLibrary();
      return book;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      rethrow;
    } finally {
      _importing = false;
      notifyListeners();
    }
  }

  Future<List<Chapter>> loadChapters(int bookId) {
    return _chapterDao.getByBookId(bookId);
  }
}

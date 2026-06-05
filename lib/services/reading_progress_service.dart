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

  List<Book> get books => sortBooks(_books, _sortType, _sortOrder);
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

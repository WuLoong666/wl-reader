import 'package:flutter/foundation.dart';

import '../database/book_dao.dart';
import '../database/chapter_dao.dart';
import '../models/book.dart';
import '../models/chapter.dart';
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
  bool _loading = false;
  bool _importing = false;
  String? _errorMessage;

  List<Book> get books => _books;
  bool get loading => _loading;
  bool get importing => _importing;
  String? get errorMessage => _errorMessage;

  Book? get recentBook {
    if (_books.isEmpty) {
      return null;
    }
    return _books.first;
  }

  Future<void> loadLibrary() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _books = await _bookDao.getAll();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
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

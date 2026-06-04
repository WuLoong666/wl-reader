import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/book_dao.dart';
import '../database/chapter_dao.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../utils/cover_generator.dart';
import '../utils/file_type_detector.dart';
import 'epub_parser_service.dart';
import 'txt_parser_service.dart';

class FileImportService {
  FileImportService({
    BookDao? bookDao,
    ChapterDao? chapterDao,
    TxtParserService? txtParser,
    EpubParserService? epubParser,
  })  : _bookDao = bookDao ?? BookDao(),
        _chapterDao = chapterDao ?? ChapterDao(),
        _txtParser = txtParser ?? TxtParserService(),
        _epubParser = epubParser ?? EpubParserService();

  final BookDao _bookDao;
  final ChapterDao _chapterDao;
  final TxtParserService _txtParser;
  final EpubParserService _epubParser;

  Future<Book?> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'epub'],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.single.path == null) {
      return null;
    }

    return importFile(result.files.single.path!);
  }

  Future<Book> importFile(String sourcePath) async {
    final format = FileTypeDetector.detectFromPath(sourcePath);
    final copiedFile = await _copyToLocalBooksDirectory(sourcePath);
    final parsed = await _parseCopiedFile(copiedFile, format);

    if (parsed.chapters.isEmpty) {
      throw const FormatException('未能解析出章节内容');
    }

    final coverPath = await _saveOrGenerateCover(
      copiedFile: copiedFile,
      title: parsed.title,
      parsed: parsed,
    );

    final now = DateTime.now();
    final book = Book(
      title: parsed.title,
      author: parsed.author,
      filePath: copiedFile.path,
      coverPath: coverPath,
      format: FileTypeDetector.formatName(format),
      totalChapters: parsed.chapters.length,
      currentChapter: 0,
      currentPosition: 0,
      progress: 0,
      addedTime: now,
      lastReadTime: null,
    );

    final bookId = await _bookDao.insert(book);
    final chapters = parsed.chapters.indexed.map((entry) {
      final (index, draft) = entry;
      return Chapter(
        bookId: bookId,
        chapterIndex: index,
        title: draft.title.trim().isEmpty ? '第 ${index + 1} 章' : draft.title,
        content: draft.content,
      );
    }).toList(growable: false);

    await _chapterDao.insertAll(chapters);
    return book.copyWith(id: bookId);
  }

  Future<File> _copyToLocalBooksDirectory(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('文件不存在', sourcePath);
    }

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDir.path, 'wl_reader', 'books'));
    await booksDir.create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = p.extension(sourcePath).toLowerCase();
    final baseName = p.basenameWithoutExtension(sourcePath);
    final safeName = baseName.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5-]+'), '_');
    final targetPath = p.join(booksDir.path, '$timestamp-$safeName$extension');
    return sourceFile.copy(targetPath);
  }

  Future<ParsedBookDraft> _parseCopiedFile(
    File copiedFile,
    LocalBookFormat format,
  ) {
    return switch (format) {
      LocalBookFormat.txt => _txtParser.parse(copiedFile),
      LocalBookFormat.epub => _epubParser.parse(copiedFile),
    };
  }

  Future<String> _saveOrGenerateCover({
    required File copiedFile,
    required String title,
    required ParsedBookDraft parsed,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(appDir.path, 'wl_reader', 'covers'));
    await coversDir.create(recursive: true);

    final coverBaseName = p.basenameWithoutExtension(copiedFile.path);
    final coverBytes = parsed.coverBytes;
    final coverExtension = parsed.coverExtension;
    if (coverBytes != null && coverBytes.isNotEmpty && coverExtension != null) {
      final coverFile = File(p.join(coversDir.path, '$coverBaseName.$coverExtension'));
      await coverFile.writeAsBytes(coverBytes, flush: true);
      return coverFile.path;
    }

    return CoverGenerator.generateDefaultCover(
      title: title,
      outputPath: p.join(coversDir.path, '$coverBaseName.png'),
    );
  }
}

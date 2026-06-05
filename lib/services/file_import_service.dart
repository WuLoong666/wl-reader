import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/book_dao.dart';
import '../database/chapter_dao.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../utils/cover_generator.dart';
import '../utils/file_type_detector.dart';
import '../utils/natural_sort.dart';
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
  static const _comicImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
  };

  Future<Book?> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'epub', 'cbz', 'zip'],
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
    if (format.isComic) {
      return _importComicArchive(sourcePath, format);
    }

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
      bookType: format == LocalBookFormat.epub ? BookType.epub : BookType.text,
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

  Future<Book> _importComicArchive(
    String sourcePath,
    LocalBookFormat format,
  ) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('文件不存在', sourcePath);
    }

    final archive = await _decodeComicArchive(sourceFile);
    final imageEntries =
        archive.files.where(_isSupportedComicEntry).toList(growable: false)
          ..sort(
            (left, right) => naturalCompare(
              _normalizedArchivePath(left.name),
              _normalizedArchivePath(right.name),
            ),
          );

    if (imageEntries.isEmpty) {
      throw const FormatException(
        '压缩包中没有可导入的漫画图片，支持 JPG、JPEG、PNG、WEBP 和 GIF。',
      );
    }

    final comicDir = await _createComicDirectory(sourcePath);
    final pagePaths = <String>[];

    try {
      for (final entry in imageEntries.indexed) {
        final (index, archiveFile) = entry;
        final bytes = _archiveFileBytes(archiveFile);
        if (bytes.isEmpty) {
          continue;
        }

        final extension = p.extension(archiveFile.name).toLowerCase();
        final pageName = '${(index + 1).toString().padLeft(5, '0')}$extension';
        final pageFile = File(p.join(comicDir.path, pageName));
        await pageFile.writeAsBytes(bytes, flush: true);
        pagePaths.add(pageFile.path);
      }
    } catch (error) {
      throw FormatException('漫画解压失败，请确认压缩包没有损坏。$error');
    }

    if (pagePaths.isEmpty) {
      throw const FormatException(
        '压缩包中的漫画图片为空，无法导入。',
      );
    }

    final now = DateTime.now();
    final book = Book(
      title: _titleFromPath(sourcePath),
      author: '',
      filePath: comicDir.path,
      coverPath: pagePaths.first,
      format: FileTypeDetector.formatName(format),
      bookType: BookType.comic,
      totalChapters: pagePaths.length,
      currentChapter: 0,
      currentPosition: 0,
      progress: 0,
      addedTime: now,
      lastReadTime: null,
    );

    final bookId = await _bookDao.insert(book);
    return book.copyWith(id: bookId);
  }

  Future<Archive> _decodeComicArchive(File sourceFile) async {
    try {
      final bytes = await sourceFile.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('压缩包为空，无法导入漫画。');
      }
      return ZipDecoder().decodeBytes(bytes, verify: true);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('漫画压缩包无法打开，请确认文件未损坏。$error');
    }
  }

  bool _isSupportedComicEntry(ArchiveFile file) {
    if (!file.isFile || file.size <= 0) {
      return false;
    }

    final normalizedName = _normalizedArchivePath(file.name);
    if (normalizedName.isEmpty) {
      return false;
    }

    final segments = normalizedName.split('/');
    if (segments.any(_isIgnoredArchiveSegment)) {
      return false;
    }

    final extension = p.extension(normalizedName).toLowerCase();
    return _comicImageExtensions.contains(extension);
  }

  bool _isIgnoredArchiveSegment(String segment) {
    final normalizedSegment = segment.trim();
    if (normalizedSegment.isEmpty || normalizedSegment.startsWith('.')) {
      return true;
    }

    final lowerSegment = normalizedSegment.toLowerCase();
    return lowerSegment == '__macosx' || lowerSegment == '.ds_store';
  }

  String _normalizedArchivePath(String value) {
    var normalized = value.replaceAll(r'\', '/').trim();
    while (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    return normalized;
  }

  List<int> _archiveFileBytes(ArchiveFile file) {
    final content = file.content;
    if (content is List<int>) {
      return content;
    }
    throw FormatException('无法读取漫画图片：${file.name}');
  }

  Future<Directory> _createComicDirectory(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final comicsDir = Directory(p.join(appDir.path, 'wl_reader', 'comics'));
    await comicsDir.create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _safeBaseName(sourcePath);
    final targetDir = Directory(p.join(comicsDir.path, '$timestamp-$safeName'));
    await targetDir.create(recursive: true);
    return targetDir;
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
    final safeName = _safeBaseName(sourcePath);
    final targetPath = p.join(booksDir.path, '$timestamp-$safeName$extension');
    return sourceFile.copy(targetPath);
  }

  String _safeBaseName(String sourcePath) {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final safeName = baseName.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5-]+'), '_');
    return safeName.trim().isEmpty ? 'book' : safeName;
  }

  String _titleFromPath(String sourcePath) {
    final title = p.basenameWithoutExtension(sourcePath).trim();
    return title.isEmpty ? '未命名漫画' : title;
  }

  Future<ParsedBookDraft> _parseCopiedFile(
    File copiedFile,
    LocalBookFormat format,
  ) {
    return switch (format) {
      LocalBookFormat.txt => _txtParser.parse(copiedFile),
      LocalBookFormat.epub => _epubParser.parse(copiedFile),
      LocalBookFormat.cbz || LocalBookFormat.zip => throw StateError(
          '漫画格式不应进入文本解析流程',
        ),
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
      final coverFile =
          File(p.join(coversDir.path, '$coverBaseName.$coverExtension'));
      await coverFile.writeAsBytes(coverBytes, flush: true);
      return coverFile.path;
    }

    return CoverGenerator.generateDefaultCover(
      title: title,
      outputPath: p.join(coversDir.path, '$coverBaseName.png'),
    );
  }
}

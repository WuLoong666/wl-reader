import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../models/chapter.dart';
import '../utils/epub_path_resolver.dart';

class EpubParserService {
  Future<ParsedBookDraft> parse(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final container = _readArchiveText(archive, 'META-INF/container.xml');
      if (container == null) {
        throw const FormatException('EPUB 缺少 container.xml');
      }

      final opfPath = _findOpfPath(container);
      final opfText = _readArchiveText(archive, opfPath);
      if (opfText == null) {
        throw FormatException('EPUB 缺少 OPF 文件：$opfPath');
      }

      final opfDocument = XmlDocument.parse(opfText);
      final opfDir = p.posix.dirname(opfPath);
      final title = _firstElementText(opfDocument, 'title') ??
          p.basenameWithoutExtension(file.path);
      final author = _firstElementText(opfDocument, 'creator') ?? '';
      final manifest = _readManifest(opfDocument);
      final spine = _readSpine(opfDocument);
      final cover = _readCover(archive, opfDocument, manifest, opfDir);

      final chapters = _readChapters(
        archive: archive,
        manifest: manifest,
        spine: spine,
        opfDir: opfDir,
      );

      if (chapters.isEmpty) {
        throw const FormatException('未能从 EPUB 中读取到章节正文');
      }

      return ParsedBookDraft(
        title: title.trim().isEmpty ? '未命名 EPUB' : title.trim(),
        author: author.trim(),
        chapters: chapters,
        coverBytes: cover?.bytes,
        coverExtension: cover?.extension,
      );
    } catch (error) {
      throw FormatException('EPUB 解析失败：$error');
    }
  }

  String _findOpfPath(String containerXml) {
    final document = XmlDocument.parse(containerXml);
    for (final element in document.findAllElements('rootfile')) {
      final path = element.getAttribute('full-path');
      if (path != null && path.trim().isNotEmpty) {
        return _normalizeArchivePath(path);
      }
    }
    throw const FormatException('EPUB container.xml 中没有 rootfile');
  }

  Map<String, _ManifestItem> _readManifest(XmlDocument document) {
    final items = <String, _ManifestItem>{};
    for (final element in document.findAllElements('item')) {
      final id = element.getAttribute('id');
      final href = element.getAttribute('href');
      if (id == null || href == null || id.isEmpty || href.isEmpty) {
        continue;
      }
      items[id] = _ManifestItem(
        id: id,
        href: href,
        mediaType: element.getAttribute('media-type') ?? '',
        properties: element.getAttribute('properties') ?? '',
      );
    }
    return items;
  }

  List<String> _readSpine(XmlDocument document) {
    final ids = <String>[];
    for (final element in document.findAllElements('itemref')) {
      final idRef = element.getAttribute('idref');
      if (idRef != null && idRef.isNotEmpty) {
        ids.add(idRef);
      }
    }
    return ids;
  }

  List<ChapterDraft> _readChapters({
    required Archive archive,
    required Map<String, _ManifestItem> manifest,
    required List<String> spine,
    required String opfDir,
  }) {
    final orderedItems = spine
        .map((id) => manifest[id])
        .whereType<_ManifestItem>()
        .where((item) => _isHtmlItem(item))
        .toList();

    if (orderedItems.isEmpty) {
      orderedItems.addAll(manifest.values.where(_isHtmlItem));
    }

    final chapters = <ChapterDraft>[];
    for (final item in orderedItems) {
      final chapterPath = _joinArchivePath(opfDir, item.href);
      final html = _readArchiveText(archive, chapterPath);
      if (html == null) {
        continue;
      }

      final parsed = html_parser.parse(html);
      for (final element in parsed.querySelectorAll('script, style, nav')) {
        element.remove();
      }

      final images = _readChapterImages(
        archive: archive,
        parsed: parsed,
        chapterPath: chapterPath,
        opfDir: opfDir,
      );
      final heading = parsed.querySelector('h1, h2, h3, title')?.text.trim();
      final text = _cleanText(parsed.body?.text ?? parsed.outerHtml);
      if (text.isEmpty && images.isEmpty) {
        continue;
      }

      chapters.add(
        ChapterDraft(
          title: heading == null || heading.isEmpty
              ? '第 ${chapters.length + 1} 章'
              : heading,
          content: text,
          htmlContent: parsed.body?.innerHtml ?? parsed.outerHtml,
          epubImages: images,
        ),
      );
    }

    return chapters;
  }

  List<EpubImageAssetDraft> _readChapterImages({
    required Archive archive,
    required dynamic parsed,
    required String chapterPath,
    required String opfDir,
  }) {
    final images = <EpubImageAssetDraft>[];

    for (final image in parsed.querySelectorAll('img')) {
      final source = image.attributes['src']?.trim();
      if (source == null || source.isEmpty) {
        continue;
      }

      final archiveFile = _findImageArchiveFile(
        archive: archive,
        source: source,
        chapterPath: chapterPath,
        opfDir: opfDir,
      );
      if (archiveFile == null || !archiveFile.isFile) {
        continue;
      }

      final archivePath = _normalizeArchivePath(archiveFile.name);
      images.add(
        EpubImageAssetDraft(
          originalPath: source,
          archivePath: archivePath,
          relativeOutputPath: EpubPathResolver.outputRelativePath(
            archivePath: archivePath,
            opfDir: opfDir,
          ),
          bytes: _archiveFileBytes(archiveFile),
        ),
      );
    }

    return images;
  }

  _CoverData? _readCover(
    Archive archive,
    XmlDocument document,
    Map<String, _ManifestItem> manifest,
    String opfDir,
  ) {
    String? coverId;
    for (final meta in document.findAllElements('meta')) {
      if (meta.getAttribute('name') == 'cover') {
        coverId = meta.getAttribute('content');
        break;
      }
    }

    final coverItem = coverId == null ? null : manifest[coverId];
    final propertyCover = _firstWhereOrNull(manifest.values, (item) {
      return item.properties.split(' ').contains('cover-image');
    });

    final namedCover = _firstWhereOrNull(manifest.values, (item) {
      final value = '${item.id} ${item.href}'.toLowerCase();
      return value.contains('cover') && item.mediaType.startsWith('image/');
    });

    final item = coverItem ?? propertyCover ?? namedCover;
    if (item == null || !item.mediaType.startsWith('image/')) {
      return null;
    }

    final extension = _imageExtension(item.href, item.mediaType);
    if (extension == 'svg') {
      return null;
    }

    final file = _findArchiveFile(archive, _joinArchivePath(opfDir, item.href));
    if (file == null || !file.isFile) {
      return null;
    }
    return _CoverData(
        bytes: List<int>.from(file.content as List), extension: extension);
  }

  bool _isHtmlItem(_ManifestItem item) {
    return item.mediaType == 'application/xhtml+xml' ||
        item.mediaType == 'text/html' ||
        item.href.toLowerCase().endsWith('.xhtml') ||
        item.href.toLowerCase().endsWith('.html') ||
        item.href.toLowerCase().endsWith('.htm');
  }

  String? _firstElementText(XmlDocument document, String localName) {
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local.toLowerCase() == localName) {
        final text = element.innerText.trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  String? _readArchiveText(Archive archive, String archivePath) {
    final file = _findArchiveFile(archive, archivePath);
    if (file == null || !file.isFile) {
      return null;
    }
    final bytes = List<int>.from(file.content as List);
    return utf8.decode(bytes, allowMalformed: true);
  }

  ArchiveFile? _findArchiveFile(Archive archive, String archivePath) {
    final normalized = _normalizeArchivePath(archivePath);
    ArchiveFile? caseInsensitiveMatch;
    for (final file in archive.files) {
      final filePath = _normalizeArchivePath(file.name);
      if (filePath == normalized) {
        return file;
      }
      if (filePath.toLowerCase() == normalized.toLowerCase()) {
        caseInsensitiveMatch ??= file;
      }
    }
    return caseInsensitiveMatch;
  }

  ArchiveFile? _findImageArchiveFile({
    required Archive archive,
    required String source,
    required String chapterPath,
    required String opfDir,
  }) {
    final candidates = EpubPathResolver.imagePathCandidates(
      chapterPath: chapterPath,
      opfDir: opfDir,
      source: source,
    );
    for (final candidate in candidates) {
      if (!_isSupportedImagePath(candidate)) {
        continue;
      }
      final file = _findArchiveFile(archive, candidate);
      if (file != null) {
        return file;
      }
    }
    return null;
  }

  String _joinArchivePath(String baseDir, String href) {
    final pathOnly = EpubPathResolver.sourcePath(href) ?? href;
    if (baseDir == '.' || baseDir.isEmpty) {
      return _normalizeArchivePath(pathOnly);
    }
    return _normalizeArchivePath(
        p.posix.normalize(p.posix.join(baseDir, pathOnly)));
  }

  String _normalizeArchivePath(String path) {
    return EpubPathResolver.normalizeArchivePath(path);
  }

  String _cleanText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _imageExtension(String href, String mediaType) {
    final sourcePath = EpubPathResolver.sourcePath(href) ?? href;
    final extension =
        p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    if (extension.isNotEmpty) {
      return extension;
    }
    return switch (mediaType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/svg+xml' => 'svg',
      _ => 'png',
    };
  }

  bool _isSupportedImagePath(String path) {
    return switch (p.extension(path).toLowerCase()) {
      '.jpg' || '.jpeg' || '.png' || '.webp' || '.gif' => true,
      _ => false,
    };
  }

  List<int> _archiveFileBytes(ArchiveFile file) {
    final content = file.content;
    if (content is List<int>) {
      return List<int>.from(content);
    }
    return List<int>.from(content as List);
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
    for (final item in items) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}

class _ManifestItem {
  const _ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  final String id;
  final String href;
  final String mediaType;
  final String properties;
}

class _CoverData {
  const _CoverData({
    required this.bytes,
    required this.extension,
  });

  final List<int> bytes;
  final String extension;
}

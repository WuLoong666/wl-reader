import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../models/chapter.dart';
import '../models/epub_toc_item.dart';
import '../utils/epub_path_resolver.dart';
import '../utils/image_format.dart';

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
      final spineTocId = _readSpineTocId(opfDocument);
      final spinePathToIndex = _spinePathToIndex(
        manifest: manifest,
        spine: spine,
        opfDir: opfDir,
      );
      final tocItems = _mapTocItemsToSpine(
        _readTocItems(
          archive: archive,
          manifest: manifest,
          spineTocId: spineTocId,
          opfDir: opfDir,
        ),
        spinePathToIndex,
      );
      final cover = _readCover(archive, opfDocument, manifest, opfDir);

      final chapters = _readChapters(
        archive: archive,
        manifest: manifest,
        spine: spine,
        tocItems: tocItems,
        opfDir: opfDir,
      );

      if (chapters.isEmpty) {
        throw const FormatException('未能从 EPUB 中读取到章节正文');
      }

      return ParsedBookDraft(
        title: title.trim().isEmpty ? '未命名 EPUB' : title.trim(),
        author: author.trim(),
        chapters: chapters,
        tocItems: tocItems,
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

  String? _readSpineTocId(XmlDocument document) {
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local.toLowerCase() == 'spine') {
        final tocId = element.getAttribute('toc');
        if (tocId != null && tocId.trim().isNotEmpty) {
          return tocId.trim();
        }
      }
    }
    return null;
  }

  Map<String, int> _spinePathToIndex({
    required Map<String, _ManifestItem> manifest,
    required List<String> spine,
    required String opfDir,
  }) {
    final paths = <String, int>{};
    var spineIndex = 0;
    for (final id in spine) {
      final item = manifest[id];
      if (item == null || !_isHtmlItem(item)) {
        continue;
      }

      final path = _joinArchivePath(opfDir, item.href);
      paths.putIfAbsent(path, () => spineIndex);
      spineIndex += 1;
    }
    return paths;
  }

  List<EpubTocItemDraft> _mapTocItemsToSpine(
    List<EpubTocItemDraft> items,
    Map<String, int> spinePathToIndex,
  ) {
    return items.map((item) {
      final mappedChildren = _mapTocItemsToSpine(
        item.children,
        spinePathToIndex,
      );
      return EpubTocItemDraft(
        title: item.title,
        href: item.href,
        normalizedPath: item.normalizedPath,
        anchor: item.anchor,
        spineIndex: spinePathToIndex[item.normalizedPath],
        level: item.level,
        children: mappedChildren,
      );
    }).toList(growable: false);
  }

  List<EpubTocItemDraft> _readTocItems({
    required Archive archive,
    required Map<String, _ManifestItem> manifest,
    required String? spineTocId,
    required String opfDir,
  }) {
    final navItems = _readNavTocItems(
      archive: archive,
      manifest: manifest,
      opfDir: opfDir,
    );
    if (navItems.isNotEmpty) {
      return navItems;
    }

    return _readNcxTocItems(
      archive: archive,
      manifest: manifest,
      spineTocId: spineTocId,
      opfDir: opfDir,
    );
  }

  List<EpubTocItemDraft> _readNavTocItems({
    required Archive archive,
    required Map<String, _ManifestItem> manifest,
    required String opfDir,
  }) {
    final candidates = <_ManifestItem>[];
    for (final item in manifest.values) {
      if (_isNavManifestItem(item)) {
        candidates.add(item);
      }
    }
    for (final item in manifest.values) {
      final value = '${item.id} ${item.href}'.toLowerCase();
      if (_isHtmlItem(item) &&
          value.contains('nav') &&
          !candidates.any((candidate) => candidate.id == item.id)) {
        candidates.add(item);
      }
    }

    for (final item in candidates) {
      final navPath = _joinArchivePath(opfDir, item.href);
      final html = _readArchiveText(archive, navPath);
      if (html == null) {
        continue;
      }

      final document = html_parser.parse(html);
      final navElements = document
          .querySelectorAll('nav')
          .where(_isTocNavElement)
          .toList(growable: false);

      for (final navElement in navElements) {
        final tocItems = _readNavElementItems(
          navElement: navElement,
          navPath: navPath,
        );
        if (tocItems.isNotEmpty) {
          return _dedupeTocItems(tocItems);
        }
      }
    }

    return const [];
  }

  List<EpubTocItemDraft> _readNavElementItems({
    required html_dom.Element navElement,
    required String navPath,
  }) {
    final ol = _firstHtmlChildElement(navElement, 'ol') ??
        navElement.querySelector('ol');
    if (ol == null) {
      return const [];
    }
    return _readNavOlItems(ol: ol, navPath: navPath, level: 0);
  }

  List<EpubTocItemDraft> _readNavOlItems({
    required html_dom.Element ol,
    required String navPath,
    required int level,
  }) {
    final items = <EpubTocItemDraft>[];
    for (final li in ol.children.where((element) {
      return element.localName?.toLowerCase() == 'li';
    })) {
      final link = _firstHtmlChildElement(li, 'a') ?? li.querySelector('a[href]');
      final href = link?.attributes['href'];
      final title = _cleanTitle(link?.text);

      final childItems = <EpubTocItemDraft>[];
      for (final childOl in li.children.where((element) {
        return element.localName?.toLowerCase() == 'ol';
      })) {
        childItems.addAll(
          _readNavOlItems(ol: childOl, navPath: navPath, level: level + 1),
        );
      }

      if (href == null || title == null) {
        items.addAll(childItems);
        continue;
      }

      final tocItem = _tocItemFromHref(
        title: title,
        href: href,
        tocPath: navPath,
        level: level,
      );
      if (tocItem == null) {
        items.addAll(childItems);
        continue;
      }

      items.add(tocItem.withChildren(childItems));
      items.addAll(childItems);
    }
    return items;
  }

  bool _isNavManifestItem(_ManifestItem item) {
    return _isHtmlItem(item) && item.properties.split(' ').contains('nav');
  }

  List<EpubTocItemDraft> _dedupeTocItems(List<EpubTocItemDraft> items) {
    final seen = <String>{};
    final unique = <EpubTocItemDraft>[];
    for (final item in items) {
      final key = '${item.title}\u0000${item.href}\u0000${item.anchor}';
      if (seen.add(key)) {
        unique.add(item);
      }
    }
    return unique;
  }

  bool _isTocNavElement(html_dom.Element element) {
    for (final key in const ['epub:type', 'type', 'role']) {
      final value = element.attributes[key]?.toLowerCase();
      if (value == null) {
        continue;
      }
      final values = value.split(RegExp(r'\s+'));
      if (values.contains('toc') || value.contains('doc-toc')) {
        return true;
      }
    }
    return false;
  }

  List<EpubTocItemDraft> _readNcxTocItems({
    required Archive archive,
    required Map<String, _ManifestItem> manifest,
    required String? spineTocId,
    required String opfDir,
  }) {
    final candidates = <_ManifestItem>[
      if (spineTocId != null && manifest[spineTocId] != null)
        manifest[spineTocId]!,
    ];
    for (final item in manifest.values) {
      final value = '${item.id} ${item.href}'.toLowerCase();
      if ((item.mediaType == 'application/x-dtbncx+xml' ||
              value.contains('toc.ncx') ||
              value.endsWith('.ncx')) &&
          !candidates.any((candidate) => candidate.id == item.id)) {
        candidates.add(item);
      }
    }

    for (final item in candidates) {
      final ncxPath = _joinArchivePath(opfDir, item.href);
      final ncx = _readArchiveText(archive, ncxPath);
      if (ncx == null) {
        continue;
      }

      final document = XmlDocument.parse(ncx);
      XmlElement? navMap;
      for (final element in document.descendants.whereType<XmlElement>()) {
        if (element.name.local.toLowerCase() == 'navmap') {
          navMap = element;
          break;
        }
      }
      if (navMap == null) {
        continue;
      }
      final tocItems = <EpubTocItemDraft>[];
      for (final navPoint in navMap.childElements.where(_isNcxNavPoint)) {
        tocItems.addAll(
          _readNcxNavPointItems(
            navPoint: navPoint,
            ncxPath: ncxPath,
            level: 0,
          ),
        );
      }

      if (tocItems.isNotEmpty) {
        return _dedupeTocItems(tocItems);
      }
    }

    return const [];
  }

  List<EpubTocItemDraft> _readNcxNavPointItems({
    required XmlElement navPoint,
    required String ncxPath,
    required int level,
  }) {
    final label = _firstChildElement(navPoint, 'navLabel');
    final title = _cleanTitle(
      label == null ? null : _firstElementText(label, 'text'),
    );
    final content = _firstChildElement(navPoint, 'content');
    final href = content?.getAttribute('src');

    final childItems = <EpubTocItemDraft>[];
    for (final childNavPoint in navPoint.childElements.where(_isNcxNavPoint)) {
      childItems.addAll(
        _readNcxNavPointItems(
          navPoint: childNavPoint,
          ncxPath: ncxPath,
          level: level + 1,
        ),
      );
    }

    if (title == null || href == null || href.trim().isEmpty) {
      return childItems;
    }

    final tocItem = _tocItemFromHref(
      title: title,
      href: href,
      tocPath: ncxPath,
      level: level,
    );
    if (tocItem == null) {
      return childItems;
    }

    return [
      tocItem.withChildren(childItems),
      ...childItems,
    ];
  }

  bool _isNcxNavPoint(XmlElement element) {
    return element.name.local.toLowerCase() == 'navpoint';
  }

  List<ChapterDraft> _readChapters({
    required Archive archive,
    required Map<String, _ManifestItem> manifest,
    required List<String> spine,
    required List<EpubTocItemDraft> tocItems,
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

    final tocItemsByPath = <String, List<EpubTocItemDraft>>{};
    for (final tocItem in tocItems) {
      tocItemsByPath
          .putIfAbsent(tocItem.normalizedPath, () => [])
          .add(tocItem);
    }
    final manifestByArchivePath = _manifestByArchivePath(manifest, opfDir);

    final chapters = <ChapterDraft>[];
    for (final item in orderedItems) {
      final chapterPath = _joinArchivePath(opfDir, item.href);
      final html = _readArchiveText(archive, chapterPath);
      if (html == null) {
        continue;
      }
      final tocItem = _firstTocItemForPath(tocItemsByPath, chapterPath);

      final parsed = html_parser.parse(html);
      for (final element in parsed.querySelectorAll('script, style, nav')) {
        element.remove();
      }

      final images = _readChapterImages(
        archive: archive,
        manifestByArchivePath: manifestByArchivePath,
        parsed: parsed,
        chapterPath: chapterPath,
        opfDir: opfDir,
      );
      final heading = _cleanTitle(
        parsed.querySelector('h1, h2, h3')?.text,
      );
      final text = _cleanText(parsed.body?.text ?? parsed.outerHtml);
      final title = tocItem?.title ??
          heading ??
          _firstTextTitle(text) ??
          'Spine ${chapters.length + 1}';

      chapters.add(
        ChapterDraft(
          title: title,
          content: text,
          htmlContent: parsed.body?.innerHtml ?? parsed.outerHtml,
          sourcePath: chapterPath,
          anchor: tocItem?.anchor ?? '',
          epubImages: images,
        ),
      );
    }

    return chapters;
  }

  EpubTocItemDraft? _firstTocItemForPath(
    Map<String, List<EpubTocItemDraft>> tocItemsByPath,
    String chapterPath,
  ) {
    final items = tocItemsByPath[_normalizeArchivePath(chapterPath)];
    if (items == null || items.isEmpty) {
      return null;
    }
    return items.first;
  }

  String? _firstTextTitle(String text) {
    for (final line in text.split('\n')) {
      final title = _cleanTitle(line);
      if (title != null) {
        return title.length <= 48 ? title : title.substring(0, 48);
      }
    }
    return null;
  }

  List<EpubImageAssetDraft> _readChapterImages({
    required Archive archive,
    required Map<String, _ManifestItem> manifestByArchivePath,
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

      final imageAsset = _findImageArchiveAsset(
        archive: archive,
        manifestByArchivePath: manifestByArchivePath,
        source: source,
        chapterPath: chapterPath,
        opfDir: opfDir,
      );
      if (imageAsset == null || !imageAsset.file.isFile) {
        continue;
      }

      images.add(
        EpubImageAssetDraft(
          originalPath: source,
          archivePath: imageAsset.archivePath,
          relativeOutputPath: _imageOutputRelativePath(
            archivePath: imageAsset.archivePath,
            opfDir: opfDir,
            mediaType: imageAsset.mediaType,
          ),
          bytes: _archiveFileBytes(imageAsset.file),
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
      return value.contains('cover') && _isImageManifestItem(item);
    });

    final item = _firstWhereOrNull(
      [
        if (coverItem != null) coverItem,
        if (propertyCover != null) propertyCover,
        if (namedCover != null) namedCover,
      ],
      _isImageManifestItem,
    );
    if (item == null) {
      return null;
    }

    final extension = _imageExtension(item.href, item.mediaType);
    if (extension.isEmpty) {
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

  String? _firstElementText(XmlNode node, String localName) {
    for (final element in node.descendants.whereType<XmlElement>()) {
      if (element.name.local.toLowerCase() == localName) {
        final text = element.innerText.trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  XmlElement? _firstChildElement(XmlElement element, String localName) {
    for (final child in element.childElements) {
      if (child.name.local.toLowerCase() == localName.toLowerCase()) {
        return child;
      }
    }
    return null;
  }

  html_dom.Element? _firstHtmlChildElement(
    html_dom.Element element,
    String localName,
  ) {
    for (final child in element.children) {
      if (child.localName?.toLowerCase() == localName.toLowerCase()) {
        return child;
      }
    }
    return null;
  }

  String? _cleanTitle(String? text) {
    if (text == null) {
      return null;
    }
    final cleaned = _cleanText(text);
    return cleaned.isEmpty ? null : cleaned;
  }

  EpubTocItemDraft? _tocItemFromHref({
    required String title,
    required String href,
    required String tocPath,
    required int level,
  }) {
    final normalizedPath = _resolveTocHrefPath(tocPath: tocPath, href: href);
    if (normalizedPath.isEmpty) {
      return null;
    }
    return EpubTocItemDraft(
      title: title,
      href: href.trim(),
      normalizedPath: normalizedPath,
      anchor: _hrefAnchor(href) ?? '',
      level: level,
    );
  }

  String _resolveTocHrefPath({
    required String tocPath,
    required String href,
  }) {
    final sourcePath = EpubPathResolver.sourcePath(href);
    if (sourcePath == null) {
      return '';
    }
    if (sourcePath.isEmpty) {
      return _normalizeArchivePath(tocPath);
    }
    if (sourcePath.startsWith('/')) {
      return _normalizeArchivePath(sourcePath);
    }
    return _normalizeArchivePath(
      p.posix.normalize(p.posix.join(p.posix.dirname(tocPath), sourcePath)),
    );
  }

  String? _hrefAnchor(String href) {
    final parsed = Uri.tryParse(href.trim());
    final fragment = parsed?.fragment;
    if (fragment != null && fragment.isNotEmpty) {
      return _decodeUriComponent(fragment);
    }

    final hashIndex = href.indexOf('#');
    if (hashIndex < 0 || hashIndex >= href.length - 1) {
      return null;
    }
    final rawAnchor = href.substring(hashIndex + 1).split('?').first;
    return rawAnchor.isEmpty ? null : _decodeUriComponent(rawAnchor);
  }

  String _decodeUriComponent(String value) {
    try {
      return Uri.decodeComponent(value);
    } on FormatException {
      return value;
    }
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

  Map<String, _ManifestItem> _manifestByArchivePath(
    Map<String, _ManifestItem> manifest,
    String opfDir,
  ) {
    final items = <String, _ManifestItem>{};
    for (final item in manifest.values) {
      final archivePath = _joinArchivePath(opfDir, item.href);
      items[archivePath] = item;
    }
    return items;
  }

  _ImageArchiveAsset? _findImageArchiveAsset({
    required Archive archive,
    required Map<String, _ManifestItem> manifestByArchivePath,
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
      final manifestItem =
          _manifestItemForPath(manifestByArchivePath, candidate);
      if (manifestItem != null && !_isImageManifestItem(manifestItem)) {
        continue;
      }
      final file = _findArchiveFile(archive, candidate);
      if (file != null) {
        return _ImageArchiveAsset(
          file: file,
          archivePath: _normalizeArchivePath(file.name),
          mediaType: manifestItem?.mediaType ?? '',
        );
      }
    }
    return null;
  }

  _ManifestItem? _manifestItemForPath(
    Map<String, _ManifestItem> manifestByArchivePath,
    String archivePath,
  ) {
    final normalized = _normalizeArchivePath(archivePath);
    final direct = manifestByArchivePath[normalized];
    if (direct != null) {
      return direct;
    }

    for (final entry in manifestByArchivePath.entries) {
      if (entry.key.toLowerCase() == normalized.toLowerCase()) {
        return entry.value;
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
    return _imageExtensionFromMediaType(mediaType);
  }

  String _imageOutputRelativePath({
    required String archivePath,
    required String opfDir,
    required String mediaType,
  }) {
    final relativePath = EpubPathResolver.outputRelativePath(
      archivePath: archivePath,
      opfDir: opfDir,
    );
    if (p.extension(relativePath).isNotEmpty) {
      return relativePath;
    }

    final extension = _imageExtensionFromMediaType(mediaType);
    if (extension.isEmpty) {
      return relativePath;
    }
    return '$relativePath.$extension';
  }

  String _imageExtensionFromMediaType(String mediaType) {
    return ImageFormat.extensionFromMediaType(mediaType);
  }

  bool _isImageManifestItem(_ManifestItem item) {
    if (ImageFormat.isImageMediaType(item.mediaType)) {
      return true;
    }
    return ImageFormat.fromPath(item.href) != ImageFileFormat.unknown ||
        ImageFormat.extensionFromMediaType(item.mediaType).isNotEmpty;
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

class _ImageArchiveAsset {
  const _ImageArchiveAsset({
    required this.file,
    required this.archivePath,
    required this.mediaType,
  });

  final ArchiveFile file;
  final String archivePath;
  final String mediaType;
}

class _CoverData {
  const _CoverData({
    required this.bytes,
    required this.extension,
  });

  final List<int> bytes;
  final String extension;
}

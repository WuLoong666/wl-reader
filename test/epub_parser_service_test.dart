import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wl_reader/services/epub_parser_service.dart';

void main() {
  test('keeps html and extracts chapter images from relative paths', () async {
    final file = await _writeTempEpub({
      'META-INF/container.xml': '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''',
      'OEBPS/content.opf': '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata>
    <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Sample</dc:title>
  </metadata>
  <manifest>
    <item id="plain" href="Text/plain.xhtml" media-type="application/xhtml+xml"/>
    <item id="pic1" href="Text/pic1.xhtml" media-type="application/xhtml+xml"/>
    <item id="pic2" href="Text/pic2.xhtml" media-type="application/xhtml+xml"/>
    <item id="missing" href="Text/missing.xhtml" media-type="application/xhtml+xml"/>
    <item id="img1" href="Text/images/001.jpg" media-type="image/jpeg"/>
    <item id="img2" href="Images/002.PNG" media-type="image/png"/>
  </manifest>
  <spine>
    <itemref idref="plain"/>
    <itemref idref="pic1"/>
    <itemref idref="pic2"/>
    <itemref idref="missing"/>
  </spine>
</package>
''',
      'OEBPS/Text/plain.xhtml': '<html><body><p>Only text.</p></body></html>',
      'OEBPS/Text/pic1.xhtml':
          '<html><body><p>Before.</p><img src="images/001.jpg" /></body></html>',
      'OEBPS/Text/pic2.xhtml':
          '<html><body><img src="../Images/002.PNG" /><p>After.</p></body></html>',
      'OEBPS/Text/missing.xhtml':
          '<html><body><p>Missing.</p><img src="../Images/nope.jpg" /></body></html>',
      'OEBPS/Text/images/001.jpg': [1, 2, 3],
      'OEBPS/Images/002.PNG': [4, 5, 6],
    });
    addTearDown(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final parsed = await EpubParserService().parse(file);

    expect(parsed.title, 'Sample');
    expect(parsed.chapters, hasLength(4));
    expect(parsed.chapters[0].content, 'Only text.');
    expect(parsed.chapters[0].htmlContent, contains('<p>Only text.</p>'));

    expect(parsed.chapters[1].epubImages.single.archivePath,
        'OEBPS/Text/images/001.jpg');
    expect(
      parsed.chapters[1].epubImages.single.relativeOutputPath
          .replaceAll(r'\', '/'),
      'Text/images/001.jpg',
    );

    expect(parsed.chapters[2].epubImages.single.archivePath,
        'OEBPS/Images/002.PNG');
    expect(
      parsed.chapters[2].epubImages.single.relativeOutputPath
          .replaceAll(r'\', '/'),
      'Images/002.PNG',
    );

    expect(parsed.chapters[3].epubImages, isEmpty);
  });

  test('extracts png webp gif svg and media typed image paths', () async {
    final file = await _writeTempEpub({
      'META-INF/container.xml': _containerXml,
      'OEBPS/content.opf': '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata>
    <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Image Types</dc:title>
  </metadata>
  <manifest>
    <item id="chapter" href="Text/chapter.xhtml" media-type="application/xhtml+xml"/>
    <item id="png" href="Images/%E5%9B%BE%20001.PNG" media-type="image/png"/>
    <item id="webp" href="Images/panel.webp" media-type="image/webp"/>
    <item id="gif" href="Images/anim.GIF" media-type="image/gif"/>
    <item id="svg" href="Images/%E6%8C%BF%E7%B5%B5%2004.svg" media-type="image/svg+xml"/>
    <item id="noext" href="Images/no_extension" media-type="image/png"/>
  </manifest>
  <spine>
    <itemref idref="chapter"/>
  </spine>
</package>
''',
      'OEBPS/Text/chapter.xhtml': '''
<html><body>
  <p>Pictures.</p>
  <img src="../Images/%E5%9B%BE%20001.PNG" />
  <img src="../Images/panel.webp" />
  <img src="../Images/anim.GIF" />
  <img src="../Images/%E6%8C%BF%E7%B5%B5%2004.svg" />
  <img src="../Images/no_extension" />
</body></html>
''',
      'OEBPS/Images/\u56fe 001.PNG': [1],
      'OEBPS/Images/panel.webp': [2],
      'OEBPS/Images/anim.GIF': [3],
      'OEBPS/Images/\u633f\u7d75 04.svg': utf8.encode('<svg></svg>'),
      'OEBPS/Images/no_extension': [4],
    });
    addTearDown(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final parsed = await EpubParserService().parse(file);
    final images = parsed.chapters.single.epubImages;

    expect(images, hasLength(5));
    expect(
      images.map((image) => image.archivePath),
      [
        'OEBPS/Images/\u56fe 001.PNG',
        'OEBPS/Images/panel.webp',
        'OEBPS/Images/anim.GIF',
        'OEBPS/Images/\u633f\u7d75 04.svg',
        'OEBPS/Images/no_extension',
      ],
    );
    expect(
      images
          .map((image) => image.relativeOutputPath.replaceAll(r'\', '/'))
          .toList(),
      [
        'Images/\u56fe 001.PNG',
        'Images/panel.webp',
        'Images/anim.GIF',
        'Images/\u633f\u7d75 04.svg',
        'Images/no_extension.png',
      ],
    );
  });

  test('reads png webp and svg covers from epub manifest', () async {
    final cases = [
      (extension: 'png', mediaType: 'image/png', bytes: [1, 2, 3]),
      (extension: 'webp', mediaType: 'image/webp', bytes: [4, 5, 6]),
      (
        extension: 'svg',
        mediaType: 'image/svg+xml',
        bytes: utf8.encode('<svg></svg>'),
      ),
    ];

    for (final coverCase in cases) {
      final file = await _writeTempEpub({
        'META-INF/container.xml': _containerXml,
        'OEBPS/content.opf': '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata>
    <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Cover ${coverCase.extension}</dc:title>
  </metadata>
  <manifest>
    <item id="cover" href="Images/cover.${coverCase.extension}" media-type="${coverCase.mediaType}" properties="cover-image"/>
    <item id="chapter" href="Text/chapter.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chapter"/>
  </spine>
</package>
''',
        'OEBPS/Text/chapter.xhtml': '<html><body><p>Chapter.</p></body></html>',
        'OEBPS/Images/cover.${coverCase.extension}': coverCase.bytes,
      });
      addTearDown(() {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });

      final parsed = await EpubParserService().parse(file);

      expect(parsed.coverExtension, coverCase.extension);
      expect(parsed.coverBytes, coverCase.bytes);
    }
  });

  test('uses epub3 nav toc titles while preserving spine order', () async {
    final file = await _writeTempEpub({
      'META-INF/container.xml': _containerXml,
      'OEBPS/content.opf': '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata>
    <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Nav Sample</dc:title>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="cover" href="Text/cover.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter1" href="Text/chapter001.xhtml" media-type="application/xhtml+xml"/>
    <item id="colophon" href="Text/colophon.xhtml" media-type="application/xhtml+xml"/>
    <item id="img1" href="Images/001.jpg" media-type="image/jpeg"/>
  </manifest>
  <spine>
    <itemref idref="cover"/>
    <itemref idref="nav"/>
    <itemref idref="chapter1"/>
    <itemref idref="colophon"/>
  </spine>
</package>
''',
      'OEBPS/nav.xhtml': '''
<html xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="Text/cover.xhtml">表纸</a></li>
        <li><a href="nav.xhtml">目录</a></li>
        <li><a href="Text/chapter001.xhtml#section1">～ 1 敗目 ～　潮風の告白</a></li>
        <li><a href="Text/colophon.xhtml">奥付</a></li>
      </ol>
    </nav>
  </body>
</html>
''',
      'OEBPS/Text/cover.xhtml': '<html><body><p>Cover page.</p></body></html>',
      'OEBPS/Text/chapter001.xhtml': '''
<html><body><h1>Wrong fallback title</h1><p>Chapter text.</p><img src="../Images/001.jpg" /></body></html>
''',
      'OEBPS/Text/colophon.xhtml': '<html><body><p>Colophon.</p></body></html>',
      'OEBPS/Images/001.jpg': [7, 8, 9],
    });
    addTearDown(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final parsed = await EpubParserService().parse(file);

    expect(
      parsed.chapters.map((chapter) => chapter.title),
      ['表纸', '目录', '～ 1 敗目 ～　潮風の告白', '奥付'],
    );
    expect(parsed.chapters[2].sourcePath, 'OEBPS/Text/chapter001.xhtml');
    expect(parsed.chapters[2].anchor, 'section1');
    expect(parsed.chapters[2].epubImages.single.archivePath,
        'OEBPS/Images/001.jpg');
  });

  test('uses epub2 ncx toc titles without adding spine fallback to toc',
      () async {
    final file = await _writeTempEpub({
      'META-INF/container.xml': _containerXml,
      'OEBPS/content.opf': '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata>
    <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">NCX Sample</dc:title>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="intro" href="Text/intro.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter1" href="Text/chapter001.xhtml" media-type="application/xhtml+xml"/>
    <item id="fallback" href="Text/fallback.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="intro"/>
    <itemref idref="chapter1"/>
    <itemref idref="fallback"/>
  </spine>
</package>
''',
      'OEBPS/toc.ncx': '''
<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/">
  <navMap>
    <navPoint id="intro" playOrder="1">
      <navLabel><text>序章</text></navLabel>
      <content src="Text/intro.xhtml#top"/>
    </navPoint>
    <navPoint id="chapter1" playOrder="2">
      <navLabel><text>第一章 中文标题</text></navLabel>
      <content src="Text/chapter001.xhtml"/>
    </navPoint>
  </navMap>
</ncx>
''',
      'OEBPS/Text/intro.xhtml': '<html><body><p>Intro.</p></body></html>',
      'OEBPS/Text/chapter001.xhtml':
          '<html><body><h1>Wrong heading</h1><p>Chapter text.</p></body></html>',
      'OEBPS/Text/fallback.xhtml':
          '<html><head><title>Fallback Title</title></head><body><p>Fallback.</p></body></html>',
    });
    addTearDown(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final parsed = await EpubParserService().parse(file);

    expect(
      parsed.chapters.map((chapter) => chapter.title),
      ['序章', '第一章 中文标题', 'Fallback.'],
    );
    expect(parsed.tocItems.map((item) => item.title), ['序章', '第一章 中文标题']);
    expect(parsed.displayChapterCount, 2);
    expect(parsed.chapters.first.anchor, 'top');
  });

  test('keeps nav toc count separate from 51 spine items', () async {
    final tocEntries = List.generate(
      11,
      (index) => _NavTocEntry(
        'Toc ${index + 1}',
        'Text/chapter${(index + 1).toString().padLeft(3, '0')}.xhtml',
      ),
    );
    final file = await _writeSyntheticNavEpub(
      spineCount: 51,
      tocEntries: tocEntries,
    );
    addTearDown(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final parsed = await EpubParserService().parse(file);

    expect(parsed.chapters, hasLength(51));
    expect(parsed.tocItems, hasLength(11));
    expect(parsed.displayChapterCount, 11);
    expect(parsed.tocItems.first.title, 'Toc 1');
  });

  test('repeated html title does not pollute nav toc', () async {
    const repeatedTitle =
        '\u8ca0\u3051\u30d2\u30ed\u30a4\u30f3\u304c\u591a\u3059\u304e\u308b\uff01 6';
    final file = await _writeSyntheticNavEpub(
      spineCount: 4,
      tocEntries: const [
        _NavTocEntry('Real chapter 1', 'Text/chapter001.xhtml'),
        _NavTocEntry('Real chapter 2', 'Text/chapter002.xhtml'),
      ],
      htmlTitle: repeatedTitle,
    );
    addTearDown(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final parsed = await EpubParserService().parse(file);

    expect(
      parsed.tocItems.map((item) => item.title),
      ['Real chapter 1', 'Real chapter 2'],
    );
    expect(parsed.tocItems.map((item) => item.title), isNot(contains(repeatedTitle)));
    expect(parsed.displayChapterCount, 2);
  });

  test('keeps cover toc and colophon nav items', () async {
    const cover = '\u8868\u7eb8';
    const toc = '\u76ee\u5f55';
    const colophon = '\u5965\u4ed8';
    final file = await _writeSyntheticNavEpub(
      spineCount: 3,
      includeNavInSpine: true,
      tocEntries: const [
        _NavTocEntry(cover, 'Text/chapter001.xhtml'),
        _NavTocEntry(toc, 'nav.xhtml'),
        _NavTocEntry(colophon, 'Text/chapter003.xhtml'),
      ],
    );
    addTearDown(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final parsed = await EpubParserService().parse(file);

    expect(parsed.tocItems.map((item) => item.title), [cover, toc, colophon]);
  });

  test('keeps multiple toc items for the same spine file with different anchors',
      () async {
    final file = await _writeSyntheticNavEpub(
      spineCount: 1,
      tocEntries: const [
        _NavTocEntry('Scene A', 'Text/chapter001.xhtml#a'),
        _NavTocEntry('Scene B', 'Text/chapter001.xhtml#b'),
      ],
    );
    addTearDown(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final parsed = await EpubParserService().parse(file);

    expect(parsed.tocItems, hasLength(2));
    expect(parsed.tocItems.map((item) => item.spineIndex), [0, 0]);
    expect(parsed.tocItems.map((item) => item.anchor), ['a', 'b']);
    expect(parsed.displayChapterCount, 2);
  });

  test('uses spine fallback count only when nav and ncx are missing', () async {
    final file = await _writeSyntheticSpineOnlyEpub(spineCount: 5);
    addTearDown(() {
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final parsed = await EpubParserService().parse(file);

    expect(parsed.tocItems, isEmpty);
    expect(parsed.chapters, hasLength(5));
    expect(parsed.displayChapterCount, 5);
  });
}

const _containerXml = '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

class _NavTocEntry {
  const _NavTocEntry(this.title, this.href);

  final String title;
  final String href;
}

Future<File> _writeSyntheticNavEpub({
  required int spineCount,
  required List<_NavTocEntry> tocEntries,
  String htmlTitle = 'Shared title',
  bool includeNavInSpine = false,
}) {
  final entries = _syntheticSpineEntries(
    spineCount: spineCount,
    htmlTitle: htmlTitle,
  );
  entries['META-INF/container.xml'] = _containerXml;
  entries['OEBPS/content.opf'] = _syntheticOpf(
    spineCount: spineCount,
    includeNav: true,
    includeNavInSpine: includeNavInSpine,
  );
  entries['OEBPS/nav.xhtml'] = _syntheticNav(tocEntries);
  return _writeTempEpub(entries);
}

Future<File> _writeSyntheticSpineOnlyEpub({required int spineCount}) {
  final entries = _syntheticSpineEntries(spineCount: spineCount);
  entries['META-INF/container.xml'] = _containerXml;
  entries['OEBPS/content.opf'] = _syntheticOpf(
    spineCount: spineCount,
    includeNav: false,
  );
  return _writeTempEpub(entries);
}

Map<String, Object> _syntheticSpineEntries({
  required int spineCount,
  String htmlTitle = 'Shared title',
}) {
  return {
    for (var index = 1; index <= spineCount; index += 1)
      'OEBPS/Text/chapter${index.toString().padLeft(3, '0')}.xhtml': '''
<html>
  <head><title>$htmlTitle</title></head>
  <body>
    <p id="a">Body $index A.</p>
    <p id="b">Body $index B.</p>
  </body>
</html>
''',
  };
}

String _syntheticOpf({
  required int spineCount,
  required bool includeNav,
  bool includeNavInSpine = false,
}) {
  final manifest = StringBuffer();
  if (includeNav) {
    manifest.writeln(
      '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
    );
  }
  for (var index = 1; index <= spineCount; index += 1) {
    manifest.writeln(
      '<item id="chapter$index" href="Text/chapter${index.toString().padLeft(3, '0')}.xhtml" media-type="application/xhtml+xml"/>',
    );
  }

  final spine = StringBuffer();
  if (includeNav && includeNavInSpine) {
    spine.writeln('<itemref idref="nav"/>');
  }
  for (var index = 1; index <= spineCount; index += 1) {
    spine.writeln('<itemref idref="chapter$index"/>');
  }

  return '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata>
    <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">Synthetic</dc:title>
  </metadata>
  <manifest>
$manifest
  </manifest>
  <spine>
$spine
  </spine>
</package>
''';
}

String _syntheticNav(List<_NavTocEntry> entries) {
  final items = entries.map((entry) {
    return '<li><a href="${entry.href}">${entry.title}</a></li>';
  }).join('\n');
  return '''
<html xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
$items
      </ol>
    </nav>
  </body>
</html>
''';
}

Future<File> _writeTempEpub(Map<String, Object> entries) async {
  final archive = Archive();
  for (final entry in entries.entries) {
    final content = entry.value;
    final bytes =
        content is List<int> ? content : utf8.encode(content as String);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }

  final bytes = ZipEncoder().encode(archive);
  final path =
      '${Directory.systemTemp.path}/wl_reader_epub_test_${DateTime.now().microsecondsSinceEpoch}.epub';
  final file = File(path);
  await file.writeAsBytes(bytes!, flush: true);
  return file;
}

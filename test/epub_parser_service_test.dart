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

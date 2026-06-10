import 'package:flutter_test/flutter_test.dart';
import 'package:wl_reader/utils/epub_path_resolver.dart';

void main() {
  test('resolves chapter relative image paths', () {
    final candidates = EpubPathResolver.imagePathCandidates(
      chapterPath: 'OEBPS/Text/chapter1.xhtml',
      opfDir: 'OEBPS',
      source: '../Images/001.jpg',
    );

    expect(candidates.first, 'OEBPS/Images/001.jpg');
    expect(candidates, contains('Images/001.jpg'));
  });

  test('handles url encoded paths and root-like manifest paths', () {
    final candidates = EpubPathResolver.imagePathCandidates(
      chapterPath: 'OEBPS/chapter1.xhtml',
      opfDir: 'OEBPS',
      source: 'Images/pic%2001.PNG?size=large#cover',
    );

    expect(candidates, contains('OEBPS/Images/pic 01.PNG'));
  });

  test('strips opf directory for stable local output paths', () {
    final relativePath = EpubPathResolver.outputRelativePath(
      archivePath: 'OEBPS/Images/001.JPG',
      opfDir: 'OEBPS',
    );

    expect(relativePath.replaceAll(r'\', '/'), 'Images/001.JPG');
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:wl_reader/models/comic_display_page.dart';
import 'package:wl_reader/services/comic_page_splitter.dart';

void main() {
  group('ComicPageSplitter', () {
    test('splits wide pages in right-to-left order and reuses cache', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'comic_page_splitter_',
      );
      final cacheDir = Directory(p.join(tempDir.path, 'cache'));
      final sourcePath = p.join(tempDir.path, 'wide.jpg');
      final leftCachePath = p.join(cacheDir.path, '00000_page_left.jpg');
      final rightCachePath = p.join(cacheDir.path, '00000_page_right.jpg');
      final sourceFile = File(sourcePath);
      await sourceFile.writeAsBytes(
        img.encodeJpg(img.Image(width: 400, height: 200)),
        flush: true,
      );

      addTearDown(() async {
        await _deleteFileIfExists(sourcePath);
        await _deleteFileIfExists(leftCachePath);
        await _deleteFileIfExists(rightCachePath);
        await _deleteDirectoryIfExists(cacheDir);
        await _deleteDirectoryIfExists(tempDir);
      });

      final displayPages = await ComicPageSplitter.buildDisplayPages(
        imagePaths: [sourcePath],
        cacheDir: cacheDir,
        autoSplitWidePages: true,
        readingDirection: ComicReadingDirection.rightToLeft,
      );

      expect(displayPages, hasLength(2));
      expect(displayPages[0].part, ComicPagePart.right);
      expect(displayPages[1].part, ComicPagePart.left);
      expect(p.basename(displayPages[0].imagePath), '00000_page_right.jpg');
      expect(p.basename(displayPages[1].imagePath), '00000_page_left.jpg');
      expect(await File(displayPages[0].imagePath).exists(), isTrue);
      expect(await File(displayPages[1].imagePath).exists(), isTrue);

      await File(leftCachePath).writeAsString('left cache', flush: true);
      await File(rightCachePath).writeAsString('right cache', flush: true);
      final cachedDisplayPages = await ComicPageSplitter.buildDisplayPages(
        imagePaths: [sourcePath],
        cacheDir: cacheDir,
        autoSplitWidePages: true,
        readingDirection: ComicReadingDirection.leftToRight,
      );

      expect(cachedDisplayPages, hasLength(2));
      expect(cachedDisplayPages[0].part, ComicPagePart.left);
      expect(cachedDisplayPages[1].part, ComicPagePart.right);
      expect(await File(leftCachePath).readAsString(), 'left cache');
      expect(await File(rightCachePath).readAsString(), 'right cache');
    });

    test('returns full pages when auto split is disabled', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'comic_page_splitter_',
      );
      final cacheDir = Directory(p.join(tempDir.path, 'cache'));
      final sourcePath = p.join(tempDir.path, 'wide.jpg');
      await File(sourcePath).writeAsBytes(
        img.encodeJpg(img.Image(width: 400, height: 200)),
        flush: true,
      );

      addTearDown(() async {
        await _deleteFileIfExists(sourcePath);
        await _deleteDirectoryIfExists(cacheDir);
        await _deleteDirectoryIfExists(tempDir);
      });

      final displayPages = await ComicPageSplitter.buildDisplayPages(
        imagePaths: [sourcePath],
        cacheDir: cacheDir,
        autoSplitWidePages: false,
        readingDirection: ComicReadingDirection.rightToLeft,
      );

      expect(displayPages, hasLength(1));
      expect(displayPages.single.imagePath, sourcePath);
      expect(displayPages.single.part, ComicPagePart.full);
      expect(await cacheDir.exists(), isFalse);
    });

    test('ignores stale split cache when source page is not wide', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'comic_page_splitter_',
      );
      final cacheDir = Directory(p.join(tempDir.path, 'cache'));
      await cacheDir.create();
      final sourcePath = p.join(tempDir.path, 'normal.jpg');
      final leftCachePath = p.join(cacheDir.path, '00000_page_left.jpg');
      final rightCachePath = p.join(cacheDir.path, '00000_page_right.jpg');
      await File(sourcePath).writeAsBytes(
        img.encodeJpg(img.Image(width: 200, height: 300)),
        flush: true,
      );
      await File(leftCachePath).writeAsBytes(
        img.encodeJpg(img.Image(width: 100, height: 300)),
        flush: true,
      );
      await File(rightCachePath).writeAsBytes(
        img.encodeJpg(img.Image(width: 100, height: 300)),
        flush: true,
      );

      addTearDown(() async {
        await _deleteFileIfExists(sourcePath);
        await _deleteFileIfExists(leftCachePath);
        await _deleteFileIfExists(rightCachePath);
        await _deleteDirectoryIfExists(cacheDir);
        await _deleteDirectoryIfExists(tempDir);
      });

      final displayPages = await ComicPageSplitter.buildDisplayPages(
        imagePaths: [sourcePath],
        cacheDir: cacheDir,
        autoSplitWidePages: true,
        readingDirection: ComicReadingDirection.rightToLeft,
      );

      expect(displayPages, hasLength(1));
      expect(displayPages.single.imagePath, sourcePath);
      expect(displayPages.single.part, ComicPagePart.full);
    });

    test('falls back to full page when decoding fails', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'comic_page_splitter_',
      );
      final cacheDir = Directory(p.join(tempDir.path, 'cache'));
      final sourcePath = p.join(tempDir.path, 'broken.jpg');
      await File(sourcePath).writeAsString('not an image', flush: true);

      addTearDown(() async {
        await _deleteFileIfExists(sourcePath);
        await _deleteDirectoryIfExists(cacheDir);
        await _deleteDirectoryIfExists(tempDir);
      });

      final displayPages = await ComicPageSplitter.buildDisplayPages(
        imagePaths: [sourcePath],
        cacheDir: cacheDir,
        autoSplitWidePages: true,
        readingDirection: ComicReadingDirection.rightToLeft,
      );

      expect(displayPages, hasLength(1));
      expect(displayPages.single.imagePath, sourcePath);
      expect(displayPages.single.part, ComicPagePart.full);
    });
  });
}

Future<void> _deleteFileIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<void> _deleteDirectoryIfExists(Directory directory) async {
  if (await directory.exists()) {
    await directory.delete();
  }
}

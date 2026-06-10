import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/comic_display_page.dart';

class ComicPageSplitter {
  const ComicPageSplitter._();

  static Future<List<ComicDisplayPage>> buildDisplayPages({
    required List<String> imagePaths,
    required Directory cacheDir,
    required bool autoSplitWidePages,
    required ComicReadingDirection readingDirection,
    double wideRatioThreshold = 1.3,
  }) async {
    final displayPages = <ComicDisplayPage>[];

    for (var sourceIndex = 0; sourceIndex < imagePaths.length; sourceIndex++) {
      final imagePath = imagePaths[sourceIndex];
      final fullPage = ComicDisplayPage(
        imagePath: imagePath,
        sourceIndex: sourceIndex,
        part: ComicPagePart.full,
      );

      if (!autoSplitWidePages) {
        displayPages.add(fullPage);
        continue;
      }

      try {
        final sourceImage = await _decodeSourceImage(imagePath);
        if (sourceImage == null) {
          displayPages.add(fullPage);
          continue;
        }

        final ratio = sourceImage.width / sourceImage.height;
        if (ratio <= wideRatioThreshold) {
          displayPages.add(fullPage);
          continue;
        }

        final cachedPages = await _cachedSplitPages(
          cacheDir: cacheDir,
          sourceIndex: sourceIndex,
          readingDirection: readingDirection,
        );
        if (cachedPages != null) {
          displayPages.addAll(cachedPages);
          continue;
        }

        final splitPages = await _splitAndCache(
          sourceImage: sourceImage,
          cacheDir: cacheDir,
          sourceIndex: sourceIndex,
          readingDirection: readingDirection,
        );
        displayPages.addAll(splitPages);
      } catch (_) {
        displayPages.add(fullPage);
      }
    }

    return displayPages;
  }

  static Future<img.Image?> _decodeSourceImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final sourceImage = img.decodeImage(bytes);
    if (sourceImage == null ||
        sourceImage.width < 2 ||
        sourceImage.height <= 0) {
      return null;
    }
    return sourceImage;
  }

  static Future<List<ComicDisplayPage>?> _cachedSplitPages({
    required Directory cacheDir,
    required int sourceIndex,
    required ComicReadingDirection readingDirection,
  }) async {
    final paths = _splitCachePaths(cacheDir, sourceIndex);
    final leftExists = await File(paths.leftPath).exists();
    final rightExists = await File(paths.rightPath).exists();
    if (!leftExists || !rightExists) {
      return null;
    }

    return _orderedSplitPages(
      leftPath: paths.leftPath,
      rightPath: paths.rightPath,
      sourceIndex: sourceIndex,
      readingDirection: readingDirection,
    );
  }

  static Future<List<ComicDisplayPage>> _splitAndCache({
    required img.Image sourceImage,
    required Directory cacheDir,
    required int sourceIndex,
    required ComicReadingDirection readingDirection,
  }) async {
    await cacheDir.create(recursive: true);

    final leftWidth = sourceImage.width ~/ 2;
    final rightWidth = sourceImage.width - leftWidth;
    final height = sourceImage.height;

    final leftPage = img.copyCrop(
      sourceImage,
      x: 0,
      y: 0,
      width: leftWidth,
      height: height,
    );
    final rightPage = img.copyCrop(
      sourceImage,
      x: leftWidth,
      y: 0,
      width: rightWidth,
      height: height,
    );

    final paths = _splitCachePaths(cacheDir, sourceIndex);
    await File(paths.leftPath).writeAsBytes(
      img.encodeJpg(leftPage, quality: 92),
      flush: true,
    );
    await File(paths.rightPath).writeAsBytes(
      img.encodeJpg(rightPage, quality: 92),
      flush: true,
    );

    return _orderedSplitPages(
      leftPath: paths.leftPath,
      rightPath: paths.rightPath,
      sourceIndex: sourceIndex,
      readingDirection: readingDirection,
    );
  }

  static List<ComicDisplayPage> _orderedSplitPages({
    required String leftPath,
    required String rightPath,
    required int sourceIndex,
    required ComicReadingDirection readingDirection,
  }) {
    final leftPage = ComicDisplayPage(
      imagePath: leftPath,
      sourceIndex: sourceIndex,
      part: ComicPagePart.left,
    );
    final rightPage = ComicDisplayPage(
      imagePath: rightPath,
      sourceIndex: sourceIndex,
      part: ComicPagePart.right,
    );

    switch (readingDirection) {
      case ComicReadingDirection.rightToLeft:
        return [rightPage, leftPage];
      case ComicReadingDirection.leftToRight:
        return [leftPage, rightPage];
    }
  }

  static _SplitCachePaths _splitCachePaths(
      Directory cacheDir, int sourceIndex) {
    final pageName = sourceIndex.toString().padLeft(5, '0');
    return _SplitCachePaths(
      leftPath: p.join(cacheDir.path, '${pageName}_page_left.jpg'),
      rightPath: p.join(cacheDir.path, '${pageName}_page_right.jpg'),
    );
  }
}

class _SplitCachePaths {
  const _SplitCachePaths({
    required this.leftPath,
    required this.rightPath,
  });

  final String leftPath;
  final String rightPath;
}

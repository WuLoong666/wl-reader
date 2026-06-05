import 'package:flutter/painting.dart';

class TextPaginator {
  const TextPaginator._();

  static List<String> paginateText({
    required String content,
    required double maxWidth,
    required double maxHeight,
    required TextStyle textStyle,
  }) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) {
      return const [''];
    }

    final safeWidth = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 1.0;
    final safeHeight = maxHeight.isFinite && maxHeight > 0 ? maxHeight : 1.0;
    final boundaries = _runeBoundaries(normalized);

    final pages = <String>[];
    var start = 0;

    while (start < boundaries.length - 1) {
      while (pages.isNotEmpty &&
          start < boundaries.length - 1 &&
          normalized.codeUnitAt(boundaries[start]) == 0x0A) {
        start += 1;
      }

      if (start >= boundaries.length - 1) {
        break;
      }

      var low = start + 1;
      var high = boundaries.length - 1;
      var best = low;

      while (low <= high) {
        final mid = low + ((high - low) >> 1);
        final candidate = normalized
            .substring(boundaries[start], boundaries[mid])
            .trimRight();

        if (_fits(
          candidate,
          maxWidth: safeWidth,
          maxHeight: safeHeight,
          textStyle: textStyle,
        )) {
          best = mid;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }

      if (best <= start) {
        best = start + 1;
      }

      final page =
          normalized.substring(boundaries[start], boundaries[best]).trimRight();
      if (page.isNotEmpty) {
        pages.add(page);
      }
      start = best;
    }

    return pages.isEmpty ? const [''] : pages;
  }

  static List<int> _runeBoundaries(String text) {
    final boundaries = <int>[0];
    var offset = 0;
    for (final rune in text.runes) {
      offset += rune > 0xFFFF ? 2 : 1;
      boundaries.add(offset);
    }
    return boundaries;
  }

  static bool _fits(
    String text, {
    required double maxWidth,
    required double maxHeight,
    required TextStyle textStyle,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );

    try {
      textPainter.layout(maxWidth: maxWidth);
      return textPainter.height <= maxHeight + 0.5;
    } finally {
      textPainter.dispose();
    }
  }
}

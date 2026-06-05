import 'dart:math' as math;

class TextPaginator {
  const TextPaginator._();

  static List<String> paginateText({
    required String content,
    required double screenWidth,
    required double screenHeight,
    required double fontSize,
    required double lineHeight,
  }) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) {
      return const [''];
    }

    final linePixelHeight = math.max(1.0, fontSize * lineHeight);
    final charsPerLine = math.max(8, (screenWidth / (fontSize * 1.05)).floor());
    final visibleLines = math.max(3, (screenHeight / linePixelHeight).floor());
    final safetyLines = visibleLines >= 8 ? 2 : 1;
    final linesPerPage = math.max(3, visibleLines - safetyLines);

    final pages = <String>[];
    final pageBuffer = StringBuffer();
    var usedLines = 0;

    void flushPage() {
      final page = pageBuffer.toString().trimRight();
      if (page.isNotEmpty) {
        pages.add(page);
      }
      pageBuffer.clear();
      usedLines = 0;
    }

    void appendVisualLine(String line) {
      if (usedLines >= linesPerPage) {
        flushPage();
      }
      if (pageBuffer.isNotEmpty) {
        pageBuffer.write('\n');
      }
      pageBuffer.write(line);
      usedLines += 1;
    }

    for (final paragraph in normalized.split('\n')) {
      if (paragraph.isEmpty) {
        appendVisualLine('');
        continue;
      }

      var start = 0;
      while (start < paragraph.length) {
        final end = math.min(start + charsPerLine, paragraph.length);
        appendVisualLine(paragraph.substring(start, end));
        start = end;
      }
    }

    flushPage();
    return pages.isEmpty ? const [''] : pages;
  }
}

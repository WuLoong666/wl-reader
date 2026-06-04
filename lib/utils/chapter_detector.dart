import '../models/chapter.dart';

class ChapterDetector {
  ChapterDetector._();

  static final List<RegExp> _patterns = [
    RegExp(r'^\s*第[一二三四五六七八九十百千万零〇两\d]+[章节卷话回].*$'),
    RegExp(r'^\s*Chapter\s+\d+.*$', caseSensitive: false),
  ];

  static List<ChapterDraft> splitIntoChapters(String rawText) {
    final normalized = rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\uFEFF', '')
        .trim();

    if (normalized.isEmpty) {
      return const [
        ChapterDraft(title: '正文', content: ''),
      ];
    }

    final lines = normalized.split('\n');
    final chapters = <ChapterDraft>[];
    var currentTitle = '正文';
    final buffer = StringBuffer();
    var foundChapter = false;

    for (final line in lines) {
      final trimmed = line.trim();
      final isTitle = _isChapterTitle(trimmed);

      if (isTitle) {
        if (foundChapter || buffer.toString().trim().isNotEmpty) {
          chapters.add(
            ChapterDraft(
              title: currentTitle,
              content: _cleanContent(buffer.toString()),
            ),
          );
          buffer.clear();
        }
        currentTitle = trimmed;
        foundChapter = true;
      } else {
        buffer.writeln(line);
      }
    }

    final lastContent = _cleanContent(buffer.toString());
    if (foundChapter || lastContent.isNotEmpty) {
      chapters.add(
        ChapterDraft(title: currentTitle, content: lastContent),
      );
    }

    if (!foundChapter || chapters.isEmpty) {
      return [
        ChapterDraft(title: '正文', content: _cleanContent(normalized)),
      ];
    }

    return chapters
        .where((chapter) =>
            chapter.title.trim().isNotEmpty || chapter.content.trim().isNotEmpty)
        .toList(growable: false);
  }

  static bool _isChapterTitle(String line) {
    if (line.isEmpty || line.length > 60) {
      return false;
    }
    return _patterns.any((pattern) => pattern.hasMatch(line));
  }

  static String _cleanContent(String content) {
    return content
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n')
        .trim();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wl_reader/utils/chapter_detector.dart';

void main() {
  test('detects Chinese and English chapter titles', () {
    final chapters = ChapterDetector.splitIntoChapters('''
序

第一章 开始
内容一

第001章 继续
内容二

Chapter 3 End
content three
''');

    expect(chapters.length, 4);
    expect(chapters[1].title, '第一章 开始');
    expect(chapters[2].title, '第001章 继续');
    expect(chapters[3].title, 'Chapter 3 End');
  });

  test('falls back to a single chapter', () {
    final chapters = ChapterDetector.splitIntoChapters('没有章节标题的正文');

    expect(chapters.length, 1);
    expect(chapters.first.title, '正文');
  });
}

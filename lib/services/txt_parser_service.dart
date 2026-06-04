import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/chapter.dart';
import '../utils/chapter_detector.dart';

class TxtParserService {
  Future<ParsedBookDraft> parse(File file) async {
    final bytes = await file.readAsBytes();
    final text = _decodeText(bytes);
    final title = p.basenameWithoutExtension(file.path).trim();
    final chapters = ChapterDetector.splitIntoChapters(text);

    return ParsedBookDraft(
      title: title.isEmpty ? '未命名 TXT' : title,
      author: '',
      chapters: chapters,
    );
  }

  String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return _decodeGbkFallback(bytes);
    }
  }

  String _decodeGbkFallback(List<int> bytes) {
    // 第一版保留 GBK 接口位置。后续可接入 gbk_codec 或平台编码转换库。
    return utf8.decode(bytes, allowMalformed: true);
  }
}

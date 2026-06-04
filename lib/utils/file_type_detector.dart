import 'package:path/path.dart' as p;

enum LocalBookFormat {
  txt,
  epub,
}

class FileTypeDetector {
  const FileTypeDetector._();

  static LocalBookFormat detectFromPath(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    return switch (extension) {
      '.txt' => LocalBookFormat.txt,
      '.epub' => LocalBookFormat.epub,
      _ => throw UnsupportedError('只支持导入 TXT 和 EPUB 文件'),
    };
  }

  static String formatName(LocalBookFormat format) {
    return switch (format) {
      LocalBookFormat.txt => 'txt',
      LocalBookFormat.epub => 'epub',
    };
  }
}

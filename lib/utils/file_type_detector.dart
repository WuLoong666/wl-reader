import 'package:path/path.dart' as p;

enum LocalBookFormat {
  txt,
  epub,
  cbz,
  zip,
}

extension LocalBookFormatKind on LocalBookFormat {
  bool get isComic {
    return switch (this) {
      LocalBookFormat.cbz || LocalBookFormat.zip => true,
      LocalBookFormat.txt || LocalBookFormat.epub => false,
    };
  }
}

class FileTypeDetector {
  const FileTypeDetector._();

  static LocalBookFormat detectFromPath(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    return switch (extension) {
      '.txt' => LocalBookFormat.txt,
      '.epub' => LocalBookFormat.epub,
      '.cbz' => LocalBookFormat.cbz,
      '.zip' => LocalBookFormat.zip,
      _ => throw UnsupportedError('只支持导入 TXT、EPUB、CBZ 和 ZIP 文件'),
    };
  }

  static String formatName(LocalBookFormat format) {
    return switch (format) {
      LocalBookFormat.txt => 'txt',
      LocalBookFormat.epub => 'epub',
      LocalBookFormat.cbz => 'cbz',
      LocalBookFormat.zip => 'zip',
    };
  }
}

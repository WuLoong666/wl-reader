import 'package:path/path.dart' as p;

enum ImageFileFormat {
  jpg,
  jpeg,
  png,
  webp,
  gif,
  svg,
  bmp,
  avif,
  unknown;

  bool get isRasterRenderable {
    return switch (this) {
      ImageFileFormat.jpg ||
      ImageFileFormat.jpeg ||
      ImageFileFormat.png ||
      ImageFileFormat.webp ||
      ImageFileFormat.gif =>
        true,
      ImageFileFormat.svg ||
      ImageFileFormat.bmp ||
      ImageFileFormat.avif ||
      ImageFileFormat.unknown =>
        false,
    };
  }

  bool get isSvg => this == ImageFileFormat.svg;

  bool get canSplitWidePage {
    return switch (this) {
      ImageFileFormat.jpg ||
      ImageFileFormat.jpeg ||
      ImageFileFormat.png ||
      ImageFileFormat.webp =>
        true,
      ImageFileFormat.gif ||
      ImageFileFormat.svg ||
      ImageFileFormat.bmp ||
      ImageFileFormat.avif ||
      ImageFileFormat.unknown =>
        false,
    };
  }
}

class ImageFormat {
  const ImageFormat._();

  static ImageFileFormat fromPath(String path) {
    return switch (p.extension(path).toLowerCase()) {
      '.jpg' => ImageFileFormat.jpg,
      '.jpeg' => ImageFileFormat.jpeg,
      '.png' => ImageFileFormat.png,
      '.webp' => ImageFileFormat.webp,
      '.gif' => ImageFileFormat.gif,
      '.svg' => ImageFileFormat.svg,
      '.bmp' => ImageFileFormat.bmp,
      '.avif' => ImageFileFormat.avif,
      _ => ImageFileFormat.unknown,
    };
  }

  static String extensionFromMediaType(String mediaType) {
    final normalized = mediaType.split(';').first.trim().toLowerCase();
    return switch (normalized) {
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/svg+xml' || 'image/svg' => 'svg',
      'image/bmp' || 'image/x-ms-bmp' => 'bmp',
      'image/avif' => 'avif',
      _ => '',
    };
  }

  static bool isImageMediaType(String mediaType) {
    return mediaType.split(';').first.trim().toLowerCase().startsWith('image/');
  }
}

enum ComicPagePart {
  full,
  left,
  right,
}

enum ComicReadingDirection {
  rightToLeft,
  leftToRight,
}

extension ComicReadingDirectionLabel on ComicReadingDirection {
  String get storageValue {
    switch (this) {
      case ComicReadingDirection.rightToLeft:
        return 'rightToLeft';
      case ComicReadingDirection.leftToRight:
        return 'leftToRight';
    }
  }

  String get label {
    switch (this) {
      case ComicReadingDirection.rightToLeft:
        return '从右到左';
      case ComicReadingDirection.leftToRight:
        return '从左到右';
    }
  }
}

ComicReadingDirection comicReadingDirectionFromString(String? value) {
  switch (value) {
    case 'leftToRight':
    case 'left_to_right':
    case 'ltr':
      return ComicReadingDirection.leftToRight;
    case 'rightToLeft':
    case 'right_to_left':
    case 'rtl':
    default:
      return ComicReadingDirection.rightToLeft;
  }
}

class ComicDisplayPage {
  const ComicDisplayPage({
    required this.imagePath,
    required this.sourceIndex,
    required this.part,
  });

  final String imagePath;
  final int sourceIndex;
  final ComicPagePart part;
}

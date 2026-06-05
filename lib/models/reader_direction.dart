enum ReaderDirection {
  horizontal,
  vertical,
}

extension ReaderDirectionLabel on ReaderDirection {
  String get storageValue {
    switch (this) {
      case ReaderDirection.horizontal:
        return 'horizontal';
      case ReaderDirection.vertical:
        return 'vertical';
    }
  }

  String get label {
    switch (this) {
      case ReaderDirection.horizontal:
        return '横向';
      case ReaderDirection.vertical:
        return '竖向';
    }
  }
}

ReaderDirection readerDirectionFromString(String? value) {
  switch (value) {
    case 'vertical':
      return ReaderDirection.vertical;
    case 'horizontal':
    default:
      return ReaderDirection.horizontal;
  }
}

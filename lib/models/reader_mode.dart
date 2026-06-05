enum ReaderMode {
  horizontalPage,
  verticalScroll,
}

extension ReaderModeLabel on ReaderMode {
  String get storageValue {
    switch (this) {
      case ReaderMode.horizontalPage:
        return 'horizontalPage';
      case ReaderMode.verticalScroll:
        return 'verticalScroll';
    }
  }

  String get label {
    switch (this) {
      case ReaderMode.horizontalPage:
        return '横向分页';
      case ReaderMode.verticalScroll:
        return '竖向连续';
    }
  }
}

ReaderMode readerModeFromString(String? value) {
  switch (value) {
    case 'verticalScroll':
    case 'vertical_scroll':
    case 'vertical':
      return ReaderMode.verticalScroll;
    case 'horizontalPage':
    case 'horizontal_page':
    case 'horizontal':
    default:
      return ReaderMode.horizontalPage;
  }
}

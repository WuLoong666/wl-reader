import '../models/book.dart';

enum BookSortType {
  title,
  author,
  importedAt,
  lastReadAt,
}

enum SortOrder {
  ascending,
  descending,
}

extension BookSortTypeStorage on BookSortType {
  String get storageValue {
    return switch (this) {
      BookSortType.title => 'title',
      BookSortType.author => 'author',
      BookSortType.importedAt => 'importedAt',
      BookSortType.lastReadAt => 'lastReadAt',
    };
  }

  String get label {
    return switch (this) {
      BookSortType.title => '书名',
      BookSortType.author => '作者',
      BookSortType.importedAt => '导入时间',
      BookSortType.lastReadAt => '最近阅读',
    };
  }
}

extension SortOrderStorage on SortOrder {
  String get storageValue {
    return switch (this) {
      SortOrder.ascending => 'ascending',
      SortOrder.descending => 'descending',
    };
  }

  String get label {
    return switch (this) {
      SortOrder.ascending => '升序',
      SortOrder.descending => '降序',
    };
  }
}

BookSortType bookSortTypeFromString(String? value) {
  return switch (value) {
    'title' => BookSortType.title,
    'author' => BookSortType.author,
    'importedAt' || 'addedTime' || 'createdAt' => BookSortType.importedAt,
    'lastReadAt' || 'lastReadTime' => BookSortType.lastReadAt,
    _ => BookSortType.lastReadAt,
  };
}

SortOrder sortOrderFromString(String? value) {
  return switch (value) {
    'ascending' || 'asc' => SortOrder.ascending,
    'descending' || 'desc' => SortOrder.descending,
    _ => SortOrder.descending,
  };
}

List<Book> sortBooks(
  List<Book> books,
  BookSortType sortType,
  SortOrder sortOrder,
) {
  final sorted = List<Book>.of(books);
  sorted.sort((left, right) {
    final comparison = switch (sortType) {
      BookSortType.title => _compareTitle(left, right),
      BookSortType.author => _compareAuthor(left, right),
      BookSortType.importedAt => _compareDate(
          left.importedAt,
          right.importedAt,
        ),
      BookSortType.lastReadAt => _compareNullableDateLast(
          left.lastReadAt,
          right.lastReadAt,
        ),
    };

    final orderedComparison = sortOrder == SortOrder.ascending
        ? comparison
        : _reversePreservingMissingLast(
            comparison: comparison,
            sortType: sortType,
            left: left,
            right: right,
          );

    if (orderedComparison != 0) {
      return orderedComparison;
    }
    return _compareTieBreaker(left, right);
  });
  return sorted;
}

int _reversePreservingMissingLast({
  required int comparison,
  required BookSortType sortType,
  required Book left,
  required Book right,
}) {
  if (sortType == BookSortType.author &&
      (_isMissingAuthor(left) || _isMissingAuthor(right))) {
    return comparison;
  }
  if (sortType == BookSortType.lastReadAt &&
      (left.lastReadAt == null || right.lastReadAt == null)) {
    return comparison;
  }
  return -comparison;
}

int _compareTitle(Book left, Book right) {
  return _normalizedText(left.title).compareTo(_normalizedText(right.title));
}

int _compareAuthor(Book left, Book right) {
  final leftMissing = _isMissingAuthor(left);
  final rightMissing = _isMissingAuthor(right);
  if (leftMissing && rightMissing) {
    return 0;
  }
  if (leftMissing) {
    return 1;
  }
  if (rightMissing) {
    return -1;
  }
  return _normalizedText(left.author).compareTo(_normalizedText(right.author));
}

bool _isMissingAuthor(Book book) {
  return book.author.trim().isEmpty;
}

int _compareDate(DateTime left, DateTime right) {
  return left.compareTo(right);
}

int _compareNullableDateLast(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

int _compareTieBreaker(Book left, Book right) {
  final lastReadComparison = _compareNullableDateLast(
    left.lastReadAt,
    right.lastReadAt,
  );
  if (lastReadComparison != 0) {
    return _reversePreservingMissingLast(
      comparison: lastReadComparison,
      sortType: BookSortType.lastReadAt,
      left: left,
      right: right,
    );
  }

  final importComparison = _compareDate(left.importedAt, right.importedAt);
  if (importComparison != 0) {
    return -importComparison;
  }

  final titleComparison = _compareTitle(left, right);
  if (titleComparison != 0) {
    return titleComparison;
  }

  return (left.id ?? 0).compareTo(right.id ?? 0);
}

String _normalizedText(String value) {
  return value.trim().toLowerCase();
}

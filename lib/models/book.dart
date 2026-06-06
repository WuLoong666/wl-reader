enum BookType {
  novel,
  comic,
}

extension BookTypeStorage on BookType {
  String get storageValue {
    return switch (this) {
      BookType.novel => 'novel',
      BookType.comic => 'comic',
    };
  }
}

BookType bookTypeFromString(String? value, {String? format}) {
  switch (value) {
    case 'novel':
    case 'text':
    case 'epub':
      return BookType.novel;
    case 'comic':
      return BookType.comic;
  }

  switch (format?.toLowerCase()) {
    case 'cbz':
    case 'zip':
      return BookType.comic;
    case 'epub':
    case 'txt':
    default:
      return BookType.novel;
  }
}

class Book {
  const Book({
    this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.coverPath,
    required this.format,
    this.bookType = BookType.novel,
    this.isWantToRead = false,
    required this.totalChapters,
    required this.currentChapter,
    required this.currentPosition,
    required this.progress,
    required this.addedTime,
    this.lastReadTime,
  });

  final int? id;
  final String title;
  final String author;
  final String filePath;
  final String coverPath;
  final String format;
  final BookType bookType;
  final bool isWantToRead;
  final int totalChapters;
  final int currentChapter;
  final int currentPosition;
  final double progress;
  final DateTime addedTime;
  final DateTime? lastReadTime;

  DateTime get importedAt => addedTime;

  DateTime? get lastReadAt => lastReadTime;

  String get typeLabel {
    return switch (bookType) {
      BookType.novel => '小说',
      BookType.comic => '漫画',
    };
  }

  String get formatLabel {
    final normalizedFormat = format.trim().toLowerCase();
    return switch (normalizedFormat) {
      'txt' => 'TXT',
      'epub' => 'EPUB',
      'cbz' => 'CBZ',
      'zip' => 'ZIP',
      _ =>
        bookType == BookType.comic ? 'Comic' : normalizedFormat.toUpperCase(),
    };
  }

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? filePath,
    String? coverPath,
    String? format,
    BookType? bookType,
    bool? isWantToRead,
    int? totalChapters,
    int? currentChapter,
    int? currentPosition,
    double? progress,
    DateTime? addedTime,
    DateTime? lastReadTime,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      format: format ?? this.format,
      bookType: bookType ?? this.bookType,
      isWantToRead: isWantToRead ?? this.isWantToRead,
      totalChapters: totalChapters ?? this.totalChapters,
      currentChapter: currentChapter ?? this.currentChapter,
      currentPosition: currentPosition ?? this.currentPosition,
      progress: progress ?? this.progress,
      addedTime: addedTime ?? this.addedTime,
      lastReadTime: lastReadTime ?? this.lastReadTime,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'file_path': filePath,
      'cover_path': coverPath,
      'format': format,
      'book_type': bookType.storageValue,
      'is_want_to_read': isWantToRead ? 1 : 0,
      'total_chapters': totalChapters,
      'current_chapter': currentChapter,
      'current_position': currentPosition,
      'progress': progress,
      'added_time': addedTime.millisecondsSinceEpoch,
      'last_read_time': lastReadTime?.millisecondsSinceEpoch,
    };
  }

  factory Book.fromMap(Map<String, Object?> map) {
    final format = map['format'] as String? ?? 'txt';
    return Book(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      author: map['author'] as String? ?? '',
      filePath: map['file_path'] as String? ?? '',
      coverPath: map['cover_path'] as String? ?? '',
      format: format,
      bookType: bookTypeFromString(
        map['book_type'] as String?,
        format: format,
      ),
      isWantToRead: _boolFromMapValue(map['is_want_to_read']),
      totalChapters: map['total_chapters'] as int? ?? 0,
      currentChapter: map['current_chapter'] as int? ?? 0,
      currentPosition: map['current_position'] as int? ?? 0,
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      addedTime: DateTime.fromMillisecondsSinceEpoch(
        map['added_time'] as int? ?? 0,
      ),
      lastReadTime: map['last_read_time'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['last_read_time'] as int),
    );
  }
}

bool _boolFromMapValue(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value == '1' || value.toLowerCase() == 'true';
  }
  return false;
}

enum BookType {
  text,
  epub,
  comic,
}

extension BookTypeStorage on BookType {
  String get storageValue {
    return switch (this) {
      BookType.text => 'text',
      BookType.epub => 'epub',
      BookType.comic => 'comic',
    };
  }
}

BookType bookTypeFromString(String? value, {String? format}) {
  switch (value) {
    case 'epub':
      return BookType.epub;
    case 'comic':
      return BookType.comic;
    case 'text':
      return BookType.text;
  }

  switch (format?.toLowerCase()) {
    case 'epub':
      return BookType.epub;
    case 'cbz':
    case 'zip':
      return BookType.comic;
    case 'txt':
    default:
      return BookType.text;
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
    this.bookType = BookType.text,
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
  final int totalChapters;
  final int currentChapter;
  final int currentPosition;
  final double progress;
  final DateTime addedTime;
  final DateTime? lastReadTime;

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? filePath,
    String? coverPath,
    String? format,
    BookType? bookType,
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

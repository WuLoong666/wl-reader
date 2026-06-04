class Chapter {
  const Chapter({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.title,
    required this.content,
  });

  final int? id;
  final int bookId;
  final int chapterIndex;
  final String title;
  final String content;

  Chapter copyWith({
    int? id,
    int? bookId,
    int? chapterIndex,
    String? title,
    String? content,
  }) {
    return Chapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'title': title,
      'content': content,
    };
  }

  factory Chapter.fromMap(Map<String, Object?> map) {
    return Chapter(
      id: map['id'] as int?,
      bookId: map['book_id'] as int? ?? 0,
      chapterIndex: map['chapter_index'] as int? ?? 0,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
    );
  }
}

class ChapterDraft {
  const ChapterDraft({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;
}

class ParsedBookDraft {
  const ParsedBookDraft({
    required this.title,
    required this.author,
    required this.chapters,
    this.coverBytes,
    this.coverExtension,
  });

  final String title;
  final String author;
  final List<ChapterDraft> chapters;
  final List<int>? coverBytes;
  final String? coverExtension;
}

import 'epub_toc_item.dart';

class Chapter {
  const Chapter({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.title,
    required this.content,
    this.htmlContent = '',
    this.sourcePath = '',
    this.anchor = '',
  });

  final int? id;
  final int bookId;
  final int chapterIndex;
  final String title;
  final String content;
  final String htmlContent;
  final String sourcePath;
  final String anchor;

  Chapter copyWith({
    int? id,
    int? bookId,
    int? chapterIndex,
    String? title,
    String? content,
    String? htmlContent,
    String? sourcePath,
    String? anchor,
  }) {
    return Chapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      title: title ?? this.title,
      content: content ?? this.content,
      htmlContent: htmlContent ?? this.htmlContent,
      sourcePath: sourcePath ?? this.sourcePath,
      anchor: anchor ?? this.anchor,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'title': title,
      'content': content,
      'html_content': htmlContent,
      'source_path': sourcePath,
      'anchor': anchor,
    };
  }

  factory Chapter.fromMap(Map<String, Object?> map) {
    return Chapter(
      id: map['id'] as int?,
      bookId: map['book_id'] as int? ?? 0,
      chapterIndex: map['chapter_index'] as int? ?? 0,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      htmlContent: map['html_content'] as String? ?? '',
      sourcePath: map['source_path'] as String? ?? '',
      anchor: map['anchor'] as String? ?? '',
    );
  }
}

class ChapterDraft {
  const ChapterDraft({
    required this.title,
    required this.content,
    this.htmlContent = '',
    this.sourcePath = '',
    this.anchor = '',
    this.epubImages = const [],
  });

  final String title;
  final String content;
  final String htmlContent;
  final String sourcePath;
  final String anchor;
  final List<EpubImageAssetDraft> epubImages;
}

class ParsedBookDraft {
  const ParsedBookDraft({
    required this.title,
    required this.author,
    required this.chapters,
    this.tocItems = const [],
    this.coverBytes,
    this.coverExtension,
  });

  final String title;
  final String author;
  final List<ChapterDraft> chapters;
  final List<EpubTocItemDraft> tocItems;
  final List<int>? coverBytes;
  final String? coverExtension;

  int get displayChapterCount {
    return tocItems.isEmpty ? chapters.length : tocItems.length;
  }
}

class EpubImageAssetDraft {
  const EpubImageAssetDraft({
    required this.originalPath,
    required this.archivePath,
    required this.relativeOutputPath,
    required this.bytes,
  });

  final String originalPath;
  final String archivePath;
  final String relativeOutputPath;
  final List<int> bytes;
}

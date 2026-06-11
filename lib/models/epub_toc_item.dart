class EpubTocItem {
  const EpubTocItem({
    this.id,
    required this.bookId,
    required this.itemIndex,
    required this.title,
    required this.href,
    required this.normalizedPath,
    required this.anchor,
    required this.spineIndex,
    required this.level,
  });

  final int? id;
  final int bookId;
  final int itemIndex;
  final String title;
  final String href;
  final String normalizedPath;
  final String anchor;
  final int? spineIndex;
  final int level;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'item_index': itemIndex,
      'title': title,
      'href': href,
      'normalized_path': normalizedPath,
      'anchor': anchor,
      'spine_index': spineIndex,
      'level': level,
    };
  }

  factory EpubTocItem.fromMap(Map<String, Object?> map) {
    return EpubTocItem(
      id: map['id'] as int?,
      bookId: map['book_id'] as int? ?? 0,
      itemIndex: map['item_index'] as int? ?? 0,
      title: map['title'] as String? ?? '',
      href: map['href'] as String? ?? '',
      normalizedPath: map['normalized_path'] as String? ?? '',
      anchor: map['anchor'] as String? ?? '',
      spineIndex: map['spine_index'] as int?,
      level: map['level'] as int? ?? 0,
    );
  }
}

class EpubTocItemDraft {
  const EpubTocItemDraft({
    required this.title,
    required this.href,
    required this.normalizedPath,
    required this.anchor,
    required this.level,
    this.spineIndex,
    this.children = const [],
  });

  final String title;
  final String href;
  final String normalizedPath;
  final String anchor;
  final int? spineIndex;
  final int level;
  final List<EpubTocItemDraft> children;

  EpubTocItemDraft withSpineIndex(int? value) {
    return EpubTocItemDraft(
      title: title,
      href: href,
      normalizedPath: normalizedPath,
      anchor: anchor,
      level: level,
      spineIndex: value,
      children: children,
    );
  }

  EpubTocItemDraft withChildren(List<EpubTocItemDraft> value) {
    return EpubTocItemDraft(
      title: title,
      href: href,
      normalizedPath: normalizedPath,
      anchor: anchor,
      level: level,
      spineIndex: spineIndex,
      children: value,
    );
  }
}

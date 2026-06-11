enum EpubContentBlockType {
  text,
  image,
  heading,
  divider,
}

class EpubContentBlock {
  const EpubContentBlock({
    required this.type,
    required this.content,
    this.anchor = '',
  });

  final EpubContentBlockType type;
  final String content;
  final String anchor;
}

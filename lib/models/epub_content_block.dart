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
  });

  final EpubContentBlockType type;
  final String content;
}

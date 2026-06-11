import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/epub_content_block.dart';

class EpubHtmlBlockParser {
  const EpubHtmlBlockParser._();

  static List<EpubContentBlock> parse({
    required String html,
    required String fallbackPlainText,
  }) {
    if (html.trim().isEmpty) {
      return _plainTextBlocks(fallbackPlainText);
    }

    final document = html_parser.parse(html);
    for (final element in document.querySelectorAll('script, style, nav')) {
      element.remove();
    }

    final root = document.body ?? document.documentElement;
    if (root == null) {
      return _plainTextBlocks(fallbackPlainText);
    }

    final blocks = <EpubContentBlock>[];
    final buffer = _TextBlockBuffer(blocks, EpubContentBlockType.text);
    for (final node in root.nodes) {
      _visit(node, blocks, buffer);
    }
    buffer.flush();

    if (blocks.isEmpty) {
      return _plainTextBlocks(fallbackPlainText);
    }
    return blocks;
  }

  static void _visit(
    dom.Node node,
    List<EpubContentBlock> blocks,
    _TextBlockBuffer buffer,
  ) {
    if (node is dom.Text) {
      buffer.write(node.text);
      return;
    }

    if (node is! dom.Element) {
      return;
    }

    final tag = node.localName?.toLowerCase() ?? '';
    if (tag == 'img') {
      buffer.flush();
      final source = node.attributes['src']?.trim();
      if (source != null && source.isNotEmpty) {
        blocks.add(
          EpubContentBlock(
            type: EpubContentBlockType.image,
            content: source,
            anchor: _elementAnchor(node),
          ),
        );
      }
      return;
    }

    if (tag == 'br') {
      buffer.write('\n');
      return;
    }

    if (_isHeading(tag)) {
      buffer.flush();
      final headingBuffer = _TextBlockBuffer(
        blocks,
        EpubContentBlockType.heading,
        anchor: _elementAnchor(node),
      );
      for (final child in node.nodes) {
        _visit(child, blocks, headingBuffer);
      }
      headingBuffer.flush();
      return;
    }

    if (_isBlock(tag)) {
      buffer.flush();
      final blockBuffer = _TextBlockBuffer(
        blocks,
        EpubContentBlockType.text,
        anchor: _elementAnchor(node),
      );
      for (final child in node.nodes) {
        _visit(child, blocks, blockBuffer);
      }
      blockBuffer.flush();
      return;
    }

    for (final child in node.nodes) {
      _visit(child, blocks, buffer);
    }
  }

  static bool _isHeading(String tag) {
    return tag == 'h1' || tag == 'h2' || tag == 'h3';
  }

  static bool _isBlock(String tag) {
    return switch (tag) {
      'p' ||
      'div' ||
      'section' ||
      'article' ||
      'main' ||
      'blockquote' ||
      'li' ||
      'tr' ||
      'td' =>
        true,
      _ => false,
    };
  }

  static String _elementAnchor(dom.Element element) {
    final id = element.attributes['id']?.trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }

    final name = element.attributes['name']?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    return '';
  }

  static List<EpubContentBlock> _plainTextBlocks(String text) {
    final blocks = text
        .split(RegExp(r'\n{2,}'))
        .map(_cleanText)
        .where((value) => value.isNotEmpty)
        .map(
          (value) => EpubContentBlock(
            type: EpubContentBlockType.text,
            content: value,
          ),
        )
        .toList(growable: false);
    return blocks.isEmpty
        ? const [EpubContentBlock(type: EpubContentBlockType.text, content: '')]
        : blocks;
  }

  static String _cleanText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t\f\v]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

class _TextBlockBuffer {
  _TextBlockBuffer(this.blocks, this.type, {this.anchor = ''});

  final List<EpubContentBlock> blocks;
  final EpubContentBlockType type;
  final String anchor;
  final StringBuffer _buffer = StringBuffer();

  void write(String value) {
    if (value.isEmpty) {
      return;
    }
    _buffer.write(value);
  }

  void flush() {
    final text = EpubHtmlBlockParser._cleanText(_buffer.toString());
    _buffer.clear();
    if (text.isEmpty) {
      return;
    }
    blocks.add(EpubContentBlock(type: type, content: text, anchor: anchor));
  }
}

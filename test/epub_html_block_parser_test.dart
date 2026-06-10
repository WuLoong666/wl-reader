import 'package:flutter_test/flutter_test.dart';
import 'package:wl_reader/models/epub_content_block.dart';
import 'package:wl_reader/utils/epub_html_block_parser.dart';

void main() {
  test('parses headings text and image blocks in order', () {
    final blocks = EpubHtmlBlockParser.parse(
      html: '''
<body>
  <h1>Chapter One</h1>
  <p>Hello <span>world</span>.</p>
  <p><img src="/tmp/book/image.jpg" /></p>
  <p>After image.</p>
</body>
''',
      fallbackPlainText: '',
    );

    expect(blocks.map((block) => block.type), [
      EpubContentBlockType.heading,
      EpubContentBlockType.text,
      EpubContentBlockType.image,
      EpubContentBlockType.text,
    ]);
    expect(blocks[2].content, '/tmp/book/image.jpg');
  });

  test('falls back to plain text when html is empty', () {
    final blocks = EpubHtmlBlockParser.parse(
      html: '',
      fallbackPlainText: 'Line one.\n\nLine two.',
    );

    expect(blocks.length, 2);
    expect(blocks.first.content, 'Line one.');
  });
}

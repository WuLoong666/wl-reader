import 'package:flutter_test/flutter_test.dart';
import 'package:wl_reader/utils/natural_sort.dart';

void main() {
  test('sorts numbered comic pages in natural order', () {
    final pages = [
      '10.jpg',
      '2.jpg',
      '1.jpg',
      'page_002.png',
      'page_010.png',
      'page_001.png',
    ]..sort(naturalCompare);

    expect(pages, [
      '1.jpg',
      '2.jpg',
      '10.jpg',
      'page_001.png',
      'page_002.png',
      'page_010.png',
    ]);
  });

  test('sorts common manga page names by embedded numbers', () {
    final pages = [
      'chapter1_10.jpg',
      '第003页.webp',
      'chapter1_04.jpg',
      '第002页.webp',
    ]..sort(naturalCompare);

    expect(pages, [
      'chapter1_04.jpg',
      'chapter1_10.jpg',
      '第002页.webp',
      '第003页.webp',
    ]);
  });
}

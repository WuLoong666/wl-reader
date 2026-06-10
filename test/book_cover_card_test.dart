import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wl_reader/models/book.dart';
import 'package:wl_reader/widgets/book_cover_card.dart';

void main() {
  testWidgets('book cover card handles tap long press and secondary tap',
      (tester) async {
    var taps = 0;
    var longPresses = 0;
    var secondaryTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 280,
            child: BookCoverCard(
              book: _book(),
              onTap: () => taps += 1,
              onLongPressStart: (_) => longPresses += 1,
              onSecondaryTapDown: (_) => secondaryTaps += 1,
            ),
          ),
        ),
      ),
    );

    final card = find.byType(BookCoverCard);
    await tester.tap(card);
    await tester.pump();
    expect(taps, 1);
    expect(longPresses, 0);

    await tester.longPress(card);
    await tester.pump();
    expect(taps, 1);
    expect(longPresses, 1);

    final center = tester.getCenter(card);
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.down(center);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(secondaryTaps, 1);
    expect(taps, 1);
  });
}

Book _book() {
  return Book(
    id: 1,
    title: 'Sample',
    author: 'Author',
    filePath: '',
    coverPath: '',
    format: 'epub',
    totalChapters: 3,
    currentChapter: 0,
    currentPosition: 0,
    progress: 0.2,
    addedTime: DateTime(2026, 1, 1),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wl_reader/widgets/today_progress_card.dart';

void main() {
  testWidgets('today progress card renders empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TodayProgressCard(book: null),
        ),
      ),
    );

    expect(find.text('今日阅读进度'), findsOneWidget);
    expect(find.text('继续阅读'), findsOneWidget);
  });
}

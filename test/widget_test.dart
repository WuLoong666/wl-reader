import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wl_reader/widgets/today_progress_card.dart';

void main() {
  testWidgets('today progress card renders empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TodayProgressCard(book: null),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('今日阅读时间'), findsOneWidget);
    expect(find.text('今日已阅读 0 分钟'), findsOneWidget);
    expect(find.text('继续阅读'), findsOneWidget);
  });
}

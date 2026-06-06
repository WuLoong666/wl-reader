import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wl_reader/services/reading_time_service.dart';
import 'package:wl_reader/utils/time_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('addElapsed stores daily stats and book seconds', () async {
    SharedPreferences.setMockInitialValues({});

    final service = ReadingTimeService();
    await service.addElapsed(const Duration(seconds: 70), bookId: 7);

    final today = _dateKey(DateTime.now());
    final dailyStats = await service.dailyReadingSeconds();

    expect(dailyStats[today], 70);
    expect((await service.todayDuration()).inSeconds, 70);
    expect((await service.bookDuration(7)).inSeconds, 70);
  });

  test('dailyReadingSeconds reads legacy day keys', () async {
    SharedPreferences.setMockInitialValues({
      'daily_reading_seconds': '{"2026-06-06":10}',
      'reading_time_seconds_2026-06-06': 20,
    });

    final service = ReadingTimeService();
    final dailyStats = await service.dailyReadingSeconds();

    expect(dailyStats['2026-06-06'], 20);
  });

  test('formatDuration keeps readable Chinese units', () {
    expect(formatDuration(0), '0 分钟');
    expect(formatDuration(20), '20 秒');
    expect(formatDuration(70), '1 分 10 秒');
    expect(formatDuration(3900), '1 小时 5 分');
  });
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

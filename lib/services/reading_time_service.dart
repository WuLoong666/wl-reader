import 'package:shared_preferences/shared_preferences.dart';

class ReadingTimeService {
  static const _keyPrefix = 'reading_time_seconds_';
  static const _bookKeyPrefix = 'reading_time_book_seconds_';

  Future<Duration> todayDuration() async {
    final preferences = await SharedPreferences.getInstance();
    final seconds = preferences.getInt(_todayKey()) ?? 0;
    return Duration(seconds: seconds);
  }

  Future<Duration> bookDuration(int bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final seconds = preferences.getInt(_bookKey(bookId)) ?? 0;
    return Duration(seconds: seconds);
  }

  Future<void> addElapsed(Duration duration, {int? bookId}) async {
    if (duration.inSeconds <= 0) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final key = _todayKey();
    final seconds = preferences.getInt(key) ?? 0;
    await preferences.setInt(key, seconds + duration.inSeconds);

    if (bookId != null) {
      final bookKey = _bookKey(bookId);
      final bookSeconds = preferences.getInt(bookKey) ?? 0;
      await preferences.setInt(bookKey, bookSeconds + duration.inSeconds);
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$_keyPrefix$year-$month-$day';
  }

  String _bookKey(int bookId) {
    return '$_bookKeyPrefix$bookId';
  }
}

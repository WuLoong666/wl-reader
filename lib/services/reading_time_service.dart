import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReadingTimeService {
  static const _keyPrefix = 'reading_time_seconds_';
  static const _bookKeyPrefix = 'reading_time_book_seconds_';
  static const _dailyStatsKey = 'daily_reading_seconds';

  Future<Duration> todayDuration() async {
    final stats = await dailyReadingSeconds();
    final seconds = stats[_dateKey(DateTime.now())] ?? 0;
    return Duration(seconds: seconds);
  }

  Future<Duration> bookDuration(int bookId) async {
    final preferences = await SharedPreferences.getInstance();
    final seconds = preferences.getInt(_bookKey(bookId)) ?? 0;
    return Duration(seconds: seconds);
  }

  Future<Map<int, int>> bookReadingSecondsById(Iterable<int> bookIds) async {
    final preferences = await SharedPreferences.getInstance();
    final result = <int, int>{};
    for (final bookId in bookIds.toSet()) {
      if (bookId <= 0) {
        continue;
      }
      result[bookId] = preferences.getInt(_bookKey(bookId)) ?? 0;
    }
    return result;
  }

  Future<Map<String, int>> dailyReadingSeconds() async {
    final preferences = await SharedPreferences.getInstance();
    final stats = _decodeDailyStats(preferences.getString(_dailyStatsKey));
    _mergeLegacyDailyStats(stats, preferences);
    return Map.unmodifiable(stats);
  }

  Future<Map<String, int>> monthlyReadingSeconds(DateTime month) async {
    final stats = await dailyReadingSeconds();
    final prefix = '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}-';
    return Map.unmodifiable({
      for (final entry in stats.entries)
        if (entry.key.startsWith(prefix)) entry.key: entry.value,
    });
  }

  Future<void> addElapsed(Duration duration, {int? bookId}) async {
    if (duration.inSeconds <= 0) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final stats = _decodeDailyStats(preferences.getString(_dailyStatsKey));
    _mergeLegacyDailyStats(stats, preferences);
    final seconds = duration.inSeconds;
    final todaySeconds = (stats[today] ?? 0) + seconds;
    stats[today] = todaySeconds;
    await preferences.setString(_dailyStatsKey, jsonEncode(stats));
    await preferences.setInt(_dailyKey(today), todaySeconds);

    if (bookId != null) {
      final bookKey = _bookKey(bookId);
      final bookSeconds = preferences.getInt(bookKey) ?? 0;
      await preferences.setInt(bookKey, bookSeconds + seconds);
    }
  }

  Map<String, int> _decodeDailyStats(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return {};
      }

      final stats = <String, int>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || !_isDateKey(key)) {
          continue;
        }
        if (value is num && value > 0) {
          stats[key] = value.toInt();
        }
      }
      return stats;
    } catch (_) {
      return {};
    }
  }

  void _mergeLegacyDailyStats(
    Map<String, int> stats,
    SharedPreferences preferences,
  ) {
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_keyPrefix)) {
        continue;
      }

      final date = key.substring(_keyPrefix.length);
      if (!_isDateKey(date)) {
        continue;
      }

      final legacySeconds = preferences.getInt(key) ?? 0;
      if (legacySeconds > (stats[date] ?? 0)) {
        stats[date] = legacySeconds;
      }
    }
  }

  bool _isDateKey(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _dailyKey(String date) {
    return '$_keyPrefix$date';
  }

  String _bookKey(int bookId) {
    return '$_bookKeyPrefix$bookId';
  }
}

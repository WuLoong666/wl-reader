import 'package:sqflite/sqflite.dart';

import '../models/book.dart';
import 'app_database.dart';

class BookDao {
  BookDao({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<int> insert(Book book) async {
    final db = await _database.database;
    return db.insert('book', book.toMap());
  }

  Future<List<Book>> getAll() async {
    final db = await _database.database;
    final rows = await db.query(
      'book',
      orderBy: '''
CASE WHEN last_read_time IS NULL THEN 1 ELSE 0 END,
last_read_time DESC,
added_time DESC
''',
    );
    return rows.map(Book.fromMap).toList(growable: false);
  }

  Future<Book?> getById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'book',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Book.fromMap(rows.first);
  }

  Future<Book?> getRecent() async {
    final db = await _database.database;
    final rows = await db.query(
      'book',
      orderBy: '''
CASE WHEN last_read_time IS NULL THEN 1 ELSE 0 END,
last_read_time DESC,
added_time DESC
''',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Book.fromMap(rows.first);
  }

  Future<void> update(Book book) async {
    final id = book.id;
    if (id == null) {
      throw ArgumentError('Book id is required for update.');
    }

    final db = await _database.database;
    await db.update(
      'book',
      book.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateProgress({
    required int bookId,
    required int currentChapter,
    required int currentPosition,
    required double progress,
  }) async {
    final db = await _database.database;
    await db.update(
      'book',
      {
        'current_chapter': currentChapter,
        'current_position': currentPosition,
        'progress': progress.clamp(0, 1),
        'last_read_time': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> updateWantToRead({
    required int bookId,
    required bool isWantToRead,
  }) async {
    final db = await _database.database;
    await db.update(
      'book',
      {'is_want_to_read': isWantToRead ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> deleteById(int bookId) async {
    final db = await _database.database;
    await db.delete(
      'book',
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }
}

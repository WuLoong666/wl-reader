import '../models/chapter.dart';
import 'app_database.dart';

class ChapterDao {
  ChapterDao({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insertAll(List<Chapter> chapters) async {
    if (chapters.isEmpty) {
      return;
    }

    final db = await _database.database;
    final batch = db.batch();
    for (final chapter in chapters) {
      batch.insert('chapter', chapter.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Chapter>> getByBookId(int bookId) async {
    final db = await _database.database;
    final rows = await db.query(
      'chapter',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_index ASC',
    );
    return rows.map(Chapter.fromMap).toList(growable: false);
  }

  Future<void> deleteByBookId(int bookId) async {
    final db = await _database.database;
    await db.delete(
      'chapter',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }
}

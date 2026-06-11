import '../models/epub_toc_item.dart';
import 'app_database.dart';

class EpubTocItemDao {
  EpubTocItemDao({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insertAll(List<EpubTocItem> items) async {
    if (items.isEmpty) {
      return;
    }

    final db = await _database.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('epub_toc_item', item.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<EpubTocItem>> getByBookId(int bookId) async {
    final db = await _database.database;
    final rows = await db.query(
      'epub_toc_item',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'item_index ASC',
    );
    return rows.map(EpubTocItem.fromMap).toList(growable: false);
  }

  Future<void> deleteByBookId(int bookId) async {
    final db = await _database.database;
    await db.delete(
      'epub_toc_item',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/reading_setting.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final dataDir = Directory(p.join(appDir.path, 'wl_reader'));
    await dataDir.create(recursive: true);

    final db = await databaseFactory.openDatabase(
      p.join(dataDir.path, 'wl_reader.db'),
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    _database = db;
    return db;
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) {
      return;
    }
    await db.close();
    _database = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE book (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  author TEXT NOT NULL DEFAULT '',
  file_path TEXT NOT NULL,
  cover_path TEXT NOT NULL DEFAULT '',
  format TEXT NOT NULL,
  book_type TEXT NOT NULL DEFAULT 'novel',
  is_want_to_read INTEGER NOT NULL DEFAULT 0,
  total_chapters INTEGER NOT NULL DEFAULT 0,
  current_chapter INTEGER NOT NULL DEFAULT 0,
  current_position INTEGER NOT NULL DEFAULT 0,
  progress REAL NOT NULL DEFAULT 0,
  added_time INTEGER NOT NULL,
  last_read_time INTEGER
)
''');

    await db.execute('''
CREATE TABLE chapter (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter_index INTEGER NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  html_content TEXT NOT NULL DEFAULT '',
  source_path TEXT NOT NULL DEFAULT '',
  anchor TEXT NOT NULL DEFAULT '',
  FOREIGN KEY(book_id) REFERENCES book(id)
)
''');

    await db.execute('''
CREATE INDEX idx_chapter_book_id
ON chapter(book_id, chapter_index)
''');

    await _createEpubTocItemTable(db);

    await db.execute('''
CREATE TABLE reading_setting (
  id INTEGER PRIMARY KEY,
  font_size REAL NOT NULL,
  line_height REAL NOT NULL,
  theme_mode TEXT NOT NULL,
  background_color TEXT NOT NULL
)
''');

    await db.insert('reading_setting', ReadingSetting.defaults.toMap());
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE book ADD COLUMN book_type TEXT NOT NULL DEFAULT 'novel'",
      );
    }

    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE book ADD COLUMN is_want_to_read INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('''
UPDATE book
SET book_type = CASE
  WHEN lower(book_type) = 'comic' OR lower(format) IN ('cbz', 'zip') THEN 'comic'
  ELSE 'novel'
END
''');
    }

    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE chapter ADD COLUMN html_content TEXT NOT NULL DEFAULT ''",
      );
    }

    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE chapter ADD COLUMN source_path TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE chapter ADD COLUMN anchor TEXT NOT NULL DEFAULT ''",
      );
    }

    if (oldVersion < 6) {
      await _createEpubTocItemTable(db);
    }
  }

  Future<void> _createEpubTocItemTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS epub_toc_item (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  item_index INTEGER NOT NULL,
  title TEXT NOT NULL,
  href TEXT NOT NULL DEFAULT '',
  normalized_path TEXT NOT NULL DEFAULT '',
  anchor TEXT NOT NULL DEFAULT '',
  spine_index INTEGER,
  level INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(book_id) REFERENCES book(id)
)
''');

    await db.execute('''
CREATE INDEX IF NOT EXISTS idx_epub_toc_item_book_id
ON epub_toc_item(book_id, item_index)
''');
  }
}

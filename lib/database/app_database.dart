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
        version: 1,
        onCreate: _onCreate,
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
  FOREIGN KEY(book_id) REFERENCES book(id)
)
''');

    await db.execute('''
CREATE INDEX idx_chapter_book_id
ON chapter(book_id, chapter_index)
''');

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
}

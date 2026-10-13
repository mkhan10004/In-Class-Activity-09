import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class DatabaseHelper {
  DatabaseHelper({this.databaseName = 'inc09.db'});

  final String databaseName;
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _openDatabase();
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, databaseName);

    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createPartOneSchema(db);
        await _createCatalogueSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCatalogueSchema(db);
        }
      },
    );
  }

  Future<void> _createPartOneSchema(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS guests (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          age INTEGER,
          created_at TEXT NOT NULL
        )
      ''');
  }

  Future<void> _createCatalogueSchema(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS folders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL
        )
      ''');

    await db.execute('''
        CREATE TABLE IF NOT EXISTS cards (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          suit TEXT NOT NULL,
          notes TEXT NOT NULL DEFAULT '',
          image_ref TEXT,
          folder_id INTEGER NOT NULL,
          FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE
        )
      ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cards_folder_id ON cards(folder_id)',
    );
  }

  Future<int> insertGuest(Map<String, Object?> guest) async {
    final db = await database;
    return db.insert(
      'guests',
      guest,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getGuests() async {
    final db = await database;
    return db.query('guests', orderBy: 'id ASC');
  }

  Future<int> insertFolder(Folder folder) async {
    final db = await database;
    return db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<FolderWithCount>> getFoldersWithCounts() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM folders f
      LEFT JOIN cards c ON c.folder_id = f.id
      GROUP BY f.id, f.name, f.created_at
      ORDER BY f.name COLLATE NOCASE ASC
    ''');

    return rows
        .map(
          (row) => FolderWithCount(
            folder: Folder(
              id: row['id'] as int?,
              name: (row['name'] ?? '') as String,
              createdAt:
                  (row['created_at'] ??
                          DateTime.now().toUtc().toIso8601String())
                      as String,
            ),
            cardCount: (row['card_count'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<int> updateFolder(Folder folder) async {
    final db = await database;
    return db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<int> deleteFolder(int id) async {
    final db = await database;
    return db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertCard(Card card) async {
    final db = await database;
    return db.insert(
      'cards',
      card.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Card>> getCards(int folderId) async {
    final db = await database;
    final rows = await db.query(
      'cards',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC',
    );

    return rows.map((row) => Card.fromMap(row)).toList();
  }

  Future<int> updateCard(Card card) async {
    final db = await database;
    return db.update(
      'cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(int id) async {
    final db = await database;
    return db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }
}

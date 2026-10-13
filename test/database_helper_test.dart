import 'package:flutter_test/flutter_test.dart';
import 'package:inc09/database_helper.dart';
import 'package:inc09/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper', () {
    test('creates folders/cards schema and preserves legacy guests table on fresh install', () async {
      final dbPath = await getDatabasesPath();
      await deleteDatabase('$dbPath/fresh_test.db');

      final helper = DatabaseHelper(databaseName: 'fresh_test.db');
      final db = await helper.database;

      final folderTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='folders'",
      );
      final cardTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='cards'",
      );
      final guestTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='guests'",
      );

      expect(folderTable, isNotEmpty);
      expect(cardTable, isNotEmpty);
      expect(guestTable, isNotEmpty);

      final folderId = await helper.insertFolder(
        Folder(name: 'Work', createdAt: '2026-01-01'),
      );
      final cardId = await helper.insertCard(
        Card(
          title: 'Alpha',
          suit: '\u2665',
          notes: 'first',
          imageRef: null,
          folderId: folderId,
        ),
      );

      final cards = await helper.getCards(folderId);
      expect(cards.length, 1);
      expect(cards.first.id, cardId);
      expect(cards.first.folderId, folderId);
    });

    test(
      'deletes folder cascades child cards and returns meaningful counts',
      () async {
        final dbPath = await getDatabasesPath();
        await deleteDatabase('$dbPath/delete_test.db');

        final helper = DatabaseHelper(databaseName: 'delete_test.db');

        final folderId = await helper.insertFolder(
          Folder(name: 'Archive', createdAt: '2026-01-02'),
        );
        await helper.insertCard(
          Card(title: 'A', suit: '\u2660', notes: 'x', folderId: folderId),
        );
        await helper.insertCard(
          Card(title: 'B', suit: '\u2666', notes: 'y', folderId: folderId),
        );

        final affected = await helper.deleteFolder(folderId);
        expect(affected, 1);

        final cards = await helper.getCards(folderId);
        expect(cards, isEmpty);

        final folders = await helper.getFoldersWithCounts();
        expect(folders.where((f) => f.folder.id == folderId), isEmpty);
      },
    );
  });

  test('supports legacy guest data shape in migrations', () async {
    final dbPath = await getDatabasesPath();
    await deleteDatabase('$dbPath/guest_test.db');

    final helper = DatabaseHelper(databaseName: 'guest_test.db');
    final db = await helper.database;

    await db.insert('guests', {
      'name': 'Ada',
      'age': 32,
      'created_at': '2026-01-01',
    });
    final rows = await db.query('guests');

    expect(rows, isNotEmpty);
    expect(rows.first['name'], 'Ada');
  });

  test('upgrades version 1 without changing existing guest rows', () async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/upgrade_test.db';
    await deleteDatabase(path);

    final versionOneDb = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE guests (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              age INTEGER,
              created_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    final guestId = await versionOneDb.insert('guests', {
      'name': 'Ada',
      'age': 32,
      'created_at': '2026-01-01',
    });
    await versionOneDb.close();

    final helper = DatabaseHelper(databaseName: 'upgrade_test.db');
    final upgradedDb = await helper.database;
    final guests = await helper.getGuests();
    final folders = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='folders'",
    );
    final cards = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='cards'",
    );
    final indexes = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_cards_folder_id'",
    );

    expect(guests, [
      {
        'id': guestId,
        'name': 'Ada',
        'age': 32,
        'created_at': '2026-01-01',
      },
    ]);
    expect(folders, isNotEmpty);
    expect(cards, isNotEmpty);
    expect(indexes, isNotEmpty);

    await helper.close();
    await deleteDatabase(path);
  });
}

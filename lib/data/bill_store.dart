import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/bill.dart';

abstract class BillStore {
  Future<List<Bill>> getAll();

  Future<int> insert(Bill bill);

  Future<void> deleteBill(int id);

  Future<List<String>> getCategories(BillType type);

  Future<void> addCategory(BillType type, String name);

  Future<void> deleteCategory(BillType type, String name);
}

class SqliteBillStore implements BillStore {
  SqliteBillStore._();

  static final SqliteBillStore instance = SqliteBillStore._();

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) {
      await _repairSchema(_database!);
      return _database!;
    }
    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasePath, 'personal_account.db'),
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bills(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            remark TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute(
          'CREATE INDEX bills_date_index ON bills(date DESC, id DESC)',
        );
        await _createCategories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE bills ADD COLUMN created_at TEXT');
          await db.execute(
            "UPDATE bills SET created_at = date || 'T00:00:00' "
            'WHERE created_at IS NULL',
          );
          await _createCategories(db);
        }
        if (oldVersion < 3) {
          await _migrateDefaultCategories(db);
        }
        if (oldVersion < 4) {
          await _migrateLegacyIncomeCategory(db);
        }
      },
    );
    await _repairSchema(_database!);
    return _database!;
  }

  @override
  Future<List<Bill>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      'bills',
      orderBy: 'date DESC, created_at DESC, id DESC',
    );
    return rows.map(Bill.fromMap).toList(growable: false);
  }

  @override
  Future<int> insert(Bill bill) async {
    final db = await _db;
    final values = bill.toMap()..remove('id');
    return db.insert('bills', values);
  }

  @override
  Future<void> deleteBill(int id) async {
    final db = await _db;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<String>> getCategories(BillType type) async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: [type.databaseValue],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map((row) => row['name'] as String).toList(growable: false);
  }

  @override
  Future<void> addCategory(BillType type, String name) async {
    final db = await _db;
    await db.insert('categories', {
      'type': type.databaseValue,
      'name': name.trim(),
      'sort_order': 999,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> deleteCategory(BillType type, String name) async {
    final db = await _db;
    await db.delete(
      'categories',
      where: 'type = ? AND name = ?',
      whereArgs: [type.databaseValue, name],
    );
  }
}

Future<void> _repairSchema(Database db) async {
  final columns = await db.rawQuery('PRAGMA table_info(bills)');
  final hasCreatedAt = columns.any((row) => row['name'] == 'created_at');
  if (!hasCreatedAt) {
    await db.execute('ALTER TABLE bills ADD COLUMN created_at TEXT');
    await db.execute(
      "UPDATE bills SET created_at = date || 'T00:00:00' "
      'WHERE created_at IS NULL',
    );
  }

  final categoryTables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name = 'categories'",
  );
  if (categoryTables.isEmpty) {
    await _createCategories(db);
  }
  var version = await db.getVersion();
  if (version < 3) {
    await _migrateDefaultCategories(db);
    await db.setVersion(3);
    version = 3;
  }
  if (version < 4) {
    await _migrateLegacyIncomeCategory(db);
    await db.setVersion(4);
  }
}

Future<void> _createCategories(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 999,
      UNIQUE(type, name)
    )
  ''');
  const expense = ['餐饮', '运动', '交通', '购物'];
  const income = ['补贴', '工资', '奖金'];
  var order = 0;
  for (final name in expense) {
    await db.insert('categories', {
      'type': 'expense',
      'name': name,
      'sort_order': order++,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  order = 0;
  for (final name in income) {
    await db.insert('categories', {
      'type': 'income',
      'name': name,
      'sort_order': order++,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

Future<void> _migrateDefaultCategories(DatabaseExecutor db) async {
  await db.delete(
    'categories',
    where: "type = 'expense' AND name IN (?, ?, ?, ?)",
    whereArgs: ['住房', '娱乐', '医疗', '其他'],
  );
  await db.delete(
    'categories',
    where: "type = 'income' AND name = ?",
    whereArgs: ['其他收入'],
  );

  const defaults = <BillType, List<String>>{
    BillType.expense: ['餐饮', '运动', '交通', '购物'],
    BillType.income: ['补贴', '工资', '奖金'],
  };
  for (final entry in defaults.entries) {
    for (var index = 0; index < entry.value.length; index++) {
      final name = entry.value[index];
      final updated = await db.update(
        'categories',
        {'sort_order': index},
        where: 'type = ? AND name = ?',
        whereArgs: [entry.key.databaseValue, name],
      );
      if (updated == 0) {
        await db.insert('categories', {
          'type': entry.key.databaseValue,
          'name': name,
          'sort_order': index,
        });
      }
    }
  }
}

Future<void> _migrateLegacyIncomeCategory(DatabaseExecutor db) async {
  await db.update(
    'bills',
    {'category': '补贴'},
    where: "type = 'income' AND category = ?",
    whereArgs: ['其他收入'],
  );
  await db.delete(
    'categories',
    where: "type = 'income' AND name = ?",
    whereArgs: ['其他收入'],
  );
}

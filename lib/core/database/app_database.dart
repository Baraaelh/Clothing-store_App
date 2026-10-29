import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// نقطة الوصول الوحيدة لقاعدة SQLite المحلية.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path}) : _factory = factory ?? databaseFactory, _path = path;

  static const int version = 1;
  static const String fileName = 'anaqa_mobile.db';

  final DatabaseFactory _factory;
  final String? _path;
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = _path ?? p.join(await _factory.getDatabasesPath(), fileName);
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          final batch = db.batch();
          for (final statement in Schema.v1) {
            batch.execute(statement);
          }
          await batch.commit(noResult: true);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // أضف هنا ترحيلات الإصدارات القادمة: if (oldVersion < 2) { ... }
        },
      ),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

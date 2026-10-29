import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../database/schema.dart';
import 'sync_operation.dart';

/// طابور العمليات المحلية (Outbox).
///
/// كل تعديل محلي يجب أن يُرسل للسيرفر يُضاف هنا **داخل نفس الـ transaction**
/// التي تحفظ التعديل، حتى لا يُحفظ أحدهما بدون الآخر.
class SyncQueue {
  SyncQueue(this._appDb);

  final AppDatabase _appDb;
  final _changes = StreamController<void>.broadcast();

  /// يصدر عند أي تغيير في الطابور (لتحديث عداد العمليات المنتظرة).
  Stream<void> get changes => _changes.stream;

  Future<void> enqueue(
    DatabaseExecutor txn, {
    required String operation,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await txn.insert(Tables.syncQueue, {
      'operation': operation,
      'entity_id': entityId,
      'payload': jsonEncode(payload),
      'status': SyncStatus.pending,
      'attempts': 0,
      'created_at': now,
      'updated_at': now,
    });
    // الإشعار بعد انتهاء الـ transaction الحالية.
    scheduleMicrotask(notifyChanged);
  }

  Future<List<SyncOperation>> pending({int limit = 50}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.syncQueue,
      where: 'status = ?',
      whereArgs: [SyncStatus.pending],
      orderBy: 'id',
      limit: limit,
    );
    return rows.map(SyncOperation.fromDb).toList();
  }

  Future<void> remove(int id) async {
    final db = await _appDb.database;
    await db.delete(Tables.syncQueue, where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }

  /// فشل مؤقت: تبقى العملية في الطابور لمحاولة لاحقة.
  Future<void> recordAttempt(int id, String error) => _update(id, error, SyncStatus.pending);

  /// فشل نهائي: تخرج من الطابور التلقائي وتنتظر مراجعة يدوية.
  Future<void> markFailed(int id, String error) => _update(id, error, SyncStatus.failed);

  /// يعيد العمليات الفاشلة للطابور (زر "إعادة المحاولة").
  Future<int> retryFailed() async {
    final db = await _appDb.database;
    final count = await db.update(
      Tables.syncQueue,
      {'status': SyncStatus.pending, 'attempts': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'status = ?',
      whereArgs: [SyncStatus.failed],
    );
    notifyChanged();
    return count;
  }

  Future<({int pending, int failed})> counts() async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('SELECT status, COUNT(*) AS c FROM ${Tables.syncQueue} GROUP BY status');
    var pending = 0;
    var failed = 0;
    for (final row in rows) {
      final count = row['c']! as int;
      if (row['status'] == SyncStatus.pending) pending = count;
      if (row['status'] == SyncStatus.failed) failed = count;
    }
    return (pending: pending, failed: failed);
  }

  Future<void> _update(int id, String error, String status) async {
    final db = await _appDb.database;
    await db.rawUpdate(
      'UPDATE ${Tables.syncQueue} SET attempts = attempts + 1, last_error = ?, status = ?, updated_at = ? WHERE id = ?',
      [error, status, DateTime.now().toUtc().toIso8601String(), id],
    );
    notifyChanged();
  }

  void notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}

import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/sync/sync_queue.dart';
import '../../domain/entities/online_order.dart';
import '../models/online_order_model.dart';

const String updateOrderStatusOperation = 'online_order.update_status';

class OnlineOrdersLocalDataSource {
  OnlineOrdersLocalDataSource(this._appDb, this._queue);

  final AppDatabase _appDb;
  final SyncQueue _queue;

  Future<List<OnlineOrder>> getOrders({OnlineOrderStatus? status}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.onlineOrders,
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.apiValue],
      orderBy: 'created_at DESC',
    );
    return rows.map(OnlineOrderModel.fromDb).toList();
  }

  Future<OnlineOrder> updateStatus(String orderId, OnlineOrderStatus status) async {
    final db = await _appDb.database;
    return db.transaction((txn) async {
      final updated = await txn.update(
        Tables.onlineOrders,
        {'status': status.apiValue, 'sync_status': SyncStatus.pending},
        where: 'id = ? AND status = ?',
        whereArgs: [orderId, OnlineOrderStatus.pending.apiValue],
      );
      if (updated == 0) throw const CacheException('الطلب غير موجود أو تمت معالجته');
      await _queue.enqueue(
        txn,
        operation: updateOrderStatusOperation,
        entityId: orderId,
        payload: {'order_id': orderId, 'status': status.apiValue},
      );
      final row = await txn.query(Tables.onlineOrders, where: 'id = ?', whereArgs: [orderId]);
      return OnlineOrderModel.fromDb(row.single);
    });
  }

  /// يحدّث الطلبات من السيرفر، مع الحفاظ على التغييرات المحلية التي لم تُرسل بعد.
  Future<void> upsertFromServer(List<Map<String, Object?>> rows) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final pendingIds = (await txn.query(
        Tables.onlineOrders,
        columns: ['id'],
        where: 'sync_status != ?',
        whereArgs: [SyncStatus.synced],
      )).map((r) => r['id']).toSet();
      final batch = txn.batch();
      for (final row in rows) {
        if (pendingIds.contains(row['id'])) continue;
        batch.insert(Tables.onlineOrders, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// عند الدخول بفرع مختلف: يحذف طلبات الفرع السابق، ويُبقي التغييرات التي لم تُرسل بعد.
  Future<void> clearSynced() async {
    final db = await _appDb.database;
    await db.delete(Tables.onlineOrders, where: 'sync_status = ?', whereArgs: [SyncStatus.synced]);
  }

  Future<void> markSynced(String orderId) => _setSyncStatus(orderId, SyncStatus.synced);

  /// السيرفر رفض التغيير: نرجع الطلب لـ "معلق" حتى يُسحب وضعه الحقيقي.
  Future<void> revertStatus(String orderId) async {
    final db = await _appDb.database;
    await db.update(
      Tables.onlineOrders,
      {'status': OnlineOrderStatus.pending.apiValue, 'sync_status': SyncStatus.synced},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> _setSyncStatus(String orderId, String status) async {
    final db = await _appDb.database;
    await db.update(Tables.onlineOrders, {'sync_status': status}, where: 'id = ?', whereArgs: [orderId]);
  }
}

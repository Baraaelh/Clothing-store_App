import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/sync/sync_queue.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/sale.dart';
import '../models/catalog_item_model.dart';
import '../models/sale_model.dart';

/// اسم عملية المزامنة لإنشاء فاتورة.
const String createSaleOperation = 'sale.create';

class PosLocalDataSource {
  PosLocalDataSource(this._appDb, this._queue);

  final AppDatabase _appDb;
  final SyncQueue _queue;

  /// الكمية المتاحة = كمية السيرفر - المبيعات المحلية التي لم يؤكدها السيرفر بعد.
  static const String _availableSql =
      '''
    (c.server_quantity - COALESCE((
      SELECT SUM(si.quantity) FROM ${Tables.saleItems} si
      JOIN ${Tables.sales} s ON s.id = si.sale_id
      WHERE si.variant_id = c.variant_id AND s.sync_status != '${SyncStatus.synced}'
    ), 0))
  ''';

  Future<List<CatalogItem>> getCatalog({String query = ''}) async {
    final db = await _appDb.database;
    final where = StringBuffer('c.is_active = 1');
    final args = <Object?>[];
    if (query.isNotEmpty) {
      where.write(' AND (c.product_name LIKE ? OR c.sku LIKE ? OR c.product_code LIKE ?)');
      final like = '%$query%';
      args.addAll([like, like, like]);
    }
    final rows = await db.rawQuery(
      'SELECT c.*, $_availableSql AS available_quantity FROM ${Tables.catalogItems} c '
      'WHERE $where ORDER BY c.product_name, c.color_name, c.size_name',
      args,
    );
    return rows.map(CatalogItemModel.fromDb).toList();
  }

  /// يحفظ الفاتورة وعناصرها ويضيفها لطابور المزامنة في transaction واحدة.
  /// يعيد التحقق من الكميات داخل الـ transaction لمنع البيع بأكثر من المتوفر.
  Future<void> insertSale(Sale sale, Map<String, Object?> syncPayload) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final requested = <int, int>{};
      for (final item in sale.items) {
        requested.update(item.variantId, (q) => q + item.quantity, ifAbsent: () => item.quantity);
      }
      for (final entry in requested.entries) {
        final available = await _availableQuantity(txn, entry.key);
        if (available == null) throw CacheException('الصنف ${entry.key} غير موجود');
        if (entry.value > available) {
          throw CacheException('الكمية غير متوفرة للصنف ${entry.key}: المتوفر $available');
        }
      }

      await txn.insert(Tables.sales, SaleModel.toDb(sale));
      for (final item in sale.items) {
        await txn.insert(Tables.saleItems, SaleModel.itemToDb(sale.id, item));
      }
      await _queue.enqueue(txn, operation: createSaleOperation, entityId: sale.id, payload: syncPayload);
    });
  }

  Future<int?> _availableQuantity(DatabaseExecutor txn, int variantId) async {
    final rows = await txn.rawQuery(
      'SELECT $_availableSql AS q FROM ${Tables.catalogItems} c WHERE c.variant_id = ? AND c.is_active = 1',
      [variantId],
    );
    return rows.isEmpty ? null : rows.first['q']! as int;
  }

  Future<List<Sale>> getRecentSales({int limit = 20}) async {
    final db = await _appDb.database;
    final sales = await db.query(Tables.sales, orderBy: 'created_at DESC', limit: limit);
    if (sales.isEmpty) return const [];
    final ids = sales.map((s) => s['id']! as String).toList();
    final items = await db.query(
      Tables.saleItems,
      where: 'sale_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'id',
    );
    return [for (final s in sales) SaleModel.fromDb(s, items.where((i) => i['sale_id'] == s['id']).toList())];
  }

  /// السيرفر قبل الفاتورة وخصمها من مخزونه: نخصمها من server_quantity المحلي أيضًا،
  /// حتى لا ترتفع الكمية المتاحة مؤقتًا قبل سحب المنتجات القادم.
  Future<void> markSaleSynced(String saleId, int? serverId) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final updated = await txn.update(
        Tables.sales,
        {'sync_status': SyncStatus.synced, 'server_id': serverId},
        where: 'id = ? AND sync_status != ?',
        whereArgs: [saleId, SyncStatus.synced],
      );
      if (updated == 0) return;
      await txn.rawUpdate(
        'UPDATE ${Tables.catalogItems} SET server_quantity = server_quantity - ('
        'SELECT SUM(si.quantity) FROM ${Tables.saleItems} si '
        'WHERE si.sale_id = ? AND si.variant_id = ${Tables.catalogItems}.variant_id) '
        'WHERE variant_id IN (SELECT variant_id FROM ${Tables.saleItems} WHERE sale_id = ?)',
        [saleId, saleId],
      );
    });
  }

  Future<void> markSaleFailed(String saleId) async {
    final db = await _appDb.database;
    await db.update(Tables.sales, {'sync_status': SyncStatus.failed}, where: 'id = ?', whereArgs: [saleId]);
  }

  /// يستبدل نسخة المنتجات بما أرسله السيرفر. الأصناف غير الموجودة في الرد تُعطّل
  /// (لا تُحذف، لأن فواتير محلية قد تشير إليها).
  Future<void> replaceCatalog(List<Map<String, Object?>> rows) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.update(Tables.catalogItems, {'is_active': 0});
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert(Tables.catalogItems, row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<bool> isCatalogEmpty() async {
    final db = await _appDb.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ${Tables.catalogItems}'));
    return (count ?? 0) == 0;
  }
}

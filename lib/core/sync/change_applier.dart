import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/schema.dart';
import '../utils/money.dart';

/// يطبق صفحة تغييرات من `/sync/bootstrap` أو `/sync/pull` على الـ Cache.
///
/// كل تغيير upsert أو delete حسب entity + id، ويمكن أن يتكرر بأمان (idempotent).
/// يُستدعى داخل transaction مع حفظ الـ cursor.
class ChangeApplier {
  const ChangeApplier();

  Future<int> apply(DatabaseExecutor txn, List<Object?> changes) async {
    var applied = 0;
    for (final raw in changes) {
      if (raw is! Map) continue;
      final change = raw.cast<String, Object?>();
      final entity = change['entity'];
      final id = change['id'];
      if (entity is! String || id is! int) continue;
      final data = change['data'];
      if (change['action'] == 'delete' || data is! Map) {
        await _delete(txn, entity, id);
      } else {
        await _upsert(txn, entity, id, data.cast<String, Object?>());
      }
      applied++;
    }
    return applied;
  }

  Future<void> _upsert(DatabaseExecutor txn, String entity, int id, Map<String, Object?> d) async {
    final (table, row) = switch (entity) {
      'categories' => (Tables.categories, {'id': id, 'name': d['name'], 'is_active': _bool(d['is_active'])}),
      'colors' => (
        Tables.colors,
        {
          'id': id,
          'name': d['name'],
          'code': d['code'],
          'hex': d['hex'] ?? d['hex_code'],
          'is_active': _bool(d['is_active']),
        },
      ),
      'sizes' => (
        Tables.sizes,
        {
          'id': id,
          'name': d['name'],
          'code': d['code'],
          'sort_order': d['sort_order'] ?? 0,
          'is_active': _bool(d['is_active']),
        },
      ),
      'products' => (
        Tables.products,
        {
          'id': id,
          'code': d['code'] ?? '',
          'name': d['name'] ?? '',
          'category_id': d['category_id'],
          'description': d['description'],
          'is_active': _bool(d['is_active']),
          'revision': d['revision'],
        },
      ),
      'variants' => (
        Tables.variants,
        {
          'id': id,
          'product_id': d['product_id'],
          'color_id': d['color_id'],
          'size_id': d['size_id'],
          'sku': d['sku'] ?? '',
          'selling_price': Money.fromJson(d['selling_price']),
          'minimum_selling_price': d['minimum_selling_price'] == null
              ? null
              : Money.fromJson(d['minimum_selling_price']),
          'is_active': _bool(d['is_active']),
          'revision': d['revision'],
        },
      ),
      'stocks' => (
        Tables.stocks,
        {
          'variant_id': d['product_variant_id'],
          'id': id,
          'quantity': d['quantity'] ?? 0,
          'reserved_quantity': d['reserved_quantity'] ?? 0,
          'available_quantity':
              d['available_quantity'] ?? ((d['quantity'] as int? ?? 0) - (d['reserved_quantity'] as int? ?? 0)),
          'average_cost': d['average_cost'] == null ? null : Money.fromJson(d['average_cost']),
          'revision': d['revision'] ?? '',
        },
      ),
      'accounts' => (
        Tables.accounts,
        {'id': id, 'name': d['name'] ?? '', 'type': d['type'] ?? 'cash', 'is_active': _bool(d['is_active'])},
      ),
      'customers' => (Tables.customers, {'id': id, 'name': d['name'] ?? '', 'phone': d['phone']}),
      'suppliers' => (Tables.suppliers, {'id': id, 'name': d['name'] ?? '', 'phone': d['phone'] ?? d['phone1']}),
      'branches' => (
        Tables.branches,
        {
          'id': id,
          'name': d['name'] ?? '',
          'is_active': _bool(d['is_active']),
          'opening_stock_closed_at': d['opening_stock_closed_at'],
        },
      ),
      _ => (Tables.other, {'entity': entity, 'id': id, 'data': jsonEncode(d)}),
    };
    if (table == Tables.stocks) {
      // المفتاح المحلي هو الصنف؛ احذف أي صف قديم بنفس رقم المخزون لصنف آخر.
      await txn.delete(Tables.stocks, where: 'id = ? AND variant_id != ?', whereArgs: [id, row['variant_id']]);
    }
    await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _delete(DatabaseExecutor txn, String entity, int id) async {
    switch (entity) {
      case 'products':
        final variantIds = (await txn.query(
          Tables.variants,
          columns: ['id'],
          where: 'product_id = ?',
          whereArgs: [id],
        )).map((r) => r['id']! as int).toList();
        for (final v in variantIds) {
          await txn.delete(Tables.stocks, where: 'variant_id = ?', whereArgs: [v]);
        }
        await txn.delete(Tables.variants, where: 'product_id = ?', whereArgs: [id]);
        await txn.delete(Tables.products, where: 'id = ?', whereArgs: [id]);
      case 'variants':
        await txn.delete(Tables.stocks, where: 'variant_id = ?', whereArgs: [id]);
        await txn.delete(Tables.variants, where: 'id = ?', whereArgs: [id]);
      case 'stocks':
        await txn.delete(Tables.stocks, where: 'id = ?', whereArgs: [id]);
      default:
        final table = _tableFor(entity);
        if (table == Tables.other) {
          await txn.delete(Tables.other, where: 'entity = ? AND id = ?', whereArgs: [entity, id]);
        } else {
          await txn.delete(table, where: 'id = ?', whereArgs: [id]);
        }
    }
  }

  static String _tableFor(String entity) => switch (entity) {
    'categories' => Tables.categories,
    'colors' => Tables.colors,
    'sizes' => Tables.sizes,
    'accounts' => Tables.accounts,
    'customers' => Tables.customers,
    'suppliers' => Tables.suppliers,
    'branches' => Tables.branches,
    _ => Tables.other,
  };

  static int _bool(Object? v) => v == false || v == 0 ? 0 : 1;
}

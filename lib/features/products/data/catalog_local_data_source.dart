import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/schema.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/session/session.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/utils/money.dart';
import '../domain/product.dart';

/// المنتجات والأصناف والمخزون من الـ Cache، وإنشاء/تعديل المنتجات عبر الـ Outbox.
class CatalogLocalDataSource {
  CatalogLocalDataSource(this._appDb, this._outbox, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final AppDatabase _appDb;
  final Outbox _outbox;
  final Uuid _uuid;

  Future<List<ProductSummary>> products({String query = '', bool includeInactive = true}) async {
    final db = await _appDb.database;
    final args = <Object?>[];
    final where = <String>[];
    if (!includeInactive) where.add('p.is_active = 1');
    if (query.isNotEmpty) {
      where.add(
        '(p.name LIKE ? OR p.code LIKE ? OR EXISTS (SELECT 1 FROM ${Tables.variants} vv WHERE vv.product_id = p.id AND vv.sku LIKE ?))',
      );
      final like = '%$query%';
      args.addAll([like, like, like]);
    }
    final rows = await db.rawQuery('''
      SELECT p.id, p.code, p.name, p.is_active, cat.name AS category_name,
             COUNT(v.id) AS variant_count,
             COALESCE(SUM(st.available_quantity), 0) AS total_available,
             COALESCE(MIN(v.selling_price), 0) AS min_price,
             COALESCE(MAX(v.selling_price), 0) AS max_price
      FROM ${Tables.products} p
      LEFT JOIN ${Tables.categories} cat ON cat.id = p.category_id
      LEFT JOIN ${Tables.variants} v ON v.product_id = p.id AND v.is_active = 1
      LEFT JOIN ${Tables.stocks} st ON st.variant_id = v.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      GROUP BY p.id
      ORDER BY p.is_active DESC, p.name
    ''', args);
    return [
      for (final r in rows)
        ProductSummary(
          id: r['id']! as int,
          code: r['code']! as String,
          name: r['name']! as String,
          categoryName: r['category_name'] as String?,
          isActive: r['is_active'] == 1,
          variantCount: r['variant_count']! as int,
          totalAvailable: r['total_available']! as int,
          minPrice: r['min_price']! as int,
          maxPrice: r['max_price']! as int,
        ),
    ];
  }

  Future<ProductDetail?> product(int id) async {
    final db = await _appDb.database;
    final p = await db.rawQuery(
      'SELECT p.*, cat.name AS category_name FROM ${Tables.products} p '
      'LEFT JOIN ${Tables.categories} cat ON cat.id = p.category_id WHERE p.id = ?',
      [id],
    );
    if (p.isEmpty) return null;
    final row = p.first;
    return ProductDetail(
      id: id,
      code: row['code']! as String,
      name: row['name']! as String,
      categoryId: row['category_id'] as int?,
      categoryName: row['category_name'] as String?,
      description: row['description'] as String?,
      isActive: row['is_active'] == 1,
      revision: row['revision'] as String?,
      variants: await variants(productId: id),
    );
  }

  /// أصناف منتج، أو كل الأصناف الفعالة (للمخزون والشراء).
  Future<List<VariantInfo>> variants({int? productId, String query = '', bool activeOnly = false}) async {
    final db = await _appDb.database;
    final where = <String>[];
    final args = <Object?>[];
    if (productId != null) {
      where.add('v.product_id = ?');
      args.add(productId);
    }
    if (activeOnly) where.add('v.is_active = 1 AND p.is_active = 1');
    if (query.isNotEmpty) {
      where.add('(p.name LIKE ? OR v.sku LIKE ? OR p.code LIKE ?)');
      final like = '%$query%';
      args.addAll([like, like, like]);
    }
    final rows = await db.rawQuery('''
      SELECT v.*, c.name AS color_name, c.hex AS color_hex, s.name AS size_name,
             st.quantity, st.reserved_quantity, st.available_quantity, st.average_cost
      FROM ${Tables.variants} v
      JOIN ${Tables.products} p ON p.id = v.product_id
      LEFT JOIN ${Tables.colors} c ON c.id = v.color_id
      LEFT JOIN ${Tables.sizes} s ON s.id = v.size_id
      LEFT JOIN ${Tables.stocks} st ON st.variant_id = v.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY p.name, c.name, s.sort_order, s.name
    ''', args);
    return rows.map(_variant).toList();
  }

  /// الأصناف مع رقم المنتج (للمخزون والشراء).
  Future<List<(int, VariantInfo)>> variantsWithProduct({String query = '', bool activeOnly = false}) async {
    final db = await _appDb.database;
    final where = <String>[if (activeOnly) 'v.is_active = 1 AND p.is_active = 1'];
    final args = <Object?>[];
    if (query.isNotEmpty) {
      where.add('(p.name LIKE ? OR v.sku LIKE ? OR p.code LIKE ?)');
      final like = '%$query%';
      args.addAll([like, like, like]);
    }
    final rows = await db.rawQuery('''
      SELECT v.*, c.name AS color_name, c.hex AS color_hex, s.name AS size_name,
             st.quantity, st.reserved_quantity, st.available_quantity, st.average_cost
      FROM ${Tables.variants} v
      JOIN ${Tables.products} p ON p.id = v.product_id
      LEFT JOIN ${Tables.colors} c ON c.id = v.color_id
      LEFT JOIN ${Tables.sizes} s ON s.id = v.size_id
      LEFT JOIN ${Tables.stocks} st ON st.variant_id = v.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY p.name, c.name, s.sort_order, s.name
    ''', args);
    return [for (final r in rows) (r['product_id']! as int, _variant(r))];
  }

  static VariantInfo _variant(Map<String, Object?> r) => VariantInfo(
    id: r['id']! as int,
    colorId: (r['color_id'] as int?) ?? 0,
    sizeId: (r['size_id'] as int?) ?? 0,
    colorName: r['color_name'] as String?,
    colorHex: r['color_hex'] as String?,
    sizeName: r['size_name'] as String?,
    sku: r['sku']! as String,
    price: r['selling_price']! as int,
    minPrice: r['minimum_selling_price'] as int?,
    isActive: r['is_active'] == 1,
    quantity: r['quantity'] as int?,
    reserved: r['reserved_quantity'] as int?,
    available: r['available_quantity'] as int?,
    averageCost: r['average_cost'] as int?,
  );

  /// `product.create`: المنتج وأصنافه بمعرّفات محلية حتى يرد السيرفر بالأرقام النهائية والـ SKU.
  Future<String> createProduct(Session session, ProductDraft draft, {required bool includeMinimum}) async {
    final db = await _appDb.database;
    final uuid = _uuid.v4();
    await db.transaction((txn) async {
      await _outbox.enqueue(
        txn,
        uuid: uuid,
        type: 'product.create',
        branchId: session.branchId,
        userId: session.userId,
        summary: 'منتج جديد: ${draft.name} (${draft.variants.length} صنف)',
        payload: {
          'client_uuid': _uuid.v4(),
          'name': draft.name,
          'category_id': draft.categoryId,
          if (draft.description?.isNotEmpty ?? false) 'description': draft.description,
          'is_active': draft.isActive,
          'variants': [
            for (final v in draft.variants) {'client_uuid': _uuid.v4(), ..._variantPayload(v, includeMinimum)},
          ],
        },
      );
    });
    return uuid;
  }

  /// `product.update` مع expected_revision: السيرفر يرفض التعديل إن تغير المنتج من مكان آخر.
  Future<String> updateProduct(
    Session session,
    ProductDetail current,
    ProductDraft draft, {
    required bool includeMinimum,
  }) async {
    if (current.revision == null) throw const CacheException('لا توجد مراجعة للمنتج؛ زامن أولًا');
    final db = await _appDb.database;
    final uuid = _uuid.v4();
    await db.transaction((txn) async {
      await _outbox.enqueue(
        txn,
        uuid: uuid,
        type: 'product.update',
        branchId: session.branchId,
        userId: session.userId,
        summary: 'تعديل منتج: ${draft.name}',
        payload: {
          'product_id': current.id,
          'expected_revision': current.revision,
          'name': draft.name,
          'category_id': draft.categoryId,
          'description': draft.description ?? '',
          'is_active': draft.isActive,
          'variants': [
            for (final v in draft.variants)
              {if (v.id != null) 'id': v.id else 'client_uuid': _uuid.v4(), ..._variantPayload(v, includeMinimum)},
          ],
        },
      );
    });
    return uuid;
  }

  static Map<String, Object?> _variantPayload(VariantDraft v, bool includeMinimum) => {
    'color_id': v.colorId,
    'size_id': v.sizeId,
    'selling_price': Money.toDecimalString(v.price),
    if (includeMinimum) 'minimum_selling_price': v.minPrice == null ? null : Money.toDecimalString(v.minPrice!),
    if (v.id != null) 'is_active': v.isActive,
  };

  /// منتجات أُنشئت على الجهاز ولم يقبلها السيرفر بعد (تظهر في القائمة كـ "بانتظار المزامنة").
  Future<List<OutboxOperation>> pendingProductOps(int userId) async {
    final ops = await _outbox.list(statuses: [OutboxStatus.pending], userId: userId);
    return ops.where((op) => op.type.startsWith('product.')).toList();
  }

  Future<String?> branchOpeningClosedAt(int branchId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.branches,
      columns: ['opening_stock_closed_at'],
      where: 'id = ?',
      whereArgs: [branchId],
    );
    return rows.isEmpty ? null : rows.first['opening_stock_closed_at'] as String?;
  }

  Future<bool> isBranchKnown(int branchId) async {
    final db = await _appDb.database;
    return (Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM ${Tables.branches} WHERE id = ?', [branchId]),
            ) ??
            0) >
        0;
  }
}

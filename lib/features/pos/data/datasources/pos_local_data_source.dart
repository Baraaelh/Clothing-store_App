import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/session/session.dart';
import '../../../../core/sync/outbox.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/checkout_request.dart';
import '../../domain/entities/sale.dart';

const String saleOperation = 'sale.create';

class PosLocalDataSource {
  PosLocalDataSource(this._appDb, this._outbox);

  final AppDatabase _appDb;
  final Outbox _outbox;

  /// المتاح = available_quantity من السيرفر - مبيعات الجهاز التي لم يقبلها السيرفر بعد.
  static const String _pendingSql =
      '''
    COALESCE((
      SELECT SUM(li.quantity) FROM ${Tables.localSaleItems} li
      JOIN ${Tables.localSales} ls ON ls.id = li.sale_id
      WHERE li.variant_id = v.id AND ls.status = '${OutboxStatus.pending}'
    ), 0)
  ''';

  static const String _catalogSelect =
      '''
    SELECT v.id AS variant_id, v.product_id, v.sku, v.selling_price, v.minimum_selling_price,
           p.code AS product_code, p.name AS product_name, cat.name AS category_name,
           c.name AS color_name, c.hex AS color_hex, s.name AS size_name,
           st.revision AS stock_revision,
           (st.available_quantity - $_pendingSql) AS available
    FROM ${Tables.variants} v
    JOIN ${Tables.products} p ON p.id = v.product_id
    JOIN ${Tables.stocks} st ON st.variant_id = v.id
    LEFT JOIN ${Tables.categories} cat ON cat.id = p.category_id
    LEFT JOIN ${Tables.colors} c ON c.id = v.color_id
    LEFT JOIN ${Tables.sizes} s ON s.id = v.size_id
    WHERE v.is_active = 1 AND p.is_active = 1
  ''';

  Future<List<CatalogItem>> getCatalog({String query = ''}) async {
    final db = await _appDb.database;
    final args = <Object?>[];
    var where = '';
    if (query.isNotEmpty) {
      where = ' AND (p.name LIKE ? OR v.sku LIKE ? OR p.code LIKE ?)';
      final like = '%$query%';
      args.addAll([like, like, like]);
    }
    final rows = await db.rawQuery('$_catalogSelect$where ORDER BY p.name, c.name, s.sort_order, s.name', args);
    return rows.map(CatalogItem.fromDb).toList();
  }

  /// يحفظ الفاتورة ويضيف عملية `sale.create` للـ Outbox في transaction واحدة.
  ///
  /// كل سطر يحمل مراجعة المخزون كما يعرفها الجهاز (expected_revision). إذا كانت على الصنف
  /// فاتورة سابقة من هذا الجهاز لم تُقبل بعد، يُربط بها (stock_revision_from + dependency)
  /// لأن مراجعتها الجديدة لا تُعرف إلا من رد السيرفر.
  Future<Sale> insertSale({
    required String saleId,
    required String operationUuid,
    required Session session,
    required CheckoutRequest request,
    required DateTime createdAt,
  }) async {
    final db = await _appDb.database;
    return db.transaction((txn) async {
      final requested = <int, int>{};
      for (final line in request.lines) {
        requested.update(line.item.variantId, (q) => q + line.quantity, ifAbsent: () => line.quantity);
      }
      for (final entry in requested.entries) {
        final rows = await txn.rawQuery('$_catalogSelect AND v.id = ?', [entry.key]);
        if (rows.isEmpty) throw const CacheException('الصنف لم يعد متاحًا في هذا الفرع');
        final available = (rows.first['available'] as int?) ?? 0;
        if (entry.value > available) {
          throw CacheException('الكمية غير متوفرة: ${rows.first['product_name']} — المتوفر $available');
        }
      }

      final refs = await _stockRefs(txn, requested.keys);
      final payload = buildPayload(request, refs.byVariant);
      final paymentLabel = _paymentLabel(request);
      final sale = Sale(
        id: saleId,
        operationUuid: operationUuid,
        cashierName: session.userName,
        customerName: request.customer?.name,
        paymentLabel: paymentLabel,
        subtotal: request.subtotal,
        discount: request.discount,
        total: request.total,
        paid: request.collected,
        createdAt: createdAt,
        status: SaleStatus.pending,
        change: request.change,
        items: [
          for (final line in request.lines)
            SaleItem(
              variantId: line.item.variantId,
              productName: line.item.productName,
              variantLabel: line.item.variantLabel,
              sku: line.item.sku,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
            ),
        ],
      );

      await txn.insert(Tables.localSales, {
        'id': sale.id,
        'operation_uuid': operationUuid,
        'user_id': session.userId,
        'branch_id': session.branchId,
        'created_at': createdAt.toUtc().toIso8601String(),
        'cashier_name': sale.cashierName,
        'customer_name': sale.customerName,
        'payment_label': paymentLabel,
        'subtotal': sale.subtotal,
        'discount': sale.discount,
        'total': sale.total,
        'paid': sale.paid,
        'status': OutboxStatus.pending,
      });
      for (final item in sale.items) {
        await txn.insert(Tables.localSaleItems, {
          'sale_id': sale.id,
          'variant_id': item.variantId,
          'product_name': item.productName,
          'variant_label': item.variantLabel,
          'sku': item.sku,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
        });
      }
      await _outbox.enqueue(
        txn,
        uuid: operationUuid,
        type: saleOperation,
        branchId: session.branchId,
        userId: session.userId,
        payload: payload,
        dependencies: refs.dependencies,
        summary:
            'بيع ${sale.itemCount} قطعة بـ ${Money.format(sale.total)}${sale.customerName == null ? '' : ' — ${sale.customerName}'}',
        createdAt: createdAt,
      );
      return sale;
    });
  }

  /// بعد مراجعة فاتورة مرفوضة (مثل تأكيد البيع تحت الحد الأدنى): عملية جديدة بنفس السلة
  /// ومراجعات مخزون محدّثة، والعملية القديمة تُغلق.
  Future<void> resubmitSale({
    required OutboxOperation rejected,
    required String newOperationUuid,
    required Map<String, Object?> extraPayload,
  }) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final saleRows = await txn.query(
        Tables.localSales,
        where: 'operation_uuid = ?',
        whereArgs: [rejected.uuid],
        limit: 1,
      );
      if (saleRows.isEmpty) throw const CacheException('الفاتورة المحلية غير موجودة');
      final saleId = saleRows.first['id']! as String;
      final rows = [for (final r in rejected.payload['rows']! as List) (r as Map).cast<String, Object?>()];
      final variantIds = rows.map((r) => r['product_variant_id']! as int).toList();
      // نستثني الفاتورة نفسها من البحث عن فواتير سابقة معلقة.
      final refs = await _stockRefs(txn, variantIds, excludeSaleId: saleId);
      final payload = <String, Object?>{
        ...rejected.payload,
        ...extraPayload,
        'rows': [
          for (final r in rows)
            {
              for (final e in r.entries)
                if (e.key != 'expected_revision' && e.key != 'stock_revision_from') e.key: e.value,
              ...refs.byVariant[r['product_variant_id']]!,
            },
        ],
      };
      await _outbox.dismiss(txn, rejected.uuid);
      await txn.update(
        Tables.localSales,
        {'operation_uuid': newOperationUuid, 'status': OutboxStatus.pending},
        where: 'id = ?',
        whereArgs: [saleId],
      );
      await _outbox.enqueue(
        txn,
        uuid: newOperationUuid,
        type: saleOperation,
        branchId: rejected.branchId,
        userId: rejected.userId,
        payload: payload,
        dependencies: refs.dependencies,
        summary: rejected.summary,
      );
    });
  }

  /// يلغي فاتورة رفضها السيرفر (تبقى في السجل كمرفوضة، ولا تخصم من الكميات).
  Future<void> dismissSale(OutboxOperation rejected) async {
    final db = await _appDb.database;
    await db.transaction((txn) => _outbox.dismiss(txn, rejected.uuid));
  }

  Future<({Map<int, Map<String, Object?>> byVariant, List<String> dependencies})> _stockRefs(
    DatabaseExecutor txn,
    Iterable<int> variantIds, {
    String? excludeSaleId,
  }) async {
    final byVariant = <int, Map<String, Object?>>{};
    final deps = <String>{};
    for (final variantId in variantIds) {
      final pending = await txn.rawQuery(
        'SELECT ls.operation_uuid FROM ${Tables.localSales} ls '
        'JOIN ${Tables.localSaleItems} li ON li.sale_id = ls.id '
        "WHERE li.variant_id = ? AND ls.status = '${OutboxStatus.pending}'${excludeSaleId == null ? '' : ' AND ls.id != ?'} "
        'ORDER BY ls.created_at DESC LIMIT 1',
        [variantId, ?excludeSaleId],
      );
      if (pending.isNotEmpty) {
        final parent = pending.first['operation_uuid']! as String;
        byVariant[variantId] = {'stock_revision_from': parent};
        deps.add(parent);
        continue;
      }
      final stock = await txn.query(
        Tables.stocks,
        columns: ['revision'],
        where: 'variant_id = ?',
        whereArgs: [variantId],
      );
      if (stock.isEmpty) throw const CacheException('لا يوجد رصيد معروف لهذا الصنف؛ زامن أولًا');
      byVariant[variantId] = {'expected_revision': stock.first['revision']};
    }
    return (byVariant: byVariant, dependencies: deps.toList());
  }

  /// payload عملية `sale.create` حسب العقد. المبالغ سلاسل عشرية، ولا تُرسل تكاليف.
  static Map<String, Object?> buildPayload(CheckoutRequest request, Map<int, Map<String, Object?>> refs) => {
    'payment_mode': request.mode.apiValue,
    if (request.customer != null) 'customer_id': request.customer!.id,
    if (request.mode != PaymentMode.credit && request.account != null)
      'payments': [
        {'account_id': request.account!.id, 'amount': Money.toDecimalString(request.collected), 'confirmed': true},
      ],
    if (request.discount > 0) 'discount': {'type': 'amount', 'value': Money.toDecimalString(request.discount)},
    if (request.notes?.trim().isNotEmpty ?? false) 'notes': request.notes!.trim(),
    'rows': [
      for (final line in request.lines)
        {
          'product_variant_id': line.item.variantId,
          'quantity': line.quantity,
          if (line.unitPrice != line.item.sellingPrice) ...{
            'unit_price': Money.toDecimalString(line.unitPrice),
            'price_reason': 'تعديل سعر من الكاشير',
          },
          ...refs[line.item.variantId]!,
        },
    ],
  };

  static String _paymentLabel(CheckoutRequest request) => switch (request.mode) {
    PaymentMode.paid => request.account?.name ?? 'مدفوع',
    PaymentMode.partial => 'جزئي — ${request.account?.name ?? ''}',
    PaymentMode.credit => 'آجل',
  };

  Future<void> markAccepted(DatabaseExecutor txn, String operationUuid, String? number) => txn.update(
    Tables.localSales,
    {'status': OutboxStatus.accepted, 'number': number},
    where: 'operation_uuid = ?',
    whereArgs: [operationUuid],
  );

  Future<void> markRejected(DatabaseExecutor txn, String operationUuid) => txn.update(
    Tables.localSales,
    {'status': OutboxStatus.review},
    where: 'operation_uuid = ?',
    whereArgs: [operationUuid],
  );

  Future<List<Sale>> getRecentSales({required int userId, required int branchId, int limit = 50}) async {
    final db = await _appDb.database;
    final sales = await db.query(
      Tables.localSales,
      where: 'user_id = ? AND branch_id = ?',
      whereArgs: [userId, branchId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    if (sales.isEmpty) return const [];
    final ids = sales.map((s) => s['id']! as String).toList();
    final items = await db.query(
      Tables.localSaleItems,
      where: 'sale_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'id',
    );
    return [
      for (final s in sales)
        Sale(
          id: s['id']! as String,
          operationUuid: s['operation_uuid']! as String,
          cashierName: s['cashier_name']! as String,
          customerName: s['customer_name'] as String?,
          paymentLabel: s['payment_label']! as String,
          subtotal: s['subtotal']! as int,
          discount: s['discount']! as int,
          total: s['total']! as int,
          paid: s['paid']! as int,
          createdAt: DateTime.parse(s['created_at']! as String).toLocal(),
          status: SaleStatus.fromDb(s['status']! as String),
          number: s['number'] as String?,
          items: [
            for (final i in items.where((i) => i['sale_id'] == s['id']))
              SaleItem(
                variantId: i['variant_id']! as int,
                productName: i['product_name']! as String,
                variantLabel: i['variant_label'] as String?,
                sku: i['sku']! as String,
                quantity: i['quantity']! as int,
                unitPrice: i['unit_price']! as int,
              ),
          ],
        ),
    ];
  }
}

/// يحدّث حالة الفاتورة المحلية حسب نتيجة السيرفر.
class SaleOperationHandler implements OperationHandler {
  SaleOperationHandler(this._local);

  final PosLocalDataSource _local;

  @override
  String get type => saleOperation;

  @override
  Future<void> onAccepted(Transaction txn, OutboxOperation op, Map<String, Object?> result) =>
      _local.markAccepted(txn, op.uuid, result['number'] as String?);

  @override
  Future<void> onRejected(Transaction txn, OutboxOperation op) => _local.markRejected(txn, op.uuid);
}

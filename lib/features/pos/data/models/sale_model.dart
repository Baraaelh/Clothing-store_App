import '../../../../core/database/schema.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/entities/sale.dart';

abstract final class SaleModel {
  static Map<String, Object?> toDb(Sale sale) => {
    'id': sale.id,
    'server_id': sale.serverId,
    'branch_id': sale.branchId,
    'cashier_name': sale.cashierName,
    'customer_name': sale.customerName,
    'payment_method': sale.paymentMethod.apiValue,
    'subtotal': sale.subtotal,
    'discount': sale.discount,
    'total': sale.total,
    'amount_paid': sale.amountPaid,
    'created_at': sale.createdAt.toUtc().toIso8601String(),
    'sync_status': syncStatusToDb(sale.syncState),
  };

  static Map<String, Object?> itemToDb(String saleId, SaleItem item) => {
    'sale_id': saleId,
    'variant_id': item.variantId,
    'product_name': item.productName,
    'color_name': item.colorName,
    'size_name': item.sizeName,
    'sku': item.sku,
    'quantity': item.quantity,
    'unit_price': item.unitPrice,
    'line_total': item.lineTotal,
  };

  static Sale fromDb(Map<String, Object?> row, List<Map<String, Object?>> itemRows) => Sale(
    id: row['id']! as String,
    serverId: row['server_id'] as int?,
    branchId: row['branch_id']! as int,
    cashierName: row['cashier_name']! as String,
    customerName: row['customer_name'] as String?,
    paymentMethod: PaymentMethod.fromApi(row['payment_method']! as String),
    subtotal: row['subtotal']! as int,
    discount: row['discount']! as int,
    total: row['total']! as int,
    amountPaid: row['amount_paid']! as int,
    createdAt: DateTime.parse(row['created_at']! as String),
    syncState: syncStateFromDb(row['sync_status']! as String),
    items: itemRows
        .map(
          (r) => SaleItem(
            variantId: r['variant_id']! as int,
            productName: r['product_name']! as String,
            colorName: r['color_name'] as String?,
            sizeName: r['size_name'] as String?,
            sku: r['sku']! as String,
            quantity: r['quantity']! as int,
            unitPrice: r['unit_price']! as int,
          ),
        )
        .toList(),
  );

  /// جسم الطلب المرسل للسيرفر.
  /// TODO(api): طابق أسماء الحقول مع الـ API عند استلامه.
  static Map<String, Object?> toApiPayload(Sale sale) => {
    'client_uuid': sale.id,
    'branch_id': sale.branchId,
    'customer_name': sale.customerName,
    'payment_method': sale.paymentMethod.apiValue,
    'subtotal': Money.toDecimalString(sale.subtotal),
    'discount': Money.toDecimalString(sale.discount),
    'total': Money.toDecimalString(sale.total),
    'amount_paid': Money.toDecimalString(sale.amountPaid),
    'sold_at': sale.createdAt.toUtc().toIso8601String(),
    'items': [
      for (final item in sale.items)
        {
          'product_variant_id': item.variantId,
          'quantity': item.quantity,
          'unit_price': Money.toDecimalString(item.unitPrice),
        },
    ],
  };

  static String syncStatusToDb(SaleSyncState state) => switch (state) {
    SaleSyncState.pending => SyncStatus.pending,
    SaleSyncState.synced => SyncStatus.synced,
    SaleSyncState.failed => SyncStatus.failed,
  };

  static SaleSyncState syncStateFromDb(String value) => switch (value) {
    SyncStatus.synced => SaleSyncState.synced,
    SyncStatus.failed => SaleSyncState.failed,
    _ => SaleSyncState.pending,
  };
}

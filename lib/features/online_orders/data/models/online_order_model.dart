import 'dart:convert';

import '../../../../core/database/schema.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/online_order.dart';

abstract final class OnlineOrderModel {
  static OnlineOrder fromDb(Map<String, Object?> row) => OnlineOrder(
    id: row['id']! as String,
    customerName: row['customer_name']! as String,
    phone: row['phone'] as String?,
    city: row['city'] as String?,
    address: row['address'] as String?,
    notes: row['notes'] as String?,
    total: row['total']! as int,
    status: OnlineOrderStatus.fromApi(row['status']! as String),
    createdAt: DateTime.parse(row['created_at']! as String),
    hasUnsyncedChange: row['sync_status'] != SyncStatus.synced,
    items: [
      for (final i in (jsonDecode(row['items_json']! as String) as List<Object?>).cast<Map<String, Object?>>())
        OnlineOrderItem(
          name: i['name']! as String,
          color: i['color'] as String?,
          size: i['size'] as String?,
          quantity: i['quantity']! as int,
          unitPrice: i['unit_price']! as int,
        ),
    ],
  );

  /// TODO(api): طابق أسماء الحقول مع رد الـ API عند استلامه.
  /// الشكل المفترض مبني على طلبات المتجر الحالية في الواجهة (store_online_orders_v6).
  static Map<String, Object?> dbRowFromJson(Map<String, Object?> json) {
    final items = (json['items'] as List<Object?>? ?? const []).cast<Map<String, Object?>>();
    return {
      'id': '${json['id']}',
      'customer_name': (json['customer_name'] ?? json['customer'] ?? '') as String,
      'phone': json['phone'] as String?,
      'city': json['city'] as String?,
      'address': json['address'] as String?,
      'notes': json['notes'] as String?,
      'items_json': jsonEncode([
        for (final i in items)
          {
            'name': (i['name'] ?? i['product_name'] ?? '') as String,
            'color': i['color'] as String?,
            'size': i['size'] as String?,
            'quantity': (i['quantity'] as num?)?.toInt() ?? 1,
            'unit_price': Money.fromJson(i['unit_price'] ?? i['price']),
          },
      ]),
      'total': Money.fromJson(json['total']),
      'status': (json['status'] ?? OnlineOrderStatus.pending.apiValue) as String,
      'created_at': DateTime.parse((json['created_at'] ?? json['date'])! as String).toUtc().toIso8601String(),
      'sync_status': SyncStatus.synced,
    };
  }
}

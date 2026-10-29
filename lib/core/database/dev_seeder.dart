import 'package:flutter/foundation.dart';

import '../../features/online_orders/data/datasources/online_orders_local_data_source.dart';
import '../../features/online_orders/data/models/online_order_model.dart';
import '../../features/pos/data/datasources/pos_local_data_source.dart';
import '../../features/pos/data/models/catalog_item_model.dart';
import '../config/api_config.dart';

/// بيانات تجريبية لتجربة التطبيق قبل ربط الـ API.
/// تعمل فقط في وضع التطوير، وعندما لا يوجد API مضبوط، وقاعدة البيانات فارغة.
/// تمر عبر نفس `fromJson` الخاصة بالـ API، فهي أيضًا مثال على شكل الرد المتوقع.
class DevSeeder {
  DevSeeder(this._pos, this._orders);

  final PosLocalDataSource _pos;
  final OnlineOrdersLocalDataSource _orders;

  Future<void> seedIfNeeded() async {
    if (!kDebugMode || ApiConfig.isConfigured || !await _pos.isCatalogEmpty()) return;

    final now = DateTime.now().toUtc().toIso8601String();
    await _pos.replaceCatalog([for (final json in _catalog) CatalogItemModel.dbRowFromJson(json, now)]);
    await _orders.upsertFromServer([for (final json in _onlineOrders) OnlineOrderModel.dbRowFromJson(json)]);
  }

  static Map<String, Object?> _variant(
    int id,
    int productId,
    String code,
    String name,
    String category,
    String color,
    String size,
    String price,
    int quantity,
  ) => {
    'id': id,
    'product_id': productId,
    'sku': '$code-${color.hashCode.abs() % 100}-$size',
    'selling_price': price,
    'minimum_selling_price': null,
    'quantity': quantity,
    'product': {
      'id': productId,
      'code': code,
      'name': name,
      'category': {'name': category},
    },
    'color': {'name': color},
    'size': {'name': size},
  };

  static final List<Map<String, Object?>> _catalog = [
    _variant(1, 1, 'TS101', 'قميص أطفال قطن', 'أطفال', 'أبيض', 'M', '25.00', 12),
    _variant(2, 1, 'TS101', 'قميص أطفال قطن', 'أطفال', 'أبيض', 'L', '25.00', 8),
    _variant(3, 1, 'TS101', 'قميص أطفال قطن', 'أطفال', 'أزرق', 'M', '25.00', 3),
    _variant(4, 2, 'DR202', 'فستان بناتي صيفي', 'بناتي', 'وردي', 'S', '35.00', 6),
    _variant(5, 2, 'DR202', 'فستان بناتي صيفي', 'بناتي', 'وردي', 'M', '35.00', 0),
    _variant(6, 3, 'JN303', 'بنطال جينز', 'أولادي', 'أزرق', '32', '60.00', 10),
    _variant(7, 3, 'JN303', 'بنطال جينز', 'أولادي', 'أسود', '34', '60.00', 4),
    _variant(8, 4, 'SW404', 'طقم سويت شيرت شتوي', 'رجالي', 'نبيذي', 'XL', '120.00', 5),
  ];

  static final List<Map<String, Object?>> _onlineOrders = [
    {
      'id': 'WEB-10021',
      'customer_name': 'ريم سعيد',
      'phone': '0599222222',
      'city': 'رام الله',
      'address': 'شارع الإرسال',
      'notes': 'التوصيل بعد العصر',
      'total': '95.00',
      'status': 'pending',
      'created_at': DateTime.now().subtract(const Duration(minutes: 40)).toUtc().toIso8601String(),
      'items': [
        {'name': 'فستان بناتي صيفي', 'color': 'وردي', 'size': 'S', 'quantity': 1, 'unit_price': '35.00'},
        {'name': 'بنطال جينز', 'color': 'أزرق', 'size': '32', 'quantity': 1, 'unit_price': '60.00'},
      ],
    },
    {
      'id': 'WEB-10020',
      'customer_name': 'خالد محمود',
      'phone': '0599111111',
      'city': 'القدس',
      'address': 'شارع صلاح الدين',
      'total': '120.00',
      'status': 'pending',
      'created_at': DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
      'items': [
        {'name': 'طقم سويت شيرت شتوي', 'color': 'نبيذي', 'size': 'XL', 'quantity': 1, 'unit_price': '120.00'},
      ],
    },
    {
      'id': 'WEB-10019',
      'customer_name': 'محمد خليل',
      'phone': '0599333333',
      'city': 'نابلس',
      'total': '50.00',
      'status': 'accepted',
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
      'items': [
        {'name': 'قميص أطفال قطن', 'color': 'أبيض', 'size': 'M', 'quantity': 2, 'unit_price': '25.00'},
      ],
    },
  ];
}

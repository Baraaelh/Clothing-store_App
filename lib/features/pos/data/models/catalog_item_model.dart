import '../../../../core/utils/money.dart';
import '../../domain/entities/catalog_item.dart';

/// تحويل [CatalogItem] من/إلى SQLite والـ API.
abstract final class CatalogItemModel {
  /// صف من SQLite. `available_quantity` محسوب في الاستعلام.
  static CatalogItem fromDb(Map<String, Object?> row) => CatalogItem(
    variantId: row['variant_id']! as int,
    productId: row['product_id']! as int,
    productCode: row['product_code']! as String,
    productName: row['product_name']! as String,
    categoryName: row['category_name'] as String?,
    colorName: row['color_name'] as String?,
    sizeName: row['size_name'] as String?,
    sku: row['sku']! as String,
    sellingPrice: row['selling_price']! as int,
    minimumSellingPrice: row['minimum_selling_price'] as int?,
    availableQuantity: row['available_quantity']! as int,
  );

  /// TODO(api): طابق أسماء الحقول مع رد الـ API عند استلامه.
  /// الشكل المفترض هنا مبني على جداول Laravel الحالية (product_variants + inventories).
  static Map<String, Object?> dbRowFromJson(Map<String, Object?> json, String syncedAt) {
    final product = (json['product'] as Map<String, Object?>?) ?? const {};
    final color = json['color'] as Map<String, Object?>?;
    final size = json['size'] as Map<String, Object?>?;
    final category = product['category'] as Map<String, Object?>?;
    return {
      'variant_id': json['id']! as int,
      'product_id': (json['product_id'] ?? product['id'])! as int,
      'product_code': (product['code'] ?? '') as String,
      'product_name': (product['name'] ?? '') as String,
      'category_name': category?['name'] as String?,
      'color_name': color?['name'] as String?,
      'size_name': size?['name'] as String?,
      'sku': json['sku']! as String,
      'selling_price': Money.fromJson(json['selling_price']),
      'minimum_selling_price': json['minimum_selling_price'] == null
          ? null
          : Money.fromJson(json['minimum_selling_price']),
      'server_quantity': (json['quantity'] as num?)?.toInt() ?? 0,
      'is_active': json['is_active'] == false ? 0 : 1,
      'synced_at': syncedAt,
    };
  }
}

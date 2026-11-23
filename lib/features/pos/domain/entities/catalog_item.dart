import 'package:equatable/equatable.dart';

/// صنف قابل للبيع: منتج بلون ومقاس محددين (product variant في السيرفر).
class CatalogItem extends Equatable {
  const CatalogItem({
    required this.variantId,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.sku,
    required this.sellingPrice,
    required this.availableQuantity,
    this.categoryName,
    this.colorName,
    this.colorHex,
    this.sizeName,
    this.minimumSellingPrice,
  });

  factory CatalogItem.fromDb(Map<String, Object?> row) => CatalogItem(
    variantId: row['variant_id']! as int,
    productId: row['product_id']! as int,
    productCode: (row['product_code'] as String?) ?? '',
    productName: (row['product_name'] as String?) ?? '',
    categoryName: row['category_name'] as String?,
    colorName: row['color_name'] as String?,
    colorHex: row['color_hex'] as String?,
    sizeName: row['size_name'] as String?,
    sku: (row['sku'] as String?) ?? '',
    sellingPrice: row['selling_price']! as int,
    minimumSellingPrice: row['minimum_selling_price'] as int?,
    availableQuantity: (row['available'] as int?) ?? 0,
  );

  final int variantId;
  final int productId;
  final String productCode;
  final String productName;
  final String? categoryName;
  final String? colorName;
  final String? colorHex;
  final String? sizeName;
  final String sku;

  /// بالأغورة.
  final int sellingPrice;

  /// أقل سعر مسموح (بالأغورة). `null` = لا يوجد حد.
  final int? minimumSellingPrice;

  /// المتاح في الفرع حسب آخر مزامنة، بعد خصم مبيعات الجهاز التي لم يؤكدها السيرفر بعد.
  final int availableQuantity;

  bool get isOutOfStock => availableQuantity <= 0;

  String get variantLabel => [colorName, sizeName].whereType<String>().where((s) => s.isNotEmpty).join(' / ');

  @override
  List<Object?> get props => [
    variantId,
    productId,
    productCode,
    productName,
    categoryName,
    colorName,
    colorHex,
    sizeName,
    sku,
    sellingPrice,
    minimumSellingPrice,
    availableQuantity,
  ];
}

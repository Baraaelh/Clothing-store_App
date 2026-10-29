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
    this.sizeName,
    this.minimumSellingPrice,
  });

  final int variantId;
  final int productId;
  final String productCode;
  final String productName;
  final String? categoryName;
  final String? colorName;
  final String? sizeName;
  final String sku;

  /// بالأغورة.
  final int sellingPrice;

  /// أقل سعر مسموح للكاشير (بالأغورة). `null` = لا يوجد حد.
  final int? minimumSellingPrice;

  /// الكمية المتاحة بعد خصم المبيعات المحلية التي لم تُرسل بعد.
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
    sizeName,
    sku,
    sellingPrice,
    minimumSellingPrice,
    availableQuantity,
  ];
}

import 'package:equatable/equatable.dart';

class ProductSummary extends Equatable {
  const ProductSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.variantCount,
    required this.totalAvailable,
    required this.minPrice,
    required this.maxPrice,
    this.categoryName,
  });

  final int id;
  final String code;
  final String name;
  final String? categoryName;
  final bool isActive;
  final int variantCount;
  final int totalAvailable;
  final int minPrice;
  final int maxPrice;

  @override
  List<Object?> get props => [id, code, name, categoryName, isActive, variantCount, totalAvailable, minPrice, maxPrice];
}

class VariantInfo extends Equatable {
  const VariantInfo({
    required this.id,
    required this.colorId,
    required this.sizeId,
    required this.sku,
    required this.price,
    required this.isActive,
    this.colorName,
    this.colorHex,
    this.sizeName,
    this.minPrice,
    this.quantity,
    this.reserved,
    this.available,
    this.averageCost,
  });

  final int id;
  final int colorId;
  final int sizeId;
  final String? colorName;
  final String? colorHex;
  final String? sizeName;
  final String sku;
  final int price;
  final int? minPrice;
  final bool isActive;

  /// null = لا يوجد رصيد لهذا الصنف في الفرع بعد.
  final int? quantity;
  final int? reserved;
  final int? available;

  /// يظهر فقط لمن يملك صلاحية التكلفة.
  final int? averageCost;

  String get label => [colorName, sizeName].whereType<String>().join(' / ');

  @override
  List<Object?> get props => [
    id,
    colorId,
    sizeId,
    sku,
    price,
    minPrice,
    isActive,
    quantity,
    reserved,
    available,
    averageCost,
  ];
}

class ProductDetail extends Equatable {
  const ProductDetail({
    required this.id,
    required this.code,
    required this.name,
    required this.categoryId,
    required this.isActive,
    required this.revision,
    required this.variants,
    this.categoryName,
    this.description,
  });

  final int id;
  final String code;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final String? description;
  final bool isActive;

  /// مراجعة المنتج من السيرفر (تُرسل كـ expected_revision عند التعديل).
  final String? revision;
  final List<VariantInfo> variants;

  @override
  List<Object?> get props => [id, code, name, categoryId, description, isActive, revision, variants];
}

/// صنف في نموذج الإضافة/التعديل.
class VariantDraft extends Equatable {
  const VariantDraft({
    required this.colorId,
    required this.sizeId,
    required this.price,
    this.id,
    this.minPrice,
    this.isActive = true,
  });

  /// null = صنف جديد.
  final int? id;
  final int colorId;
  final int sizeId;
  final int price;
  final int? minPrice;
  final bool isActive;

  @override
  List<Object?> get props => [id, colorId, sizeId, price, minPrice, isActive];
}

class ProductDraft extends Equatable {
  const ProductDraft({
    required this.name,
    required this.categoryId,
    required this.variants,
    this.description,
    this.isActive = true,
  });

  final String name;
  final int? categoryId;
  final String? description;
  final bool isActive;
  final List<VariantDraft> variants;

  @override
  List<Object?> get props => [name, categoryId, description, isActive, variants];
}

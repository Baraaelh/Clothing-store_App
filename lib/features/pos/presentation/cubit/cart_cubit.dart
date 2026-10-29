import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cart_line.dart';
import '../../domain/entities/catalog_item.dart';

class CartState extends Equatable {
  const CartState({this.lines = const [], this.discount = 0, this.message});

  final List<CartLine> lines;
  final int discount;

  /// رسالة لمرة واحدة (مثل "لا توجد كمية كافية").
  final String? message;

  int get subtotal => lines.fold(0, (sum, l) => sum + l.lineTotal);
  int get total => subtotal - discount;
  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);
  bool get isEmpty => lines.isEmpty;

  int quantityOf(int variantId) =>
      lines.where((l) => l.item.variantId == variantId).fold(0, (sum, l) => sum + l.quantity);

  CartState copyWith({List<CartLine>? lines, int? discount, String? message}) =>
      CartState(lines: lines ?? this.lines, discount: discount ?? this.discount, message: message);

  @override
  List<Object?> get props => [lines, discount, message];
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  void add(CatalogItem item) {
    final index = state.lines.indexWhere((l) => l.item.variantId == item.variantId);
    if (index == -1) {
      if (item.isOutOfStock) return _notify('${item.productName}: نفدت الكمية');
      emit(state.copyWith(lines: [...state.lines, CartLine.of(item)]));
    } else {
      setQuantity(item.variantId, state.lines[index].quantity + 1);
    }
  }

  void setQuantity(int variantId, int quantity) {
    final index = state.lines.indexWhere((l) => l.item.variantId == variantId);
    if (index == -1) return;
    if (quantity <= 0) return remove(variantId);
    final line = state.lines[index];
    if (quantity > line.item.availableQuantity) {
      return _notify('المتوفر من ${line.item.productName} ${line.item.availableQuantity} فقط');
    }
    final lines = [...state.lines]..[index] = line.copyWith(quantity: quantity);
    emit(state.copyWith(lines: lines, discount: _clampDiscount(state.discount, lines)));
  }

  void setUnitPrice(int variantId, int unitPrice) {
    final index = state.lines.indexWhere((l) => l.item.variantId == variantId);
    if (index == -1 || unitPrice < 0) return;
    final line = state.lines[index];
    final minimum = line.item.minimumSellingPrice;
    if (minimum != null && unitPrice < minimum) return _notify('السعر أقل من الحد الأدنى المسموح');
    final lines = [...state.lines]..[index] = line.copyWith(unitPrice: unitPrice);
    emit(state.copyWith(lines: lines, discount: _clampDiscount(state.discount, lines)));
  }

  void remove(int variantId) {
    final lines = state.lines.where((l) => l.item.variantId != variantId).toList();
    emit(state.copyWith(lines: lines, discount: _clampDiscount(state.discount, lines)));
  }

  void setDiscount(int discount) => emit(state.copyWith(discount: _clampDiscount(discount, state.lines)));

  /// بعد إعادة تحميل المنتجات: حدّث الكميات المتاحة في السلة.
  void refreshItems(List<CatalogItem> catalog) {
    if (state.isEmpty) return;
    final byId = {for (final item in catalog) item.variantId: item};
    final lines = [
      for (final line in state.lines)
        if (byId[line.item.variantId] case final item?)
          CartLine(item: item, quantity: line.quantity, unitPrice: line.unitPrice),
    ];
    emit(state.copyWith(lines: lines, discount: _clampDiscount(state.discount, lines)));
  }

  void clear() => emit(const CartState());

  void _notify(String message) => emit(state.copyWith(message: message));

  static int _clampDiscount(int discount, List<CartLine> lines) {
    final subtotal = lines.fold(0, (sum, l) => sum + l.lineTotal);
    return discount.clamp(0, subtotal);
  }
}

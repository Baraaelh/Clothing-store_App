import 'package:anaqa_mobile/features/pos/domain/entities/catalog_item.dart';
import 'package:anaqa_mobile/features/pos/presentation/cubit/cart_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogItem item({int id = 1, int available = 2, int price = 2500, int? minimum}) => CatalogItem(
  variantId: id,
  productId: 1,
  productCode: 'P1',
  productName: 'قميص',
  sku: 'SKU-$id',
  sellingPrice: price,
  minimumSellingPrice: minimum,
  availableQuantity: available,
);

void main() {
  blocTest<CartCubit, CartState>(
    'adding the same item increases quantity up to available stock',
    build: CartCubit.new,
    act: (c) => c
      ..add(item())
      ..add(item())
      ..add(item()),
    verify: (c) {
      expect(c.state.itemCount, 2);
      expect(c.state.total, 5000);
      expect(c.state.message, contains('2'));
    },
  );

  blocTest<CartCubit, CartState>(
    'out of stock item is not added',
    build: CartCubit.new,
    act: (c) => c.add(item(available: 0)),
    verify: (c) => expect(c.state.isEmpty, isTrue),
  );

  blocTest<CartCubit, CartState>(
    'discount is clamped to subtotal, also after removing lines',
    build: CartCubit.new,
    act: (c) => c
      ..add(item(id: 1))
      ..add(item(id: 2, price: 1000))
      ..setDiscount(99999)
      ..remove(1),
    verify: (c) {
      expect(c.state.subtotal, 1000);
      expect(c.state.discount, 1000);
      expect(c.state.total, 0);
    },
  );

  blocTest<CartCubit, CartState>(
    'price below minimum is refused',
    build: CartCubit.new,
    act: (c) => c
      ..add(item(minimum: 2000))
      ..setUnitPrice(1, 1500),
    verify: (c) => expect(c.state.lines.single.unitPrice, 2500),
  );

  blocTest<CartCubit, CartState>(
    'refreshItems updates stock info and drops items no longer in the catalog',
    build: CartCubit.new,
    act: (c) => c
      ..add(item(id: 1))
      ..add(item(id: 2))
      ..refreshItems([item(id: 1, available: 9)]),
    verify: (c) {
      expect(c.state.lines.map((l) => l.item.variantId), [1]);
      expect(c.state.lines.single.item.availableQuantity, 9);
    },
  );
}

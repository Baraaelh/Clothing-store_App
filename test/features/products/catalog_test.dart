import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/sync/change_applier.dart';
import 'package:anaqa_mobile/core/sync/outbox.dart';
import 'package:anaqa_mobile/features/inventory/data/stock_entry_data_source.dart';
import 'package:anaqa_mobile/features/inventory/domain/stock_entry.dart';
import 'package:anaqa_mobile/core/data/reference_data.dart';
import 'package:anaqa_mobile/features/products/data/catalog_local_data_source.dart';
import 'package:anaqa_mobile/features/products/domain/product.dart';
import 'package:anaqa_mobile/features/products/presentation/products_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Outbox outbox;
  late CatalogLocalDataSource catalog;

  setUp(() async {
    db = await createTestDatabase();
    outbox = Outbox(db);
    catalog = CatalogLocalDataSource(db, outbox);
    final d = await db.database;
    await d.transaction((txn) => const ChangeApplier().apply(txn, seedChanges()));
  });

  test('product list aggregates variants, prices and availability', () async {
    final p = (await catalog.products()).single;
    expect(p.variantCount, 2);
    expect(p.totalAvailable, 5);
    expect(p.minPrice, 4500);
    final detail = (await catalog.product(5))!;
    expect(detail.revision, 'p5');
    expect(detail.variants.map((v) => v.quantity), [5, null]);
    expect(detail.variants.last.minPrice, 4000);
  });

  test('product.create sends client uuids, decimal prices, and minimum only when allowed', () async {
    const draft = ProductDraft(
      name: 'بنطال',
      categoryId: 1,
      variants: [VariantDraft(colorId: 2, sizeId: 3, price: 8000, minPrice: 7000)],
    );
    final uuid = await catalog.createProduct(testSession, draft, includeMinimum: false);
    final op = (await outbox.find(uuid))!;
    expect(op.type, 'product.create');
    expect(op.payload['client_uuid'], isA<String>());
    final v = (op.payload['variants']! as List).single as Map;
    expect(v['client_uuid'], isA<String>());
    expect(v['selling_price'], '80.00');
    expect(v.containsKey('minimum_selling_price'), isFalse);
  });

  test('product.update sends expected_revision and all variants (existing by id, new by client uuid)', () async {
    final current = (await catalog.product(5))!;
    final draft = ProductDraft(
      name: 'قميص قطن',
      categoryId: 1,
      variants: [
        for (final v in current.variants) VariantDraft(id: v.id, colorId: v.colorId, sizeId: v.sizeId, price: 5000),
        const VariantDraft(colorId: 2, sizeId: 99, price: 5000),
      ],
    );
    final op = (await outbox.find(await catalog.updateProduct(testSession, current, draft, includeMinimum: true)))!;
    expect(op.payload['product_id'], 5);
    expect(op.payload['expected_revision'], 'p5');
    final variants = op.payload['variants']! as List;
    expect(variants.map((v) => (v as Map)['id']), [12, 13, null]);
    expect((variants.last as Map)['client_uuid'], isA<String>());
  });

  test('product form validation', () {
    expect(ProductFormCubit.validate(const ProductDraft(name: '', categoryId: 1, variants: [])), contains('اسم'));
    expect(
      ProductFormCubit.validate(
        const ProductDraft(
          name: 'x',
          categoryId: 1,
          variants: [VariantDraft(colorId: 1, sizeId: 1, price: 100), VariantDraft(colorId: 1, sizeId: 1, price: 100)],
        ),
      ),
      contains('مكررة'),
    );
  });

  test('purchase.create payload with an initial cash payment', () async {
    final variant = (await catalog.variants(productId: 5)).first;
    final draft = StockEntryDraft(
      kind: StockEntryKind.purchase,
      supplier: const Party(id: 4, name: 'مورد'),
      initialPayment: 2000,
      account: const PaymentAccount(id: 9, name: 'درج', type: 'cash'),
      rows: [StockEntryRow(variant: variant, productName: 'قميص', quantity: 4, unitCost: 2000)],
    );
    expect(draft.validate(), isNull);
    final uuid = await StockEntryDataSource(db, outbox).submit(testSession, draft, now: DateTime(2026, 11, 20));
    final op = (await outbox.find(uuid))!;
    expect(op.type, 'purchase.create');
    expect(op.payload, {
      'supplier_id': 4,
      'invoice_date': '2026-11-20',
      'initial_payment': '20.00',
      'payment_method': 'cash',
      'payment_details': {'account_id': 9, 'confirmed': true},
      'rows': [
        {'product_variant_id': 12, 'quantity': 4, 'unit_cost': '20.00'},
      ],
    });
  });
}

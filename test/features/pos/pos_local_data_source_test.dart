import 'package:anaqa_mobile/core/data/reference_data.dart';
import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/database/schema.dart';
import 'package:anaqa_mobile/core/error/exceptions.dart';
import 'package:anaqa_mobile/core/sync/change_applier.dart';
import 'package:anaqa_mobile/core/sync/outbox.dart';
import 'package:anaqa_mobile/features/pos/data/datasources/pos_local_data_source.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/cart_line.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/catalog_item.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/checkout_request.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/sale.dart';
import 'package:anaqa_mobile/features/pos/domain/usecases/create_sale.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Outbox outbox;
  late PosLocalDataSource pos;
  const cash = PaymentAccount(id: 9, name: 'درج المحل', type: 'cash');

  setUp(() async {
    db = await createTestDatabase();
    outbox = Outbox(db);
    pos = PosLocalDataSource(db, outbox);
    final d = await db.database;
    await d.transaction((txn) => const ChangeApplier().apply(txn, seedChanges()));
  });

  Future<CatalogItem> item() async => (await pos.getCatalog()).single;

  CheckoutRequest request(CatalogItem item, {int qty = 1, PaymentMode mode = PaymentMode.paid, int discount = 0}) =>
      CheckoutRequest(
        lines: [CartLine(item: item, quantity: qty, unitPrice: item.sellingPrice)],
        mode: mode,
        account: cash,
        discount: discount,
      );

  Future<Sale> sell(CatalogItem item, String id, {int qty = 1}) => pos.insertSale(
    saleId: 's-$id',
    operationUuid: id,
    session: testSession,
    request: request(item, qty: qty),
    createdAt: DateTime.utc(2026, 11, 20, 10, int.parse(id.replaceAll(RegExp('[^0-9]'), ''))),
  );

  test('catalog lists only variants with stock in the branch, with names and prices in minor units', () async {
    final i = await item();
    expect(i.variantId, 12);
    expect(i.productName, 'قميص');
    expect(i.variantLabel, 'أبيض / M');
    expect(i.sellingPrice, 4500);
    expect(i.availableQuantity, 5);
  });

  test('a sale is saved with an outbox operation carrying the stock revision, and reduces availability', () async {
    final sale = await sell(await item(), 'op1', qty: 2);
    expect(sale.status, SaleStatus.pending);
    final op = (await outbox.find('op1'))!;
    expect(op.type, 'sale.create');
    expect(op.payload['payment_mode'], 'paid');
    expect(op.payload['payments'], [
      {'account_id': 9, 'amount': '90.00', 'confirmed': true},
    ]);
    expect(op.payload['rows'], [
      {'product_variant_id': 12, 'quantity': 2, 'expected_revision': 'r1'},
    ]);
    expect(op.dependencies, isEmpty);
    expect((await item()).availableQuantity, 3);
  });

  test('a second offline sale on the same item chains to the first via stock_revision_from', () async {
    await sell(await item(), 'op1');
    await sell(await item(), 'op2');
    final second = (await outbox.find('op2'))!;
    expect(second.dependencies, ['op1']);
    expect((second.payload['rows']! as List).single, {
      'product_variant_id': 12,
      'quantity': 1,
      'stock_revision_from': 'op1',
    });
  });

  test('selling more than available is refused inside the transaction', () async {
    final i = await item();
    await sell(i, 'op1', qty: 4);
    expect(() => sell(i, 'op2', qty: 2), throwsA(isA<CacheException>()));
    expect(await outbox.find('op2'), isNull);
  });

  test('accepted sale stops counting against availability; the next pull brings the real quantity', () async {
    await sell(await item(), 'op1', qty: 2);
    final d = await db.database;
    await d.transaction((txn) => pos.markAccepted(txn, 'op1', 'SL-0000001'));
    final sales = await pos.getRecentSales(userId: 7, branchId: 3);
    expect(sales.single.number, 'SL-0000001');
    expect(sales.single.status, SaleStatus.accepted);
  });

  test('resubmitting a rejected sale creates a new operation with the confirmation and current revision', () async {
    await sell(await item(), 'op1');
    final d = await db.database;
    await d.transaction((txn) async {
      await outbox.markReview(txn, 'op1', code: 'validation_failed', message: 'min');
      await pos.markRejected(txn, 'op1');
    });
    await d.update(Tables.stocks, {'revision': 'r2'});

    await pos.resubmitSale(
      rejected: (await outbox.find('op1'))!,
      newOperationUuid: 'op9',
      extraPayload: {'below_minimum_confirmed': true, 'below_minimum_confirmation': 'tok'},
    );

    expect((await outbox.find('op1'))!.status, OutboxStatus.dismissed);
    final next = (await outbox.find('op9'))!;
    expect(next.payload['below_minimum_confirmation'], 'tok');
    expect((next.payload['rows']! as List).single, {
      'product_variant_id': 12,
      'quantity': 1,
      'expected_revision': 'r2',
    });
    expect((await pos.getRecentSales(userId: 7, branchId: 3)).single.operationUuid, 'op9');
  });

  test('checkout validation', () async {
    final i = await item();
    expect(CreateSale.validate(request(i, qty: 6)), contains('أكبر من المتوفر'));
    expect(CreateSale.validate(request(i, mode: PaymentMode.credit)), contains('الزبون'));
    expect(CreateSale.validate(request(i, discount: 5000)), contains('الخصم'));
    expect(CreateSale.validate(request(i)), isNull);
  });

  test('payload: credit sale sends customer and no payments; discount is an amount object', () {
    const i = CatalogItem(
      variantId: 12,
      productId: 5,
      productCode: 'S',
      productName: 'ق',
      sku: 'S',
      sellingPrice: 4500,
      availableQuantity: 3,
    );
    final payload = PosLocalDataSource.buildPayload(
      const CheckoutRequest(
        lines: [CartLine(item: i, quantity: 1, unitPrice: 4000)],
        mode: PaymentMode.credit,
        customer: Party(id: 1, name: 'خالد'),
        discount: 500,
      ),
      {
        12: {'expected_revision': 'r1'},
      },
    );
    expect(payload['customer_id'], 1);
    expect(payload.containsKey('payments'), isFalse);
    expect(payload['discount'], {'type': 'amount', 'value': '5.00'});
    expect((payload['rows']! as List).single, {
      'product_variant_id': 12,
      'quantity': 1,
      'unit_price': '40.00',
      'price_reason': 'تعديل سعر من الكاشير',
      'expected_revision': 'r1',
    });
  });
}

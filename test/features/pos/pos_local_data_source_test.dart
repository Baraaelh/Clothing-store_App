import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/error/failures.dart';
import 'package:anaqa_mobile/core/sync/sync_queue.dart';
import 'package:anaqa_mobile/core/utils/result.dart';
import 'package:anaqa_mobile/features/pos/data/datasources/pos_local_data_source.dart';
import 'package:anaqa_mobile/features/pos/data/repositories/pos_repository_impl.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/cart_line.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/catalog_item.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/checkout_request.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/payment_method.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/sale.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncQueue queue;
  late PosLocalDataSource local;
  late PosRepositoryImpl repository;

  setUp(() async {
    db = await createTestDatabase();
    queue = SyncQueue(db);
    local = PosLocalDataSource(db, queue);
    repository = PosRepositoryImpl(local, await sessionManagerWith(testSession));
    await local.replaceCatalog([catalogRow(variantId: 1, quantity: 5), catalogRow(variantId: 2, quantity: 2)]);
  });

  tearDown(() => db.close());

  Future<CatalogItem> item(int variantId) async =>
      (await local.getCatalog()).firstWhere((i) => i.variantId == variantId);

  Future<Result<Sale>> sell(CatalogItem item, int quantity) => repository.createSale(
    CheckoutRequest(
      lines: [CartLine(item: item, quantity: quantity, unitPrice: item.sellingPrice)],
      paymentMethod: PaymentMethod.cash,
      amountPaid: item.sellingPrice * quantity,
    ),
  );

  test('sale is saved locally, queued for sync, and reduces available stock', () async {
    final result = await sell(await item(1), 3);

    final sale = (result as Ok<Sale>).value;
    expect(sale.branchId, 3);
    expect(sale.cashierName, 'سارة');
    expect(sale.total, 7500);
    expect(sale.syncState, SaleSyncState.pending);
    expect((await item(1)).availableQuantity, 2);

    final ops = await queue.pending();
    expect(ops, hasLength(1));
    expect(ops.single.operation, createSaleOperation);
    expect(ops.single.entityId, sale.id);
    expect(ops.single.payload['client_uuid'], sale.id);
    expect(ops.single.payload['total'], '75.00');
  });

  test('selling more than available is rejected and nothing is saved or queued', () async {
    final stale = await item(2); // available 2
    await sell(stale, 2);

    final result = await sell(stale, 1); // the cart still thinks 2 are available

    expect((result as Err<Sale>).failure, isA<ValidationFailure>());
    expect((await local.getRecentSales()), hasLength(1));
    expect(await queue.pending(), hasLength(1));
  });

  test('catalog refresh from server keeps unsynced local sales deducted', () async {
    await sell(await item(1), 2);

    // السيرفر لم يستلم الفاتورة بعد، فما زال يرى 5.
    await local.replaceCatalog([catalogRow(variantId: 1, quantity: 5), catalogRow(variantId: 2, quantity: 2)]);

    expect((await item(1)).availableQuantity, 3);
  });

  test('confirmed sale is deducted from server quantity so stock does not bounce back', () async {
    final sale = ((await sell(await item(1), 2)) as Ok<Sale>).value;

    await local.markSaleSynced(sale.id, 99);
    await local.markSaleSynced(sale.id, 99); // idempotent

    expect((await item(1)).availableQuantity, 3);
    final saved = (await local.getRecentSales()).single;
    expect(saved.serverId, 99);
    expect(saved.syncState, SaleSyncState.synced);
  });

  test('variants missing from the server response are deactivated, not deleted', () async {
    await local.replaceCatalog([catalogRow(variantId: 1)]);

    expect((await local.getCatalog()).map((i) => i.variantId), [1]);
  });

  test('search matches name and sku', () async {
    await local.replaceCatalog([catalogRow(variantId: 1, name: 'فستان'), catalogRow(variantId: 2, name: 'جينز')]);

    expect((await local.getCatalog(query: 'جينز')).map((i) => i.variantId), [2]);
    expect((await local.getCatalog(query: 'SKU-1')).map((i) => i.variantId), [1]);
  });
}

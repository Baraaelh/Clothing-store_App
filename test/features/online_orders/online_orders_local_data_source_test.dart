import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/error/exceptions.dart';
import 'package:anaqa_mobile/core/sync/sync_queue.dart';
import 'package:anaqa_mobile/features/online_orders/data/datasources/online_orders_local_data_source.dart';
import 'package:anaqa_mobile/features/online_orders/data/models/online_order_model.dart';
import 'package:anaqa_mobile/features/online_orders/domain/entities/online_order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

Map<String, Object?> orderJson(String id, {String status = 'pending'}) => {
  'id': id,
  'customer_name': 'ريم',
  'phone': '0599',
  'total': '95.50',
  'status': status,
  'created_at': '2026-10-20T10:00:00Z',
  'items': [
    {'name': 'فستان', 'size': 'S', 'quantity': 2, 'unit_price': '47.75'},
  ],
};

void main() {
  late AppDatabase db;
  late SyncQueue queue;
  late OnlineOrdersLocalDataSource local;

  setUp(() async {
    db = await createTestDatabase();
    queue = SyncQueue(db);
    local = OnlineOrdersLocalDataSource(db, queue);
    await local.upsertFromServer([OnlineOrderModel.dbRowFromJson(orderJson('WEB-1'))]);
  });

  tearDown(() => db.close());

  test('maps server json to entity (money in minor units)', () async {
    final order = (await local.getOrders()).single;
    expect(order.total, 9550);
    expect(order.items.single.lineTotal, 9550);
    expect(order.status, OnlineOrderStatus.pending);
    expect(order.hasUnsyncedChange, isFalse);
  });

  test('accepting an order updates it locally and queues the change', () async {
    final order = await local.updateStatus('WEB-1', OnlineOrderStatus.accepted);

    expect(order.status, OnlineOrderStatus.accepted);
    expect(order.hasUnsyncedChange, isTrue);
    final op = (await queue.pending()).single;
    expect(op.operation, updateOrderStatusOperation);
    expect(op.payload, {'order_id': 'WEB-1', 'status': 'accepted'});
  });

  test('an order that is no longer pending cannot change status', () async {
    await local.updateStatus('WEB-1', OnlineOrderStatus.rejected);

    expect(() => local.updateStatus('WEB-1', OnlineOrderStatus.accepted), throwsA(isA<CacheException>()));
    expect(await queue.pending(), hasLength(1));
  });

  test('server refresh does not overwrite a local change that was not sent yet', () async {
    await local.updateStatus('WEB-1', OnlineOrderStatus.accepted);

    await local.upsertFromServer([
      OnlineOrderModel.dbRowFromJson(orderJson('WEB-1')), // السيرفر ما زال يراه معلقًا
      OnlineOrderModel.dbRowFromJson(orderJson('WEB-2')),
    ]);

    final orders = {for (final o in await local.getOrders()) o.id: o};
    expect(orders['WEB-1']!.status, OnlineOrderStatus.accepted);
    expect(orders['WEB-2']!.status, OnlineOrderStatus.pending);
  });

  test('permanent server rejection reverts the order to pending', () async {
    await local.updateStatus('WEB-1', OnlineOrderStatus.accepted);
    await local.revertStatus('WEB-1');

    final order = (await local.getOrders()).single;
    expect(order.status, OnlineOrderStatus.pending);
    expect(order.hasUnsyncedChange, isFalse);
  });
}

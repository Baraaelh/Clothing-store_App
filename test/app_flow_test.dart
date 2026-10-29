import 'dart:async';

import 'package:anaqa_mobile/app/app.dart';
import 'package:anaqa_mobile/core/config/app_settings.dart';
import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/di/injection.dart';
import 'package:anaqa_mobile/core/network/network_info.dart';
import 'package:anaqa_mobile/core/sync/sync_queue.dart';
import 'package:anaqa_mobile/features/online_orders/data/datasources/online_orders_local_data_source.dart';
import 'package:anaqa_mobile/features/online_orders/data/models/online_order_model.dart';
import 'package:anaqa_mobile/features/pos/data/datasources/pos_local_data_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

class OfflineNetwork implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;

  @override
  Stream<bool> get onStatusChange => const Stream.empty();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await createTestDatabase();
    await sl.reset();
    await configureDependencies(
      settings: const AppSettings(branchId: 1, cashierName: 'test'),
      database: db,
    );
    sl
      ..unregister<NetworkInfo>()
      ..registerSingleton<NetworkInfo>(OfflineNetwork());
    await sl<PosLocalDataSource>().replaceCatalog([catalogRow(variantId: 1, quantity: 2, name: 'قميص أبيض')]);
    await sl<OnlineOrdersLocalDataSource>().upsertFromServer([
      OnlineOrderModel.dbRowFromJson({
        'id': 'WEB-7',
        'customer_name': 'ريم',
        'total': '35.00',
        'status': 'pending',
        'created_at': '2026-10-20T10:00:00Z',
        'items': [
          {'name': 'فستان', 'quantity': 1, 'unit_price': '35.00'},
        ],
      }),
    ]);
  });

  tearDown(() async {
    await sl.reset();
    await db.close();
  });

  /// sqflite ffi يعمل على isolate حقيقي: نعطيه وقتًا ثم نرسم.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('offline sale: add to cart, checkout, stock drops, sale is queued', (tester) async {
    await tester.pumpWidget(const AnaqaApp());
    await settle(tester);

    expect(find.text('قميص أبيض'), findsOneWidget);
    expect(find.text('متوفر: 2'), findsOneWidget);

    await tester.tap(find.text('قميص أبيض'));
    await tester.pump();
    await tester.tap(find.text('عرض السلة'));
    await settle(tester);
    await tester.tap(find.text('إتمام البيع'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'المبلغ المستلم (₪)'), '30');
    await tester.pump();
    expect(find.text('الباقي للزبون'), findsOneWidget);

    await tester.tap(find.text('تأكيد البيع'));
    await settle(tester);

    expect(find.textContaining('تم حفظ الفاتورة'), findsOneWidget);
    expect(find.text('متوفر: 1'), findsOneWidget);
    expect(find.text('عرض السلة'), findsNothing, reason: 'cart cleared and sheets closed');

    final counts = (await tester.runAsync(() => sl<SyncQueue>().counts()))!;
    expect(counts.pending, 1);
  });

  testWidgets('accept online order offline: status changes locally and is queued', (tester) async {
    await tester.pumpWidget(const AnaqaApp());
    await settle(tester);

    await tester.tap(find.text('طلبات الموقع').last);
    await settle(tester);
    expect(find.text('ريم'), findsOneWidget);

    await tester.tap(find.text('ريم'));
    await settle(tester);
    await tester.tap(find.text('قبول'));
    await settle(tester);

    expect(find.text('تم قبول الطلب'), findsOneWidget);
    expect(find.text('ريم'), findsNothing, reason: 'no longer in the pending filter');

    final orders = (await tester.runAsync(() => sl<OnlineOrdersLocalDataSource>().getOrders()))!;
    expect(orders.single.hasUnsyncedChange, isTrue);
  });
}

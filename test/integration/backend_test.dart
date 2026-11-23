// اختبار تكامل مع باك اند appStore حقيقي (Laravel + MySQL بمزامنة مفعلة).
// لا يعمل إلا عند تمرير العنوان وحساب تجريبي:
//   flutter test test/integration --dart-define=BACKEND_URL=http://127.0.0.1:8000/api/v1 \
//     --dart-define=BACKEND_USER=owner --dart-define=BACKEND_PASSWORD=...
// يحتاج فرعًا البيع فيه مسموح، وفيه حساب قبض ومورد ومنتج واحد على الأقل بكمية.
import 'package:anaqa_mobile/core/config/app_settings.dart';
import 'package:anaqa_mobile/core/data/reference_data.dart';
import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/database/schema.dart';
import 'package:anaqa_mobile/core/network/api_client.dart';
import 'package:anaqa_mobile/core/session/session_manager.dart';
import 'package:anaqa_mobile/core/sync/outbox.dart';
import 'package:anaqa_mobile/core/sync/sync_engine.dart';
import 'package:anaqa_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:anaqa_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:anaqa_mobile/features/inventory/data/stock_entry_data_source.dart';
import 'package:anaqa_mobile/features/inventory/domain/stock_entry.dart';
import 'package:anaqa_mobile/features/pos/data/datasources/pos_local_data_source.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/cart_line.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/checkout_request.dart';
import 'package:anaqa_mobile/features/pos/domain/entities/sale.dart';
import 'package:anaqa_mobile/features/products/data/catalog_local_data_source.dart';
import 'package:anaqa_mobile/features/products/domain/product.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

const backend = String.fromEnvironment('BACKEND_URL');
const user = String.fromEnvironment('BACKEND_USER');
const password = String.fromEnvironment('BACKEND_PASSWORD');

void main() {
  late AppDatabase db;
  late SessionManager session;
  late Outbox outbox;
  late SyncEngine engine;
  late PosLocalDataSource pos;
  late CatalogLocalDataSource catalog;
  late ReferenceData reference;
  late AuthRepositoryImpl auth;

  setUpAll(() async {
    db = await createTestDatabase();
    session = SessionManager(InMemorySessionStorage());
    outbox = Outbox(db);
    final api = ApiClient(baseUrl: backend, tokenProvider: () async => session.current?.token);
    pos = PosLocalDataSource(db, outbox);
    catalog = CatalogLocalDataSource(db, outbox);
    reference = ReferenceData(db);
    engine = SyncEngine(api: api, database: db, outbox: outbox, session: session, handlers: [SaleOperationHandler(pos)]);
    auth = AuthRepositoryImpl(remote: AuthRemoteDataSource(api), session: session, settings: const AppSettings(), sync: engine);
  });

  group('appStore API v1', skip: backend.isEmpty ? 'BACKEND_URL not set' : null, () {
    test('wrong password is refused with a clear message', () async {
      final result = await auth.login(username: user, password: '${password}x');
      expect(result.fold((f) => f.message, (_) => ''), isNotEmpty);
      expect(session.current, isNull);
    });

    test('login registers the device and returns permissions and branches', () async {
      final result = await auth.login(username: user, password: password);
      final s = result.fold((f) => fail(f.message), (s) => s);
      expect(s.token, isNotEmpty);
      expect(s.canSell, isTrue);
      expect(s.branches, isNotEmpty);
      // نفس UUID الجهاز يُستخدم في الدخول التالي لهذا الحساب.
      expect(await session.storage.deviceIdFor(user), s.deviceId);
    });

    test('bootstrap downloads the branch catalog, stock and accounts', () async {
      final report = (await engine.run())!;
      expect(report.stopped, isFalse, reason: report.error);
      expect(await engine.initialSyncCompleted, isTrue);
      expect(await pos.getCatalog(), isNotEmpty);
      expect(await reference.accounts(), isNotEmpty);
      expect((await engine.operationState())?['sales_allowed'], isTrue);
    });

    test('two offline sales on the same item are accepted in order and quantities update after pull', () async {
      final item = (await pos.getCatalog()).firstWhere((i) => i.availableQuantity >= 2);
      final account = (await reference.accounts()).first;
      final before = item.availableQuantity;
      for (final id in ['a', 'b']) {
        await pos.insertSale(
          saleId: 'sale-$id-${DateTime.now().microsecondsSinceEpoch}',
          operationUuid: outbox.newUuid(),
          session: session.requireSession,
          request: CheckoutRequest(
            lines: [CartLine(item: item, quantity: 1, unitPrice: item.sellingPrice)],
            mode: PaymentMode.paid,
            account: account,
          ),
          createdAt: DateTime.now(),
        );
      }
      expect((await pos.getCatalog()).firstWhere((i) => i.variantId == item.variantId).availableQuantity, before - 2);

      final report = (await engine.run())!;
      expect(report.accepted, 2, reason: report.error);
      expect(report.rejected, 0);

      final sales = await pos.getRecentSales(userId: session.requireSession.userId, branchId: session.requireSession.branchId);
      expect(sales.take(2).every((s) => s.status == SaleStatus.accepted && (s.number?.isNotEmpty ?? false)), isTrue);
      // بعد الـ Pull: كمية السيرفر الحقيقية، بلا خصم محلي مزدوج.
      expect((await pos.getCatalog()).firstWhere((i) => i.variantId == item.variantId).availableQuantity, before - 2);
    });

    test('resending an accepted operation returns already_applied without a second sale', () async {
      final d = await db.database;
      final accepted = (await d.query(Tables.outbox, where: "status = 'accepted' AND operation_type = 'sale.create'", limit: 1)).single;
      await d.update(Tables.outbox, {'status': OutboxStatus.pending}, where: 'seq = ?', whereArgs: [accepted['seq']]);
      final report = await engine.push();
      expect(report.accepted, 1);
      expect(report.rejected, 0);
    });

    test('a stale stock revision is rejected for review instead of overselling', () async {
      final item = (await pos.getCatalog()).firstWhere((i) => i.availableQuantity >= 1);
      final d = await db.database;
      await d.update(Tables.stocks, {'revision': '0' * 64}, where: 'variant_id = ?', whereArgs: [item.variantId]);
      await pos.insertSale(
        saleId: 'stale-${DateTime.now().microsecondsSinceEpoch}',
        operationUuid: outbox.newUuid(),
        session: session.requireSession,
        request: CheckoutRequest(
          lines: [CartLine(item: item, quantity: 1, unitPrice: item.sellingPrice)],
          mode: PaymentMode.paid,
          account: (await reference.accounts()).first,
        ),
        createdAt: DateTime.now(),
      );
      final report = await engine.push();
      expect(report.rejected, 1);
      final review = await outbox.list(statuses: [OutboxStatus.review]);
      expect(review.first.errorCode, 'conflict_requires_review');
      await engine.pull(); // يعيد المراجعة الحقيقية
    });

    test('a product created on the phone is accepted and appears after pull; purchase adds its stock', () async {
      final colors = await reference.colors();
      final sizes = await reference.sizes();
      final categories = await reference.categories();
      final name = 'منتج من الجوال ${DateTime.now().millisecondsSinceEpoch}';
      await catalog.createProduct(
        session.requireSession,
        ProductDraft(
          name: name,
          categoryId: categories.first.id,
          variants: [VariantDraft(colorId: colors.first.id, sizeId: sizes.first.id, price: 6000)],
        ),
        includeMinimum: false,
      );
      var report = (await engine.run())!;
      expect(report.accepted, 1, reason: report.error);
      final product = (await catalog.products(query: name)).single;
      final variant = (await catalog.variants(productId: product.id)).single;
      expect(variant.sku, isNotEmpty);
      expect(variant.quantity, isNull); // لا رصيد قبل الشراء

      final supplier = (await reference.suppliers()).first;
      await StockEntryDataSource(db, outbox).submit(
        session.requireSession,
        StockEntryDraft(
          kind: StockEntryKind.purchase,
          supplier: supplier,
          rows: [StockEntryRow(variant: variant, productName: name, quantity: 4, unitCost: 2500)],
        ),
      );
      report = (await engine.run())!;
      expect(report.accepted, 1, reason: report.error);
      final stocked = (await catalog.variants(productId: product.id)).single;
      expect(stocked.quantity, 4);
      expect(stocked.available, 4);
    });

    test('editing a product with an old revision is rejected as a conflict', () async {
      final product = (await catalog.products()).first;
      final detail = (await catalog.product(product.id))!;
      final stale = ProductDetail(
        id: detail.id,
        code: detail.code,
        name: detail.name,
        categoryId: detail.categoryId,
        isActive: detail.isActive,
        revision: '0' * 64,
        variants: detail.variants,
      );
      await catalog.updateProduct(
        session.requireSession,
        stale,
        ProductDraft(
          name: '${detail.name} *',
          categoryId: detail.categoryId,
          variants: [for (final v in detail.variants) VariantDraft(id: v.id, colorId: v.colorId, sizeId: v.sizeId, price: v.price)],
        ),
        includeMinimum: false,
      );
      final report = await engine.push();
      expect(report.rejected, 1);
    });

    test('logout revokes the token and clears the read cache', () async {
      await auth.logout();
      expect(session.current, isNull);
      final d = await db.database;
      expect(await d.query(Tables.variants), isEmpty);
      expect(await d.query(Tables.outbox), isNotEmpty); // العمليات لا تُحذف
    });
  });
}

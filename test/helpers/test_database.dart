import 'dart:io';

import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/session/session.dart';
import 'package:anaqa_mobile/core/session/session_manager.dart';
import 'package:anaqa_mobile/core/session/session_storage.dart';
import 'package:anaqa_mobile/features/pos/data/models/catalog_item_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// قاعدة SQLite حقيقية في ملف مؤقت لكل اختبار.
Future<AppDatabase> createTestDatabase() async {
  sqfliteFfiInit();
  final dir = await Directory.systemTemp.createTemp('anaqa_test_');
  return AppDatabase(factory: databaseFactoryFfi, path: '${dir.path}/test.db');
}

Map<String, Object?> catalogRow({
  required int variantId,
  int quantity = 10,
  String price = '25.00',
  String? minimum,
  String name = 'قميص',
}) => CatalogItemModel.dbRowFromJson({
  'id': variantId,
  'product_id': 1,
  'sku': 'SKU-$variantId',
  'selling_price': price,
  'minimum_selling_price': minimum,
  'quantity': quantity,
  'product': {'id': 1, 'code': 'P1', 'name': name},
  'color': {'name': 'أبيض'},
  'size': {'name': 'M'},
}, DateTime.utc(2026).toIso8601String());

/// تخزين جلسة في الذاكرة بدل التخزين الآمن (لا platform channels في الاختبارات).
class InMemorySessionStorage implements SessionStorage {
  InMemorySessionStorage([this.session]) : _lastBranch = session?.branchId;

  Session? session;
  int? _lastBranch;

  @override
  Future<Session?> read() async => session;

  @override
  Future<void> write(Session value) async {
    session = value;
    _lastBranch = value.branchId;
  }

  @override
  Future<void> clear() async => session = null;

  @override
  Future<int?> lastBranchId() async => _lastBranch;
}

const testSession = Session(token: 't', userId: 7, userName: 'سارة', role: UserRole.cashier, branchId: 3);

Future<SessionManager> sessionManagerWith(Session? session) async {
  final manager = SessionManager(InMemorySessionStorage(session));
  await manager.restore();
  return manager;
}

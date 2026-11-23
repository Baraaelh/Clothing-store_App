import 'dart:io';

import 'package:anaqa_mobile/core/database/app_database.dart';
import 'package:anaqa_mobile/core/session/session.dart';
import 'package:anaqa_mobile/core/session/session_manager.dart';
import 'package:anaqa_mobile/core/session/session_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// قاعدة SQLite حقيقية في ملف مؤقت لكل اختبار.
Future<AppDatabase> createTestDatabase() async {
  sqfliteFfiInit();
  final dir = await Directory.systemTemp.createTemp('anaqa_test_');
  return AppDatabase(factory: databaseFactoryFfi, path: '${dir.path}/test.db');
}

/// تخزين جلسة في الذاكرة بدل التخزين الآمن (لا platform channels في الاختبارات).
class InMemorySessionStorage implements SessionStorage {
  InMemorySessionStorage([this.session]) : _scope = session == null ? null : scopeOf(session);

  Session? session;
  String? _scope;
  final Map<String, String> devices = {};

  @override
  Future<Session?> read() async => session;

  @override
  Future<void> write(Session value) async {
    session = value;
    _scope = scopeOf(value);
  }

  @override
  Future<void> clear() async => session = null;

  @override
  Future<String?> lastScope() async => _scope;

  @override
  Future<String?> deviceIdFor(String username) async => devices[username.toLowerCase()];

  @override
  Future<void> saveDeviceId(String username, String deviceId) async => devices[username.toLowerCase()] = deviceId;
}

const allPermissions = {
  Permissions.catalogSearch,
  Permissions.inventoryView,
  Permissions.manageCatalog,
  Permissions.sell,
  Permissions.salesView,
  Permissions.customers,
  Permissions.viewCost,
  Permissions.purchasesView,
  Permissions.purchasesManage,
  Permissions.purchasePost,
};

const testSession = Session(
  token: 't',
  deviceId: 'ad63c818-a2b5-433d-aea6-df46479571b1',
  userId: 7,
  userName: 'سارة',
  username: 'sara',
  role: 'sales_owner',
  permissions: allPermissions,
  branches: [Branch(id: 3, name: 'الرئيسي')],
  branchId: 3,
);

Future<SessionManager> sessionManagerWith(Session? session) async {
  final manager = SessionManager(InMemorySessionStorage(session));
  await manager.restore();
  return manager;
}

/// صفحة تغييرات بشكل رد السيرفر.
Map<String, Object?> change(String entity, int id, Map<String, Object?>? data) => {
  'entity': entity,
  'id': id,
  'action': data == null ? 'delete' : 'upsert',
  'data': data,
};

/// تغييرات تبني فرعًا فيه منتج بصنفين ومخزون وحساب نقدي.
List<Map<String, Object?>> seedChanges({int qty = 5, String rev = 'r1'}) => [
  change('categories', 1, {'id': 1, 'name': 'رجالي', 'is_active': true}),
  change('colors', 2, {'id': 2, 'name': 'أبيض', 'code': 'WHT', 'hex': '#ffffff', 'is_active': true}),
  change('sizes', 3, {'id': 3, 'name': 'M', 'code': 'M', 'sort_order': 1, 'is_active': true}),
  change('sizes', 4, {'id': 4, 'name': 'L', 'code': 'L', 'sort_order': 2, 'is_active': true}),
  change('products', 5, {
    'id': 5,
    'code': 'SHIRT',
    'name': 'قميص',
    'category_id': 1,
    'is_active': true,
    'revision': 'p5',
  }),
  change('variants', 12, {
    'id': 12,
    'product_id': 5,
    'color_id': 2,
    'size_id': 3,
    'sku': 'SHIRT-WHT-M',
    'selling_price': '45.00',
    'minimum_selling_price': null,
    'is_active': true,
    'revision': 'v12',
  }),
  change('variants', 13, {
    'id': 13,
    'product_id': 5,
    'color_id': 2,
    'size_id': 4,
    'sku': 'SHIRT-WHT-L',
    'selling_price': '45.00',
    'minimum_selling_price': '40.00',
    'is_active': true,
    'revision': 'v13',
  }),
  change('stocks', 100, {
    'id': 100,
    'branch_id': 3,
    'product_variant_id': 12,
    'quantity': qty,
    'reserved_quantity': 0,
    'available_quantity': qty,
    'average_cost': '20.00',
    'revision': rev,
  }),
  change('accounts', 9, {'id': 9, 'branch_id': 3, 'name': 'درج المحل', 'type': 'cash', 'is_active': true}),
  change('customers', 1, {'id': 1, 'name': 'خالد', 'phone': '0599'}),
];

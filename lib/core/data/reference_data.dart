import 'package:equatable/equatable.dart';

import '../database/app_database.dart';
import '../database/schema.dart';

/// حساب قبض/دفع في الفرع (درج، بنك، محفظة).
class PaymentAccount extends Equatable {
  const PaymentAccount({required this.id, required this.name, required this.type});

  final int id;
  final String name;

  /// cash / bank / wallet / other.
  final String type;

  String get typeLabel => switch (type) {
    'cash' => 'نقدي',
    'bank' => 'بنك',
    'wallet' => 'محفظة',
    _ => 'أخرى',
  };

  @override
  List<Object?> get props => [id, name, type];
}

class Party extends Equatable {
  const Party({required this.id, required this.name, this.phone});

  final int id;
  final String name;
  final String? phone;

  @override
  List<Object?> get props => [id, name, phone];
}

class NamedRef extends Equatable {
  const NamedRef({required this.id, required this.name, this.code, this.hex});

  final int id;
  final String name;
  final String? code;
  final String? hex;

  @override
  List<Object?> get props => [id, name, code, hex];
}

/// قراءة البيانات المرجعية من الـ Cache (تعمل بدون إنترنت).
class ReferenceData {
  ReferenceData(this._appDb);

  final AppDatabase _appDb;

  Future<List<PaymentAccount>> accounts() async {
    final db = await _appDb.database;
    final rows = await db.query(Tables.accounts, where: 'is_active = 1', orderBy: "type = 'cash' DESC, name");
    return [
      for (final r in rows) PaymentAccount(id: r['id']! as int, name: r['name']! as String, type: r['type']! as String),
    ];
  }

  Future<List<Party>> customers({String query = ''}) => _parties(Tables.customers, query);

  Future<List<Party>> suppliers({String query = ''}) => _parties(Tables.suppliers, query);

  Future<List<NamedRef>> categories() => _named(Tables.categories, orderBy: 'name');

  Future<List<NamedRef>> colors() => _named(Tables.colors, orderBy: 'name');

  Future<List<NamedRef>> sizes() => _named(Tables.sizes, orderBy: 'sort_order, name');

  Future<List<Party>> _parties(String table, String query) async {
    final db = await _appDb.database;
    final q = query.trim();
    final rows = await db.query(
      table,
      where: q.isEmpty ? null : 'name LIKE ? OR phone LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
      orderBy: 'name',
      limit: 50,
    );
    return [for (final r in rows) Party(id: r['id']! as int, name: r['name']! as String, phone: r['phone'] as String?)];
  }

  Future<List<NamedRef>> _named(String table, {required String orderBy}) async {
    final db = await _appDb.database;
    final rows = await db.query(table, where: 'is_active = 1', orderBy: orderBy);
    return [
      for (final r in rows)
        NamedRef(id: r['id']! as int, name: r['name']! as String, code: r['code'] as String?, hex: r['hex'] as String?),
    ];
  }
}

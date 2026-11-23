import 'package:equatable/equatable.dart';

/// فرع مسموح للمستخدم.
class Branch extends Equatable {
  const Branch({required this.id, required this.name, this.isActive = true});

  factory Branch.fromJson(Map<String, Object?> json) =>
      Branch(id: json['id']! as int, name: (json['name'] as String?) ?? '', isActive: json['is_active'] != false);

  final int id;
  final String name;
  final bool isActive;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'is_active': isActive};

  @override
  List<Object?> get props => [id, name, isActive];
}

/// صلاحيات السيرفر التي يعتمد عليها التطبيق (الأسماء كما في Laravel).
abstract final class Permissions {
  static const catalogSearch = 'catalog.search';
  static const inventoryView = 'inventory.view';
  static const manageCatalog = 'inventory.manage_catalog';
  static const correctSetup = 'inventory.correct_setup';
  static const sell = 'sales.sell';
  static const salesView = 'sales.view';
  static const customers = 'sales.customers';
  static const overridePrice = 'sales.override_price';
  static const viewCost = 'sales.view_cost';
  static const purchasesView = 'purchases.view';
  static const purchasesManage = 'purchases.manage';
  static const purchasePost = 'finance.purchase_post';
  static const allBranches = 'sales.all_branches';
}

/// المستخدم المسجل دخوله على هذا الجهاز.
class Session extends Equatable {
  const Session({
    required this.token,
    required this.deviceId,
    required this.userId,
    required this.userName,
    required this.username,
    required this.role,
    required this.permissions,
    required this.branches,
    required this.branchId,
    this.expiresAt,
  });

  final String token;

  /// UUID تسجيل الجهاز لهذا الحساب (يولده التطبيق مرة لكل حساب).
  final String deviceId;
  final int userId;
  final String userName;
  final String username;

  /// اسم الدور في السيرفر (مثل `sales_owner`).
  final String role;
  final Set<String> permissions;
  final List<Branch> branches;

  /// الفرع الذي يعمل عليه الجهاز الآن.
  final int branchId;
  final DateTime? expiresAt;

  bool can(String permission) => permissions.contains(permission);

  bool canAll(Iterable<String> required) => required.every(permissions.contains);

  Branch? get branch => branches.where((b) => b.id == branchId).firstOrNull;

  bool get canSell => canAll([Permissions.sell, Permissions.salesView]);
  bool get canSeeCatalog => canAll([Permissions.catalogSearch, Permissions.inventoryView]);
  bool get canManageCatalog => canSeeCatalog && can(Permissions.manageCatalog);
  bool get canPurchase =>
      canAll([Permissions.purchasesView, Permissions.purchasesManage, Permissions.viewCost, Permissions.purchasePost]);
  bool get canOpeningStock => canAll([Permissions.correctSetup, Permissions.viewCost]);
  bool get canSeeCost => can(Permissions.viewCost);

  /// الحد الأدنى للسعر: إدارة الكتالوج مع ملكية، أو تجاوز الأسعار مع كل الفروع (نفس قاعدة السيرفر).
  bool get canManageMinimumPrice =>
      (can(Permissions.manageCatalog) && role == 'sales_owner') ||
      canAll([Permissions.overridePrice, Permissions.allBranches]);

  String get roleLabel => switch (role) {
    'sales_owner' => 'المالك',
    'branch_manager' || 'sales_manager' => 'مدير فرع',
    'cashier' || 'sales_cashier' => 'كاشير',
    _ => role,
  };

  Session copyWith({int? branchId, String? token}) => Session(
    token: token ?? this.token,
    deviceId: deviceId,
    userId: userId,
    userName: userName,
    username: username,
    role: role,
    permissions: permissions,
    branches: branches,
    branchId: branchId ?? this.branchId,
    expiresAt: expiresAt,
  );

  Map<String, Object?> toJson() => {
    'token': token,
    'device_id': deviceId,
    'user_id': userId,
    'user_name': userName,
    'username': username,
    'role': role,
    'permissions': permissions.toList(),
    'branches': [for (final b in branches) b.toJson()],
    'branch_id': branchId,
    'expires_at': expiresAt?.toIso8601String(),
  };

  factory Session.fromJson(Map<String, Object?> json) => Session(
    token: json['token']! as String,
    deviceId: json['device_id']! as String,
    userId: json['user_id']! as int,
    userName: json['user_name']! as String,
    username: json['username']! as String,
    role: json['role']! as String,
    permissions: {...(json['permissions']! as List).cast<String>()},
    branches: [for (final b in json['branches']! as List) Branch.fromJson((b as Map).cast<String, Object?>())],
    branchId: json['branch_id']! as int,
    expiresAt: DateTime.tryParse((json['expires_at'] as String?) ?? ''),
  );

  @override
  List<Object?> get props => [
    token,
    deviceId,
    userId,
    userName,
    username,
    role,
    permissions,
    branches,
    branchId,
    expiresAt,
  ];
}

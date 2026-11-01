import 'package:equatable/equatable.dart';

enum UserRole {
  owner('owner', 'المالك'),
  manager('manager', 'مدير فرع'),
  cashier('cashier', 'كاشير');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static UserRole fromApi(String? value) =>
      values.firstWhere((r) => r.apiValue == value, orElse: () => UserRole.cashier);
}

/// المستخدم المسجل دخوله على هذا الجهاز.
class Session extends Equatable {
  const Session({
    required this.token,
    required this.userId,
    required this.userName,
    required this.role,
    required this.branchId,
  });

  final String token;
  final int userId;
  final String userName;
  final UserRole role;

  /// الفرع الذي يبيع منه هذا الجهاز.
  final int branchId;

  /// طلبات الموقع للمالك والمدير فقط (نفس قاعدة لوحة الويب).
  bool get canManageOnlineOrders => role != UserRole.cashier;

  Map<String, Object?> toJson() => {
    'token': token,
    'user_id': userId,
    'user_name': userName,
    'role': role.apiValue,
    'branch_id': branchId,
  };

  factory Session.fromJson(Map<String, Object?> json) => Session(
    token: json['token']! as String,
    userId: json['user_id']! as int,
    userName: json['user_name']! as String,
    role: UserRole.fromApi(json['role'] as String?),
    branchId: json['branch_id']! as int,
  );

  @override
  List<Object?> get props => [token, userId, userName, role, branchId];
}

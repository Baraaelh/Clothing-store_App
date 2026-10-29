import 'package:equatable/equatable.dart';

enum OnlineOrderStatus {
  pending('pending', 'قيد الانتظار'),
  accepted('accepted', 'مقبول'),
  rejected('rejected', 'مرفوض');

  const OnlineOrderStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static OnlineOrderStatus fromApi(String value) =>
      values.firstWhere((s) => s.apiValue == value, orElse: () => OnlineOrderStatus.pending);
}

class OnlineOrderItem extends Equatable {
  const OnlineOrderItem({required this.name, required this.quantity, required this.unitPrice, this.color, this.size});

  final String name;
  final String? color;
  final String? size;
  final int quantity;

  /// بالأغورة.
  final int unitPrice;

  int get lineTotal => unitPrice * quantity;

  @override
  List<Object?> get props => [name, color, size, quantity, unitPrice];
}

/// طلب من المتجر الإلكتروني.
class OnlineOrder extends Equatable {
  const OnlineOrder({
    required this.id,
    required this.customerName,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
    this.phone,
    this.city,
    this.address,
    this.notes,
    this.hasUnsyncedChange = false,
  });

  final String id;
  final String customerName;
  final String? phone;
  final String? city;
  final String? address;
  final String? notes;
  final List<OnlineOrderItem> items;
  final int total;
  final OnlineOrderStatus status;
  final DateTime createdAt;

  /// تم تغيير الحالة على الجهاز ولم تُرسل للسيرفر بعد.
  final bool hasUnsyncedChange;

  bool get canChangeStatus => status == OnlineOrderStatus.pending;

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  @override
  List<Object?> get props => [
    id,
    customerName,
    phone,
    city,
    address,
    notes,
    items,
    total,
    status,
    createdAt,
    hasUnsyncedChange,
  ];
}

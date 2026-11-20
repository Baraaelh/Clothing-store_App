import 'package:equatable/equatable.dart';

import '../../../core/data/reference_data.dart';
import '../../products/domain/product.dart';

enum StockEntryKind {
  /// فاتورة شراء من مورد (تُحفظ وتُعتمد على السيرفر مباشرة).
  purchase,

  /// بضاعة أول المدة (فقط قبل إغلاق فترة الإعداد في الفرع).
  opening,
}

class StockEntryRow extends Equatable {
  const StockEntryRow({
    required this.variant,
    required this.productName,
    required this.quantity,
    required this.unitCost,
  });

  final VariantInfo variant;
  final String productName;
  final int quantity;

  /// تكلفة القطعة بالأغورة.
  final int unitCost;

  @override
  List<Object?> get props => [variant, productName, quantity, unitCost];
}

class StockEntryDraft extends Equatable {
  const StockEntryDraft({
    required this.kind,
    required this.rows,
    this.supplier,
    this.invoiceNumber,
    this.initialPayment = 0,
    this.account,
    this.notes,
  });

  final StockEntryKind kind;
  final List<StockEntryRow> rows;
  final Party? supplier;
  final String? invoiceNumber;
  final int initialPayment;
  final PaymentAccount? account;
  final String? notes;

  int get total => rows.fold(0, (s, r) => s + r.quantity * r.unitCost);

  String? validate() {
    if (rows.isEmpty) return 'أضف صنفًا واحدًا على الأقل';
    final ids = <int>{};
    for (final r in rows) {
      if (!ids.add(r.variant.id)) return 'الصنف ${r.productName} مكرر';
      if (r.quantity <= 0) return 'أدخل كمية صحيحة لـ ${r.productName}';
      if (r.unitCost < 0) return 'التكلفة لا تكون سالبة';
    }
    if (kind == StockEntryKind.purchase) {
      if (supplier == null) return 'اختر المورد';
      if (initialPayment > total) return 'الدفعة أكبر من قيمة الفاتورة';
      if (initialPayment > 0 && account == null) return 'اختر الحساب الذي ستدفع منه';
    }
    return null;
  }

  @override
  List<Object?> get props => [kind, rows, supplier, invoiceNumber, initialPayment, account, notes];
}

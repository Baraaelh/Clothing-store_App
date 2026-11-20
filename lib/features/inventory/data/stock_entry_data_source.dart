import '../../../core/data/reference_data.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session/session.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/utils/money.dart';
import '../domain/stock_entry.dart';

/// إدخال بضاعة: فاتورة شراء (`purchase.create`) أو بضاعة أول المدة (`opening_stock.create`).
/// الكمية لا تُضاف محليًا: تظهر بعد اعتماد السيرفر والمزامنة.
class StockEntryDataSource {
  StockEntryDataSource(this._appDb, this._outbox);

  final AppDatabase _appDb;
  final Outbox _outbox;

  Future<String> submit(Session session, StockEntryDraft draft, {DateTime? now}) async {
    final db = await _appDb.database;
    final uuid = _outbox.newUuid();
    final date = _date((now ?? DateTime.now()).toLocal());
    final qty = draft.rows.fold(0, (s, r) => s + r.quantity);
    final value = draft.rows.fold(0, (s, r) => s + r.quantity * r.unitCost);
    final Map<String, Object?> payload;
    final String type;
    final String summary;
    if (draft.kind == StockEntryKind.purchase) {
      type = 'purchase.create';
      summary = 'شراء $qty قطعة بـ ${Money.format(value)} — ${draft.supplier?.name ?? ''}';
      final paying = draft.initialPayment > 0 && draft.account != null;
      payload = {
        'supplier_id': draft.supplier!.id,
        'invoice_date': date,
        if (draft.invoiceNumber?.trim().isNotEmpty ?? false) 'supplier_invoice_number': draft.invoiceNumber!.trim(),
        'initial_payment': Money.toDecimalString(paying ? draft.initialPayment : 0),
        if (paying) ...{
          'payment_method': _method(draft.account!),
          'payment_details': {'account_id': draft.account!.id, 'confirmed': true},
        },
        'rows': [
          for (final r in draft.rows)
            {
              'product_variant_id': r.variant.id,
              'quantity': r.quantity,
              'unit_cost': Money.toDecimalString(r.unitCost),
            },
        ],
      };
    } else {
      type = 'opening_stock.create';
      summary = 'بضاعة أول المدة: $qty قطعة';
      payload = {
        'opening_date': date,
        if (draft.notes?.trim().isNotEmpty ?? false) 'notes': draft.notes!.trim(),
        'rows': [
          for (final r in draft.rows)
            {
              'product_variant_id': r.variant.id,
              'qty': r.quantity,
              'cost': Money.toDecimalString(r.unitCost),
              'price': Money.toDecimalString(r.variant.price),
            },
        ],
      };
    }
    await db.transaction(
      (txn) => _outbox.enqueue(
        txn,
        uuid: uuid,
        type: type,
        branchId: session.branchId,
        userId: session.userId,
        payload: payload,
        summary: summary,
      ),
    );
    return uuid;
  }

  static String _method(PaymentAccount account) => switch (account.type) {
    'cash' || 'bank' || 'wallet' => account.type,
    _ => 'other',
  };

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

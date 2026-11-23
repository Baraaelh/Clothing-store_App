import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/reference_data.dart';
import '../../../core/di/injection.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/party_picker.dart';
import '../domain/stock_entry.dart';
import 'inventory_cubit.dart';

/// استلام بضاعة من مورد (فاتورة شراء) أو إدخال بضاعة أول المدة.
class StockEntryPage extends StatefulWidget {
  const StockEntryPage({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          BlocProvider(create: (_) => StockEntryCubit(sl(), sl(), sl(), sl())..load(), child: const StockEntryPage()),
    ),
  );

  @override
  State<StockEntryPage> createState() => _StockEntryPageState();
}

class _Line {
  _Line(this.stock) : qty = TextEditingController(text: '1'), cost = TextEditingController(text: _initialCost(stock));

  final StockLine stock;
  final TextEditingController qty;
  final TextEditingController cost;

  static String _initialCost(StockLine s) =>
      s.variant.averageCost == null || s.variant.averageCost == 0 ? '' : Money.toDecimalString(s.variant.averageCost!);

  void dispose() {
    qty.dispose();
    cost.dispose();
  }
}

class _StockEntryPageState extends State<StockEntryPage> {
  late StockEntryKind _kind = (sl<SessionManager>().current?.canPurchase ?? false)
      ? StockEntryKind.purchase
      : StockEntryKind.opening;
  Party? _supplier;
  PaymentAccount? _account;
  final _invoice = TextEditingController();
  final _payment = TextEditingController();
  final _notes = TextEditingController();
  final List<_Line> _lines = [];

  @override
  void dispose() {
    _invoice.dispose();
    _payment.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  static int _money(String t) => Money.fromDecimal(num.tryParse(t.trim()) ?? 0);

  StockEntryDraft _draft() => StockEntryDraft(
    kind: _kind,
    supplier: _supplier,
    invoiceNumber: _invoice.text,
    initialPayment: _money(_payment.text),
    account: _account,
    notes: _notes.text,
    rows: [
      for (final l in _lines)
        StockEntryRow(
          variant: l.stock.variant,
          productName: l.stock.productName,
          quantity: int.tryParse(l.qty.text.trim()) ?? 0,
          unitCost: _money(l.cost.text),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>().current;
    return BlocConsumer<StockEntryCubit, StockEntryState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!), backgroundColor: Colors.red));
        }
        if (state.saved) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('حُفظ المستند. الكميات تُضاف بعد اعتماد السيرفر والمزامنة.')));
        }
      },
      builder: (context, state) {
        final cubit = context.read<StockEntryCubit>();
        final draft = _draft();
        final kinds = [
          if (session?.canPurchase ?? false) StockEntryKind.purchase,
          if (state.openingAllowed) StockEntryKind.opening,
        ];
        if (!kinds.contains(_kind) && kinds.isNotEmpty) _kind = kinds.first;
        return Scaffold(
          appBar: AppBar(title: const Text('استلام بضاعة')),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: state.saving || kinds.isEmpty ? null : () => cubit.submit(draft),
                child: Text('حفظ (${Money.format(draft.total)})'),
              ),
            ),
          ),
          body: kinds.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'لا تملك صلاحية إدخال بضاعة في هذا الفرع، أو فترة الإعداد مغلقة.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (kinds.length > 1)
                      SegmentedButton<StockEntryKind>(
                        segments: const [
                          ButtonSegment(value: StockEntryKind.purchase, label: Text('فاتورة شراء')),
                          ButtonSegment(value: StockEntryKind.opening, label: Text('بضاعة أول المدة')),
                        ],
                        selected: {_kind},
                        onSelectionChanged: (s) => setState(() => _kind = s.first),
                      ),
                    const SizedBox(height: 12),
                    if (_kind == StockEntryKind.purchase) ...[
                      PartyField(
                        label: 'المورد',
                        icon: Icons.local_shipping_outlined,
                        value: _supplier,
                        search: cubit.searchSuppliers,
                        onChanged: (p) => setState(() => _supplier = p),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _invoice,
                        decoration: const InputDecoration(labelText: 'رقم فاتورة المورد (اختياري)'),
                      ),
                    ] else
                      TextField(
                        controller: _notes,
                        decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('الأصناف', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _pickVariant(context, state.variants),
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة صنف'),
                        ),
                      ],
                    ),
                    if (_lines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('لم تُضف أصناف بعد', textAlign: TextAlign.center),
                      ),
                    for (final (i, line) in _lines.indexed)
                      Card.outlined(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${line.stock.productName} — ${line.stock.variant.label}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => setState(() => _lines.removeAt(i).dispose()),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: line.qty,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'الكمية'),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: line.cost,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(labelText: 'تكلفة القطعة (₪)'),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_kind == StockEntryKind.purchase) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _payment,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'دفعة للمورد الآن (₪، اختياري)'),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_money(_payment.text) > 0) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<PaymentAccount>(
                          initialValue: _account,
                          decoration: const InputDecoration(labelText: 'الدفع من حساب'),
                          items: [
                            for (final a in state.accounts)
                              DropdownMenuItem(value: a, child: Text('${a.name} (${a.typeLabel})')),
                          ],
                          onChanged: (a) => setState(() => _account = a),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'المتبقي للمورد: ${Money.format((draft.total - draft.initialPayment).clamp(0, draft.total))}',
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Future<void> _pickVariant(BuildContext context, List<StockLine> variants) async {
    final picked = await showModalBottomSheet<StockLine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VariantSearch(variants: variants),
    );
    if (picked != null && !_lines.any((l) => l.stock.variant.id == picked.variant.id)) {
      setState(() => _lines.add(_Line(picked)));
    }
  }
}

class _VariantSearch extends StatefulWidget {
  const _VariantSearch({required this.variants});

  final List<StockLine> variants;

  @override
  State<_VariantSearch> createState() => _VariantSearchState();
}

class _VariantSearchState extends State<_VariantSearch> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim();
    final results = q.isEmpty
        ? widget.variants
        : widget.variants
              .where((l) => l.productName.contains(q) || l.variant.sku.toLowerCase().contains(q.toLowerCase()))
              .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بالاسم أو SKU'),
              onChanged: (v) => setState(() => _q = v),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final l in results)
                    ListTile(
                      title: Text(l.productName),
                      subtitle: Text('${l.variant.label} • ${l.variant.sku}'),
                      trailing: Text(l.variant.quantity == null ? 'جديد' : 'الرصيد ${l.variant.quantity}'),
                      onTap: () => Navigator.pop(context, l),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

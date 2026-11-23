import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/reference_data.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/party_picker.dart';
import '../../domain/entities/checkout_request.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/checkout_cubit.dart';

/// نموذج الدفع: طريقة السداد، حساب القبض، الزبون، الخصم.
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<CartCubit>()),
        BlocProvider.value(value: context.read<CatalogCubit>()),
        BlocProvider(create: (_) => sl<CheckoutCubit>()..load()),
      ],
      child: const CheckoutSheet(),
    ),
  );

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  PaymentMode _mode = PaymentMode.paid;
  PaymentAccount? _account;
  Party? _customer;
  final _discount = TextEditingController();
  final _received = TextEditingController();
  final _partial = TextEditingController();

  @override
  void dispose() {
    _discount.dispose();
    _received.dispose();
    _partial.dispose();
    super.dispose();
  }

  static int _parse(String text) => Money.fromDecimal(num.tryParse(text.trim()) ?? 0);

  CheckoutRequest _request(CartState cart) => CheckoutRequest(
    lines: cart.lines,
    mode: _mode,
    account: _mode == PaymentMode.credit ? null : _account,
    discount: cart.discount,
    paidAmount: _parse(_partial.text),
    amountReceived: _parse(_received.text),
    customer: _customer,
  );

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartCubit>().state;
    final request = _request(cart);

    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listener: _onState,
      builder: (context, checkout) {
        if (_account == null && checkout.accounts.isNotEmpty) _account = checkout.accounts.first;
        final remaining = request.total - request.collected;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('إتمام البيع', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                SegmentedButton<PaymentMode>(
                  segments: [for (final m in PaymentMode.values) ButtonSegment(value: m, label: Text(m.label))],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                if (_mode != PaymentMode.credit) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentAccount>(
                    initialValue: _account,
                    decoration: const InputDecoration(
                      labelText: 'حساب القبض',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: [
                      for (final a in checkout.accounts)
                        DropdownMenuItem(value: a, child: Text('${a.name} (${a.typeLabel})')),
                    ],
                    onChanged: (a) => setState(() => _account = a),
                  ),
                  if (checkout.accounts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'لا توجد حسابات قبض في هذا الفرع بعد. زامن أو أضفها من لوحة الويب.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                PartyField(
                  label: _mode.needsCustomer ? 'الزبون (مطلوب)' : 'الزبون (اختياري)',
                  icon: Icons.person_outline,
                  value: _customer,
                  search: context.read<CheckoutCubit>().searchCustomers,
                  onChanged: (p) => setState(() => _customer = p),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _discount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'خصم على الفاتورة (₪)',
                    prefixIcon: Icon(Icons.discount_outlined),
                  ),
                  onChanged: (v) => context.read<CartCubit>().setDiscount(_parse(v)),
                ),
                if (_mode == PaymentMode.partial) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _partial,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المدفوع الآن (₪)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                if (_mode == PaymentMode.paid && _account?.type == 'cash') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _received,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المستلم من الزبون (₪)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 16),
                _row('الإجمالي', Money.format(request.total), bold: true),
                if (_mode == PaymentMode.paid && request.amountReceived > 0)
                  _row(
                    request.amountReceived >= request.total ? 'الباقي للزبون' : 'ناقص',
                    Money.format((request.amountReceived - request.total).abs()),
                    color: request.amountReceived >= request.total ? Colors.green.shade700 : Colors.red,
                  ),
                if (_mode != PaymentMode.paid)
                  _row('يُسجل دينًا على الزبون', Money.format(remaining < 0 ? 0 : remaining)),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: checkout.submitting ? null : () => context.read<CheckoutCubit>().submit(request),
                  child: checkout.submitting
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('تأكيد البيع'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onState(BuildContext context, CheckoutState state) {
    final messenger = ScaffoldMessenger.of(context);
    if (state.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(state.error!), backgroundColor: Colors.red));
    }
    final sale = state.sale;
    if (sale == null) return;
    final cart = context.read<CartCubit>();
    final catalog = context.read<CatalogCubit>();
    Navigator.of(context).pop();
    // إفراغ السلة يغلق نافذة السلة أيضًا (CartSheet تستمع لذلك).
    cart.clear();
    catalog.load();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'تم حفظ الفاتورة (${Money.format(sale.total)})'
          '${sale.change > 0 ? ' — الباقي ${Money.format(sale.change)}' : ''}'
          '. تُعتمد بعد وصولها للسيرفر.',
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : null, color: color, fontSize: bold ? 18 : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

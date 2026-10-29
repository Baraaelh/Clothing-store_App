import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/checkout_request.dart';
import '../../domain/entities/payment_method.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/checkout_cubit.dart';

/// نموذج الدفع: طريقة الدفع، الخصم، المبلغ المدفوع، اسم الزبون.
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
        BlocProvider(create: (_) => sl<CheckoutCubit>()),
      ],
      child: const CheckoutSheet(),
    ),
  );

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  PaymentMethod _method = PaymentMethod.cash;
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  final _customer = TextEditingController();

  @override
  void dispose() {
    _discount.dispose();
    _paid.dispose();
    _customer.dispose();
    super.dispose();
  }

  static int _parse(String text) => Money.fromDecimal(num.tryParse(text.trim()) ?? 0);

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartCubit>().state;
    final paid = _method == PaymentMethod.cash ? _parse(_paid.text) : cart.total;
    final change = paid - cart.total;

    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listener: _onCheckoutState,
      builder: (context, checkout) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إتمام البيع', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<PaymentMethod>(
                segments: [for (final m in PaymentMethod.values) ButtonSegment(value: m, label: Text(m.label))],
                selected: {_method},
                onSelectionChanged: (s) => setState(() => _method = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'خصم (₪)', prefixIcon: Icon(Icons.discount_outlined)),
                onChanged: (v) => context.read<CartCubit>().setDiscount(_parse(v)),
              ),
              if (_method == PaymentMethod.cash) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _paid,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المستلم (₪)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _customer,
                decoration: const InputDecoration(
                  labelText: 'اسم الزبون (اختياري)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              _row('الإجمالي', Money.format(cart.total), bold: true),
              if (_method == PaymentMethod.cash && paid > 0)
                _row(
                  change >= 0 ? 'الباقي للزبون' : 'المتبقي',
                  Money.format(change.abs()),
                  color: change >= 0 ? Colors.green.shade700 : Colors.red,
                ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: checkout is CheckoutSubmitting ? null : () => _submit(cart, paid),
                child: checkout is CheckoutSubmitting
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('تأكيد البيع'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(CartState cart, int paid) {
    context.read<CheckoutCubit>().submit(
      CheckoutRequest(
        lines: cart.lines,
        paymentMethod: _method,
        discount: cart.discount,
        amountPaid: paid,
        customerName: _customer.text,
      ),
    );
  }

  void _onCheckoutState(BuildContext context, CheckoutState state) {
    final messenger = ScaffoldMessenger.of(context);
    switch (state) {
      case CheckoutSuccess(:final sale):
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
              '. ستُرسل للسيرفر عند توفر الإنترنت.',
            ),
          ),
        );
      case CheckoutFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
        context.read<CheckoutCubit>().reset();
      case CheckoutIdle():
      case CheckoutSubmitting():
        break;
    }
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

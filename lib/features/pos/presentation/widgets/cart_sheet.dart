import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/money.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/catalog_cubit.dart';
import 'checkout_sheet.dart';

class CartSheet extends StatelessWidget {
  const CartSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // النافذة route منفصل: نمرر لها الـ cubits التي تحتاجها هي ونافذة الدفع.
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<CartCubit>()),
        BlocProvider.value(value: context.read<CatalogCubit>()),
      ],
      child: const CartSheet(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CartCubit, CartState>(
      listener: (context, cart) {
        if (cart.isEmpty) Navigator.of(context).pop();
      },
      builder: (context, cart) {
        final cubit = context.read<CartCubit>();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (context, scroll) => Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final line in cart.lines)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(line.item.productName),
                        subtitle: Text('${line.item.variantLabel} • ${Money.format(line.unitPrice)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => cubit.setQuantity(line.item.variantId, line.quantity - 1),
                            ),
                            Text('${line.quantity}', style: Theme.of(context).textTheme.titleMedium),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => cubit.setQuantity(line.item.variantId, line.quantity + 1),
                            ),
                            SizedBox(width: 80, child: Text(Money.format(line.lineTotal), textAlign: TextAlign.end)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _totalRow(context, 'المجموع', cart.subtotal),
                    if (cart.discount > 0) _totalRow(context, 'الخصم', -cart.discount),
                    _totalRow(context, 'الإجمالي', cart.total, bold: true),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(onPressed: cubit.clear, child: const Text('إفراغ السلة')),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => CheckoutSheet.show(context),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('إتمام البيع'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _totalRow(BuildContext context, String label, int amount, {bool bold = false}) {
    final style = bold ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) : null;
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(Money.format(amount), style: style),
      ],
    );
  }
}

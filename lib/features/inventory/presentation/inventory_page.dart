import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/sync/sync_cubit.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/color_dot.dart';
import 'inventory_cubit.dart';
import 'stock_entry_page.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>().current;
    final canReceive = (session?.canPurchase ?? false) || (session?.canOpeningStock ?? false);
    return BlocListener<SyncCubit, SyncState>(
      listenWhen: (a, b) => a.lastSyncAt != b.lastSyncAt,
      listener: (context, _) => context.read<InventoryCubit>().load(),
      child: Scaffold(
        floatingActionButton: canReceive
            ? FloatingActionButton.extended(
                heroTag: 'receive-goods',
                onPressed: () => StockEntryPage.open(context),
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: const Text('استلام بضاعة'),
              )
            : null,
        body: BlocBuilder<InventoryCubit, InventoryState>(
          builder: (context, state) {
            final cubit = context.read<InventoryCubit>();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بالاسم أو SKU'),
                    onChanged: cubit.search,
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final f in StockFilter.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            label: Text(f.label),
                            selected: state.filter == f,
                            onSelected: (_) => cubit.setFilter(f),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text('إجمالي القطع: ${state.totalUnits}'),
                      const Spacer(),
                      if (state.totalValue != null) Text('القيمة بالتكلفة: ${Money.format(state.totalValue!)}'),
                    ],
                  ),
                ),
                Expanded(
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : state.lines.isEmpty
                      ? const Center(child: Text('لا توجد أصناف'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                          itemCount: state.lines.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final line = state.lines[i];
                            final v = line.variant;
                            final available = v.available ?? 0;
                            final color = available <= 0
                                ? Theme.of(context).colorScheme.error
                                : available <= 3
                                ? Colors.orange.shade800
                                : Colors.green.shade700;
                            return Card.outlined(
                              child: ListTile(
                                leading: ColorDot(hex: v.colorHex, size: 22),
                                title: Text(line.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text([v.label, v.sku].where((s) => s.isNotEmpty).join(' • ')),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$available',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      (v.reserved ?? 0) > 0 ? 'الكلي ${v.quantity} • محجوز ${v.reserved}' : 'متاح',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

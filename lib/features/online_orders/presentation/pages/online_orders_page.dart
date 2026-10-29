import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/sync/sync_cubit.dart';
import '../../domain/entities/online_order.dart';
import '../cubit/online_orders_cubit.dart';
import '../widgets/order_card.dart';

class OnlineOrdersPage extends StatelessWidget {
  const OnlineOrdersPage({super.key});

  static const _filters = <(OnlineOrderStatus?, String)>[
    (OnlineOrderStatus.pending, 'المعلقة'),
    (OnlineOrderStatus.accepted, 'المقبولة'),
    (OnlineOrderStatus.rejected, 'المرفوضة'),
    (null, 'الكل'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnlineOrdersCubit, OnlineOrdersState>(
      listenWhen: (_, s) => s.message != null,
      listener: (context, s) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, state) {
        final cubit = context.read<OnlineOrdersCubit>();
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  for (final (status, label) in _filters)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: state.filter == status,
                        onSelected: (_) => cubit.setFilter(status),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                // السحب للتحديث = مزامنة (إرسال التغييرات وسحب الطلبات الجديدة).
                onRefresh: () => context.read<SyncCubit>().syncNow(),
                child: _body(context, state),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, OnlineOrdersState state) {
    if (state.status == OrdersStatus.initial || state.status == OrdersStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.orders.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('لا توجد طلبات')),
        ],
      );
    }
    final cubit = context.read<OnlineOrdersCubit>();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: state.orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final order = state.orders[i];
        return OrderCard(
          order: order,
          busy: state.busyOrderIds.contains(order.id),
          onAccept: () => cubit.accept(order),
          onReject: () => _confirmReject(context, order),
        );
      },
    );
  }

  Future<void> _confirmReject(BuildContext context, OnlineOrder order) async {
    final cubit = context.read<OnlineOrdersCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: Text('هل تريد رفض الطلب ${order.id} للزبون ${order.customerName}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('رفض')),
        ],
      ),
    );
    if (ok ?? false) await cubit.reject(order);
  }
}

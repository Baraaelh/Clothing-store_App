import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/session/session.dart';
import '../core/sync/sync_cubit.dart';
import '../core/widgets/sync_indicator.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/online_orders/domain/entities/online_order.dart';
import '../features/online_orders/presentation/cubit/online_orders_cubit.dart';
import '../features/online_orders/presentation/pages/online_orders_page.dart';
import '../features/pos/presentation/cubit/cart_cubit.dart';
import '../features/pos/presentation/cubit/catalog_cubit.dart';
import '../features/pos/presentation/pages/pos_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.session});

  final Session session;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  bool get _showOrders => widget.session.canManageOnlineOrders;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // بعد كل مزامنة: أعد تحميل البيانات المحلية (قد يكون السحب جلب تحديثات).
        BlocListener<SyncCubit, SyncState>(
          listenWhen: (a, b) => a.lastSyncAt != b.lastSyncAt,
          listener: (context, _) {
            context.read<CatalogCubit>().load();
            if (_showOrders) context.read<OnlineOrdersCubit>().load();
          },
        ),
        // تحديث الكميات المتاحة لأصناف السلة بعد إعادة تحميل المنتجات.
        BlocListener<CatalogCubit, CatalogState>(
          listenWhen: (a, b) => a.items != b.items && b.query.isEmpty,
          listener: (context, state) => context.read<CartCubit>().refreshItems(state.items),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tab == 0 ? 'الكاشير' : 'طلبات الموقع'),
          actions: [
            const SyncIndicator(),
            _UserMenu(session: widget.session),
            const SizedBox(width: 4),
          ],
        ),
        body: _showOrders
            ? IndexedStack(index: _tab, children: const [PosPage(), OnlineOrdersPage()])
            : const PosPage(),
        bottomNavigationBar: _showOrders
            ? NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.point_of_sale_outlined),
                    selectedIcon: Icon(Icons.point_of_sale),
                    label: 'الكاشير',
                  ),
                  NavigationDestination(
                    icon: BlocSelector<OnlineOrdersCubit, OnlineOrdersState, int>(
                      selector: (s) => s.filter == null || s.filter == OnlineOrderStatus.pending
                          ? s.orders.where((o) => o.canChangeStatus).length
                          : 0,
                      builder: (_, pending) => Badge(
                        isLabelVisible: pending > 0,
                        label: Text('$pending'),
                        child: const Icon(Icons.shopping_bag_outlined),
                      ),
                    ),
                    selectedIcon: const Icon(Icons.shopping_bag),
                    label: 'طلبات الموقع',
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'الحساب',
      icon: CircleAvatar(radius: 16, child: Text(session.userName.isEmpty ? '?' : session.userName.characters.first)),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(session.userName),
            subtitle: Text('${session.role.label} • الفرع ${session.branchId}'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => _confirmLogout(context),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('تسجيل الخروج'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthCubit>();
    final pending = context.read<SyncCubit>().state;
    final unsent = pending.pendingCount + pending.failedCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: Text(
          unsent > 0
              ? 'يوجد $unsent عمليات لم تُرسل للسيرفر بعد. ستبقى محفوظة على الجهاز وتُرسل بعد تسجيل الدخول من جديد.'
              : 'هل تريد تسجيل الخروج؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسجيل الخروج')),
        ],
      ),
    );
    if (ok ?? false) await auth.logout();
  }
}

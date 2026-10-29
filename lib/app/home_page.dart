import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/sync/sync_cubit.dart';
import '../core/widgets/sync_indicator.dart';
import '../features/online_orders/presentation/cubit/online_orders_cubit.dart';
import '../features/online_orders/presentation/pages/online_orders_page.dart';
import '../features/pos/presentation/cubit/cart_cubit.dart';
import '../features/pos/presentation/cubit/catalog_cubit.dart';
import '../features/pos/presentation/pages/pos_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // بعد كل مزامنة: أعد تحميل البيانات المحلية (قد يكون السحب جلب تحديثات).
        BlocListener<SyncCubit, SyncState>(
          listenWhen: (a, b) => a.lastSyncAt != b.lastSyncAt,
          listener: (context, _) {
            context.read<CatalogCubit>().load();
            context.read<OnlineOrdersCubit>().load();
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
          actions: const [SyncIndicator(), SizedBox(width: 8)],
        ),
        body: IndexedStack(index: _tab, children: const [PosPage(), OnlineOrdersPage()]),
        bottomNavigationBar: NavigationBar(
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
                selector: (s) => s.filter == null || s.filter!.name == 'pending'
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
        ),
      ),
    );
  }
}

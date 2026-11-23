import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/session/session.dart';
import '../core/sync/sync_cubit.dart';
import '../core/widgets/sync_indicator.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/inventory/presentation/inventory_page.dart';
import '../features/operations/presentation/operations_page.dart';
import '../features/pos/presentation/cubit/cart_cubit.dart';
import '../features/pos/presentation/cubit/catalog_cubit.dart';
import '../features/pos/presentation/pages/pos_page.dart';
import '../features/pos/presentation/pages/sales_history_page.dart';
import '../features/products/presentation/products_page.dart';

enum _Tab {
  pos('البيع', Icons.point_of_sale_outlined, Icons.point_of_sale),
  products('المنتجات', Icons.checkroom_outlined, Icons.checkroom),
  inventory('المخزون', Icons.inventory_2_outlined, Icons.inventory_2);

  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.session});

  final Session session;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  late final List<_Tab> _tabs = [
    if (widget.session.canSell) _Tab.pos,
    if (widget.session.canSeeCatalog) ...[_Tab.products, _Tab.inventory],
  ];

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('الأناقة الذكي'),
          actions: [_UserMenu(session: widget.session)],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'حسابك لا يملك صلاحيات البيع أو المخزون على الجوال. راجع مالك المحل.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final tab = _tabs[_index];
    return MultiBlocListener(
      listeners: [
        if (widget.session.canSell) ...[
          // بعد كل مزامنة: أعد تحميل الأصناف (الكميات تغيرت).
          BlocListener<SyncCubit, SyncState>(
            listenWhen: (a, b) => a.lastSyncAt != b.lastSyncAt,
            listener: (context, _) => context.read<CatalogCubit>().load(),
          ),
          BlocListener<CatalogCubit, CatalogState>(
            listenWhen: (a, b) => a.items != b.items && b.query.isEmpty,
            listener: (context, state) => context.read<CartCubit>().refreshItems(state.items),
          ),
        ],
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(tab.label),
          actions: [
            if (tab == _Tab.pos)
              IconButton(
                tooltip: 'فواتير الجهاز',
                icon: const Icon(Icons.receipt_long_outlined),
                onPressed: () => SalesHistoryPage.open(context),
              ),
            const SyncIndicator(),
            _UserMenu(session: widget.session),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            const _StatusBanner(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  for (final t in _tabs)
                    switch (t) {
                      _Tab.pos => const PosPage(),
                      _Tab.products => const ProductsPage(),
                      _Tab.inventory => const InventoryPage(),
                    },
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _tabs.length < 2
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                destinations: [
                  for (final t in _tabs)
                    NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
                ],
              ),
      ),
    );
  }
}

/// تنبيهات أعلى الشاشة: أول تنزيل، عمليات مرفوضة، البيع غير مسموح في الفرع.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncState>(
      builder: (context, s) {
        final scheme = Theme.of(context).colorScheme;
        if (!s.initialCompleted) {
          return MaterialBanner(
            leading: s.isSyncing
                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_download_outlined),
            content: Text(
              s.isOnline ? 'جارٍ تنزيل بيانات الفرع لأول مرة…' : 'اتصل بالإنترنت لتنزيل بيانات الفرع لأول مرة.',
            ),
            actions: const [SizedBox.shrink()],
          );
        }
        if (s.reviewCount > 0) {
          return MaterialBanner(
            backgroundColor: scheme.errorContainer,
            leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
            content: Text(
              '${s.reviewCount} عملية رفضها السيرفر وتحتاج مراجعتك',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            actions: [TextButton(onPressed: () => OperationsPage.open(context), child: const Text('مراجعة'))],
          );
        }
        if (s.salesAllowed == false) {
          return MaterialBanner(
            leading: const Icon(Icons.block),
            content: Text(
              s.branchWarning ?? 'البيع غير مفعّل في هذا الفرع بعد (فترة الإعداد). الفواتير تُحفظ لكن السيرفر سيرفضها.',
            ),
            actions: const [SizedBox.shrink()],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthCubit>();
    return PopupMenuButton<void>(
      tooltip: 'الحساب',
      icon: CircleAvatar(radius: 16, child: Text(session.userName.isEmpty ? '?' : session.userName.characters.first)),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(session.userName),
            subtitle: Text('${session.roleLabel} • ${session.branch?.name ?? 'الفرع ${session.branchId}'}'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => OperationsPage.open(context),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.sync_alt),
            title: Text('عمليات المزامنة'),
          ),
        ),
        if (session.branches.length > 1)
          PopupMenuItem(
            onTap: () => _pickBranch(context, auth),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.store_outlined),
              title: Text('تبديل الفرع'),
            ),
          ),
        PopupMenuItem(
          onTap: () => _confirmLogout(context, auth),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('تسجيل الخروج'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickBranch(BuildContext context, AuthCubit auth) async {
    final id = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر الفرع'),
        children: [
          for (final b in session.branches)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, b.id),
              child: Row(
                children: [
                  Expanded(child: Text(b.name)),
                  if (b.id == session.branchId) const Icon(Icons.check),
                ],
              ),
            ),
        ],
      ),
    );
    if (id != null && id != session.branchId) await auth.switchBranch(id);
  }

  Future<void> _confirmLogout(BuildContext context, AuthCubit auth) async {
    final sync = context.read<SyncCubit>().state;
    final unsent = sync.pendingCount + sync.reviewCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: Text(
          unsent > 0
              ? 'يوجد $unsent عمليات لم تصل للسيرفر بعد. ستبقى محفوظة على الجهاز وتُرسل بعد دخولك بنفس الحساب.'
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

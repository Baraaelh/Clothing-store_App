import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/sync/sync_cubit.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/sale.dart';
import '../../domain/usecases/get_recent_sales.dart';

/// فواتير هذا الجهاز وحالة كل منها على السيرفر.
class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  static Future<void> open(BuildContext context) {
    final sync = context.read<SyncCubit>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(value: sync, child: const SalesHistoryPage()),
      ),
    );
  }

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  List<Sale>? _sales;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<GetRecentSales>()(const NoParams());
    if (mounted) setState(() => _sales = result.fold((_) => const [], (s) => s));
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('d/M HH:mm', 'en');
    return BlocListener<SyncCubit, SyncState>(
      listenWhen: (a, b) => a.lastSyncAt != b.lastSyncAt,
      listener: (_, _) => _load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('فواتير الجهاز')),
        body: _sales == null
            ? const Center(child: CircularProgressIndicator())
            : _sales!.isEmpty
            ? const Center(child: Text('لا توجد فواتير بعد'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _sales!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final s = _sales![i];
                  final (label, color, icon) = switch (s.status) {
                    SaleStatus.accepted => (s.number ?? 'معتمدة', Colors.green.shade700, Icons.check_circle_outline),
                    SaleStatus.pending => ('بانتظار الإرسال', Colors.orange.shade800, Icons.cloud_upload_outlined),
                    SaleStatus.review => (
                      'مرفوضة — راجع العمليات',
                      Theme.of(context).colorScheme.error,
                      Icons.error_outline,
                    ),
                  };
                  return Card.outlined(
                    child: ExpansionTile(
                      leading: Icon(icon, color: color),
                      title: Text('${Money.format(s.total)} • ${s.itemCount} قطعة'),
                      subtitle: Text(
                        '${time.format(s.createdAt)} • ${s.paymentLabel} • $label',
                        style: TextStyle(color: color),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        for (final item in s.items)
                          Row(
                            children: [
                              Expanded(child: Text('${item.productName} ${item.variantLabel ?? ''}')),
                              Text('${item.quantity} × ${Money.format(item.unitPrice)}'),
                            ],
                          ),
                        if (s.discount > 0)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text('خصم ${Money.format(s.discount)}'),
                          ),
                        if (s.customerName != null)
                          Align(alignment: AlignmentDirectional.centerStart, child: Text('الزبون: ${s.customerName}')),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/sync/sync_cubit.dart';
import '../../pos/data/datasources/pos_local_data_source.dart';
import 'operations_cubit.dart';

/// العمليات المنتظرة والمرفوضة. الرفض لا يُعاد تلقائيًا: المستخدم يقرر.
class OperationsPage extends StatelessWidget {
  const OperationsPage({super.key});

  static Future<void> open(BuildContext context) {
    final sync = context.read<SyncCubit>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: sync),
            BlocProvider(create: (_) => sl<OperationsCubit>()..load()),
          ],
          child: const OperationsPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SyncCubit, SyncState>(
      listenWhen: (a, b) => a.lastSyncAt != b.lastSyncAt || a.pendingCount != b.pendingCount,
      listener: (context, _) => context.read<OperationsCubit>().load(),
      child: BlocConsumer<OperationsCubit, OperationsState>(
        listenWhen: (_, s) => s.message != null,
        listener: (context, s) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.message!)));
          context.read<SyncCubit>().syncNow(force: true);
        },
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: const Text('عمليات المزامنة'),
            actions: [
              IconButton(
                tooltip: 'مزامنة الآن',
                icon: const Icon(Icons.sync),
                onPressed: () => context.read<SyncCubit>().syncNow(force: true),
              ),
            ],
          ),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.review.isEmpty && state.pending.isEmpty
              ? const Center(child: Text('كل العمليات وصلت للسيرفر'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (state.review.isNotEmpty) ...[
                      _header(context, 'تحتاج مراجعة (${state.review.length})', Colors.red),
                      for (final op in state.review) _ReviewCard(op: op),
                      const SizedBox(height: 16),
                    ],
                    if (state.pending.isNotEmpty) ...[
                      _header(context, 'تنتظر الإرسال (${state.pending.length})', Colors.orange.shade800),
                      for (final op in state.pending)
                        Card.outlined(
                          child: ListTile(
                            leading: const Icon(Icons.cloud_upload_outlined),
                            title: Text(op.summary),
                            subtitle: Text(
                              [op.typeLabel, if (op.errorMessage != null) op.errorMessage!].join(' • '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.op});

  final OutboxOperation op;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OperationsCubit>();
    final quote = op.type == saleOperation ? MinimumQuote.fromResult(op.result) : null;
    final stockChanged = op.type == saleOperation && quote == null && op.errorCode == 'conflict_requires_review';
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(op.summary, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(op.typeLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              op.errorMessage ?? 'رفض السيرفر العملية',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (quote != null) ...[
              const SizedBox(height: 8),
              for (final item in quote.items)
                Text(
                  '• ${item['name']} (${[item['color'], item['size']].whereType<String>().join(' / ')}): '
                  'السعر ${item['effective_unit']} والحد الأدنى ${item['minimum_unit']}',
                ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(onPressed: () => _confirmDismiss(context, cubit), child: const Text('إلغاء العملية')),
                if (quote != null)
                  FilledButton(
                    onPressed: () => cubit.confirmBelowMinimum(op, quote),
                    child: const Text('تأكيد البيع تحت الحد الأدنى'),
                  ),
                if (stockChanged)
                  FilledButton(
                    onPressed: () => cubit.resubmitSale(op),
                    child: const Text('إعادة الإرسال بالرصيد الحالي'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDismiss(BuildContext context, OperationsCubit cubit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء العملية'),
        content: const Text(
          'لن تُرسل هذه العملية للسيرفر. إن كانت فاتورة بيع، تأكد من إرجاع البضاعة أو تسجيلها من جديد.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إلغاء العملية')),
        ],
      ),
    );
    if (ok ?? false) await cubit.dismiss(op);
  }
}

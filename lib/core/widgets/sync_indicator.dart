import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../sync/sync_cubit.dart';

/// أيقونة حالة المزامنة في الشريط العلوي. الضغط عليها يعرض التفاصيل.
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncState>(
      builder: (context, state) {
        final (icon, color) = switch (state) {
          SyncState(isSyncing: true) => (Icons.sync, Theme.of(context).colorScheme.primary),
          SyncState(failedCount: > 0) => (Icons.sync_problem, Colors.red),
          SyncState(isOnline: false) => (Icons.cloud_off, Colors.grey),
          SyncState(pendingCount: > 0) => (Icons.cloud_upload_outlined, Colors.orange),
          _ => (Icons.cloud_done_outlined, Colors.green),
        };
        final badge = state.pendingCount + state.failedCount;
        return IconButton(
          tooltip: 'المزامنة',
          onPressed: () => _showDetails(context),
          icon: Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            child: Icon(icon, color: color),
          ),
        );
      },
    );
  }

  void _showDetails(BuildContext context) {
    final cubit = context.read<SyncCubit>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(value: cubit, child: const _SyncSheet()),
    );
  }
}

class _SyncSheet extends StatelessWidget {
  const _SyncSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncState>(
      builder: (context, state) {
        final cubit = context.read<SyncCubit>();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('المزامنة مع السيرفر', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _row('الاتصال', state.isOnline ? 'متصل' : 'غير متصل'),
              _row('عمليات تنتظر الإرسال', '${state.pendingCount}'),
              _row('عمليات فشلت', '${state.failedCount}'),
              _row(
                'آخر مزامنة',
                state.lastSyncAt == null ? '—' : TimeOfDay.fromDateTime(state.lastSyncAt!).format(context),
              ),
              if (!state.apiConfigured)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'الـ API لم يُضبط بعد. البيانات محفوظة على الجهاز وستُرسل عند ضبطه.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: state.isSyncing || !state.isOnline ? null : cubit.syncNow,
                icon: state.isSyncing
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync),
                label: const Text('مزامنة الآن'),
              ),
              if (state.failedCount > 0) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: state.isSyncing ? null : cubit.retryFailed,
                  icon: const Icon(Icons.replay),
                  label: const Text('إعادة محاولة العمليات الفاشلة'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

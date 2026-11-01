import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/api_config.dart';
import '../network/network_info.dart';
import 'sync_queue.dart';
import 'sync_service.dart';

class SyncState extends Equatable {
  const SyncState({
    this.isOnline = false,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncAt,
    this.apiConfigured = true,
    this.sessionExpired = false,
  });

  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;

  /// آخر دورة مزامنة اكتملت (حتى لو لم يُرسل شيء). الشاشات تعيد التحميل عند تغيّره.
  final DateTime? lastSyncAt;
  final bool apiConfigured;

  /// السيرفر رفض التوكن (401). الواجهة ترجع لشاشة الدخول.
  final bool sessionExpired;

  SyncState copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSyncAt,
    bool? apiConfigured,
    bool? sessionExpired,
  }) => SyncState(
    isOnline: isOnline ?? this.isOnline,
    isSyncing: isSyncing ?? this.isSyncing,
    pendingCount: pendingCount ?? this.pendingCount,
    failedCount: failedCount ?? this.failedCount,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    apiConfigured: apiConfigured ?? this.apiConfigured,
    sessionExpired: sessionExpired ?? this.sessionExpired,
  );

  @override
  List<Object?> get props => [
    isOnline,
    isSyncing,
    pendingCount,
    failedCount,
    lastSyncAt,
    apiConfigured,
    sessionExpired,
  ];
}

/// يشغّل المزامنة تلقائيًا: عند عودة الاتصال، وكل [interval]، وعند وجود عمليات جديدة.
class SyncCubit extends Cubit<SyncState> {
  SyncCubit({
    required SyncService service,
    required SyncQueue queue,
    required NetworkInfo network,
    this.interval = const Duration(minutes: 2),
  }) : _service = service,
       _queue = queue,
       _network = network,
       super(const SyncState(apiConfigured: ApiConfig.baseUrl != ''));

  final SyncService _service;
  final SyncQueue _queue;
  final NetworkInfo _network;
  final Duration interval;

  StreamSubscription<bool>? _networkSub;
  StreamSubscription<void>? _queueSub;
  Timer? _timer;

  Future<void> start() async {
    _networkSub = _network.onStatusChange.listen((online) {
      emit(state.copyWith(isOnline: online));
      if (online) unawaited(syncNow());
    });
    _queueSub = _queue.changes.listen((_) async {
      await _refreshCounts();
      // عملية جديدة أُضيفت: حاول إرسالها فورًا إن كان هناك اتصال.
      if (state.isOnline && !_service.isRunning) unawaited(syncNow());
    });
    _timer = Timer.periodic(interval, (_) {
      if (state.isOnline) unawaited(syncNow());
    });

    emit(state.copyWith(isOnline: await _network.isConnected));
    await _refreshCounts();
    if (state.isOnline) await syncNow();
  }

  Future<void> syncNow() async {
    if (_service.isRunning || isClosed || state.sessionExpired) return;
    emit(state.copyWith(isSyncing: true));
    final report = await _service.run();
    if (isClosed) return;
    final counts = await _queue.counts();
    emit(
      state.copyWith(
        isSyncing: false,
        pendingCount: counts.pending,
        failedCount: counts.failed,
        lastSyncAt: DateTime.now(),
        apiConfigured: report == null ? null : !report.notConfigured,
        sessionExpired: report?.unauthorized,
      ),
    );
  }

  Future<void> retryFailed() async {
    await _queue.retryFailed();
    await syncNow();
  }

  Future<void> _refreshCounts() async {
    final counts = await _queue.counts();
    if (!isClosed) emit(state.copyWith(pendingCount: counts.pending, failedCount: counts.failed));
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _networkSub?.cancel();
    await _queueSub?.cancel();
    return super.close();
  }
}

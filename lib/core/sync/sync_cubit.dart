import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/api_config.dart';
import '../network/network_info.dart';
import '../session/session_manager.dart';
import 'outbox.dart';
import 'sync_engine.dart';

class SyncState extends Equatable {
  const SyncState({
    this.isOnline = false,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.reviewCount = 0,
    this.lastSyncAt,
    this.initialCompleted = false,
    this.apiConfigured = true,
    this.sessionExpired = false,
    this.salesAllowed,
    this.branchWarning,
    this.lastError,
  });

  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;

  /// عمليات رفضها السيرفر وتنتظر مراجعة المستخدم.
  final int reviewCount;

  /// آخر دورة مزامنة اكتملت. الشاشات تعيد التحميل عند تغيّره.
  final DateTime? lastSyncAt;

  /// اكتمل أول تنزيل للبيانات على هذا الجهاز.
  final bool initialCompleted;
  final bool apiConfigured;

  /// السيرفر رفض التوكن (401). الواجهة ترجع لشاشة الدخول.
  final bool sessionExpired;

  /// هل يسمح السيرفر بالبيع في هذا الفرع الآن (null = غير معروف بعد).
  final bool? salesAllowed;
  final String? branchWarning;
  final String? lastError;

  SyncState copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    int? reviewCount,
    DateTime? lastSyncAt,
    bool? initialCompleted,
    bool? apiConfigured,
    bool? sessionExpired,
    bool? salesAllowed,
    String? branchWarning,
    String? lastError,
    bool clearError = false,
  }) => SyncState(
    isOnline: isOnline ?? this.isOnline,
    isSyncing: isSyncing ?? this.isSyncing,
    pendingCount: pendingCount ?? this.pendingCount,
    reviewCount: reviewCount ?? this.reviewCount,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    initialCompleted: initialCompleted ?? this.initialCompleted,
    apiConfigured: apiConfigured ?? this.apiConfigured,
    sessionExpired: sessionExpired ?? this.sessionExpired,
    salesAllowed: salesAllowed ?? this.salesAllowed,
    branchWarning: branchWarning ?? this.branchWarning,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );

  @override
  List<Object?> get props => [
    isOnline,
    isSyncing,
    pendingCount,
    reviewCount,
    lastSyncAt,
    initialCompleted,
    apiConfigured,
    sessionExpired,
    salesAllowed,
    branchWarning,
    lastError,
  ];
}

/// يشغّل المزامنة تلقائيًا: عند عودة الاتصال، وكل [interval]، وعند إضافة عملية جديدة.
class SyncCubit extends Cubit<SyncState> {
  SyncCubit({
    required SyncEngine engine,
    required Outbox outbox,
    required NetworkInfo network,
    required SessionManager session,
    this.interval = const Duration(minutes: 2),
  }) : _engine = engine,
       _outbox = outbox,
       _network = network,
       _session = session,
       super(const SyncState(apiConfigured: ApiConfig.baseUrl != ''));

  final SyncEngine _engine;
  final Outbox _outbox;
  final NetworkInfo _network;
  final SessionManager _session;
  final Duration interval;

  StreamSubscription<bool>? _networkSub;
  StreamSubscription<void>? _outboxSub;
  Timer? _timer;

  Future<void> start() async {
    _networkSub = _network.onStatusChange.listen((online) {
      if (isClosed) return;
      emit(state.copyWith(isOnline: online));
      if (online) unawaited(syncNow());
    });
    _outboxSub = _outbox.changes.listen((_) async {
      await _refreshLocal();
      if (state.isOnline && !_engine.isRunning) unawaited(syncNow());
    });
    _timer = Timer.periodic(interval, (_) {
      if (state.isOnline) unawaited(syncNow());
    });

    final online = await _network.isConnected;
    if (isClosed) return;
    emit(state.copyWith(isOnline: online));
    await _refreshLocal();
    if (state.isOnline) await syncNow();
  }

  Future<void> syncNow({bool force = false}) async {
    if (_engine.isRunning || isClosed || state.sessionExpired) return;
    if (force) await _outbox.wakeUp();
    emit(state.copyWith(isSyncing: true, clearError: true));
    final report = await _engine.run();
    if (isClosed) return;
    emit(
      state.copyWith(
        isSyncing: false,
        lastSyncAt: DateTime.now(),
        isOnline: report?.offline == true ? false : null,
        apiConfigured: report == null ? null : !report.notConfigured,
        sessionExpired: report?.unauthorized,
        lastError: report?.error,
      ),
    );
    await _refreshLocal();
  }

  Future<void> _refreshLocal() async {
    final session = _session.current;
    if (session == null || isClosed) return;
    final counts = await _outbox.counts(userId: session.userId);
    final initial = await _engine.initialSyncCompleted;
    final op = await _engine.operationState();
    if (isClosed) return;
    emit(
      state.copyWith(
        pendingCount: counts.pending,
        reviewCount: counts.review,
        initialCompleted: initial,
        salesAllowed: op?['sales_allowed'] as bool?,
        branchWarning: op?['warning'] as String?,
      ),
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _networkSub?.cancel();
    await _outboxSub?.cancel();
    return super.close();
  }
}

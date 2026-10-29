/// إعدادات الجهاز العامة. الفرع والمستخدم يأتيان من الجلسة (`SessionManager`).
class AppSettings {
  const AppSettings({
    this.deviceName = 'anaqa-mobile',
    this.syncInterval = const Duration(minutes: 2),
    this.maxSyncAttempts = 10,
  });

  /// اسم الجهاز المرسل عند تسجيل الدخول (يظهر كاسم للتوكن في السيرفر).
  final String deviceName;

  /// كل كم تحاول المزامنة تلقائيًا أثناء وجود اتصال.
  final Duration syncInterval;

  /// بعد هذا العدد من المحاولات الفاشلة تُعلَّم العملية "فاشلة" وتنتظر تدخلًا يدويًا.
  final int maxSyncAttempts;
}

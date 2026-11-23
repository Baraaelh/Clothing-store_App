/// إعدادات الجهاز العامة. الفرع والمستخدم يأتيان من الجلسة (`SessionManager`).
class AppSettings {
  const AppSettings({
    this.deviceName = 'هاتف الأناقة الذكي',
    this.syncInterval = const Duration(minutes: 2),
    this.maxSyncAttempts = 10,
  });

  /// اسم الجهاز المرسل عند تسجيل الدخول (يظهر في قائمة أجهزة المستخدم على السيرفر).
  final String deviceName;

  /// كل كم تحاول المزامنة تلقائيًا أثناء وجود اتصال.
  final Duration syncInterval;

  /// بعد هذا العدد من المحاولات الفاشلة تُعلَّم العملية "فاشلة" وتنتظر تدخلًا يدويًا.
  final int maxSyncAttempts;
}

/// إعدادات الجهاز. ثابتة الآن، وتنتقل لاحقًا لشاشة إعدادات أو تأتي من تسجيل الدخول.
class AppSettings {
  const AppSettings({
    required this.branchId,
    required this.cashierName,
    this.syncInterval = const Duration(minutes: 2),
    this.maxSyncAttempts = 10,
  });

  /// الفرع الذي يعمل عليه هذا الجهاز (`branches.id` في السيرفر).
  final int branchId;
  final String cashierName;

  /// كل كم تحاول المزامنة تلقائيًا أثناء وجود اتصال.
  final Duration syncInterval;

  /// بعد هذا العدد من المحاولات الفاشلة تُعلَّم العملية "فاشلة" وتنتظر تدخلًا يدويًا.
  final int maxSyncAttempts;
}

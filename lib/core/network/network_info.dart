import 'package:connectivity_plus/connectivity_plus.dart';

/// حالة الاتصال بالشبكة.
///
/// ملاحظة: وجود Wi-Fi لا يعني أن السيرفر متاح. لذلك المزامنة تتعامل مع
/// فشل الطلب كحالة "لا يوجد اتصال" وتعيد المحاولة لاحقًا.
abstract interface class NetworkInfo {
  Future<bool> get isConnected;

  /// يصدر `true` عند الاتصال و`false` عند الانقطاع.
  Stream<bool> get onStatusChange;
}

class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async => _hasConnection(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged.map(_hasConnection).distinct();

  static bool _hasConnection(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);
}

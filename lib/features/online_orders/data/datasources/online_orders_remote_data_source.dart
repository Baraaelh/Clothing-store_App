import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';

class OnlineOrdersRemoteDataSource {
  OnlineOrdersRemoteDataSource(this._api);

  final ApiClient _api;

  /// TODO(api): عدّل استخراج القائمة حسب شكل الرد.
  Future<List<Map<String, Object?>>> fetchOrders() async {
    final response = await _api.get(ApiEndpoints.onlineOrders);
    final list = switch (response) {
      final List<Object?> l => l,
      final Map<String, Object?> m when m['data'] is List => m['data']! as List<Object?>,
      _ => const <Object?>[],
    };
    return list.cast<Map<String, Object?>>();
  }

  /// TODO(api): عدّل الطريقة (PATCH/POST) وجسم الطلب حسب الـ API.
  Future<void> updateStatus(String orderId, String status) =>
      _api.patch(ApiEndpoints.updateOnlineOrderStatus, pathParams: {'id': orderId}, body: {'status': status});
}

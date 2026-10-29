import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';

class PosRemoteDataSource {
  PosRemoteDataSource(this._api);

  final ApiClient _api;

  /// منتجات الفرع مع الكميات.
  /// TODO(api): عدّل استخراج القائمة حسب شكل الرد (Laravel paginate يضعها في `data`).
  Future<List<Map<String, Object?>>> fetchCatalog(int branchId) async {
    final response = await _api.get(ApiEndpoints.catalog, pathParams: {'branchId': branchId});
    final list = switch (response) {
      final List<Object?> l => l,
      final Map<String, Object?> m when m['data'] is List => m['data']! as List<Object?>,
      _ => const <Object?>[],
    };
    return list.cast<Map<String, Object?>>();
  }

  /// يرسل الفاتورة ويرجع رقمها في السيرفر إن وُجد.
  /// TODO(api): عدّل استخراج المعرف حسب شكل الرد.
  Future<int?> createSale(Map<String, Object?> payload) async {
    final response = await _api.post(ApiEndpoints.createSale, body: payload);
    if (response is Map<String, Object?>) {
      final data = response['data'];
      final id = data is Map<String, Object?> ? data['id'] : response['id'];
      if (id is int) return id;
    }
    return null;
  }
}

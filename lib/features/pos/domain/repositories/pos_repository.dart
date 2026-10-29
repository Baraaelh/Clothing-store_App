import '../../../../core/utils/result.dart';
import '../entities/catalog_item.dart';
import '../entities/checkout_request.dart';
import '../entities/sale.dart';

abstract interface class PosRepository {
  /// المنتجات من النسخة المحلية (تعمل بدون إنترنت).
  Future<Result<List<CatalogItem>>> getCatalog({String query = ''});

  /// يحفظ الفاتورة محليًا ويضيفها لطابور المزامنة. لا يحتاج إنترنت.
  Future<Result<Sale>> createSale(CheckoutRequest request);

  Future<Result<List<Sale>>> getRecentSales({int limit = 20});
}

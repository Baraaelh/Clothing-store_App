import '../../../../core/data/reference_data.dart';
import '../../../../core/utils/result.dart';
import '../entities/catalog_item.dart';
import '../entities/checkout_request.dart';
import '../entities/sale.dart';

abstract interface class PosRepository {
  /// الأصناف المتاحة في الفرع من النسخة المحلية (تعمل بدون إنترنت).
  Future<Result<List<CatalogItem>>> getCatalog({String query = ''});

  Future<Result<List<PaymentAccount>>> getAccounts();

  Future<Result<List<Party>>> searchCustomers(String query);

  /// يحفظ الفاتورة محليًا ويضيفها للـ Outbox. لا يحتاج إنترنت.
  Future<Result<Sale>> createSale(CheckoutRequest request);

  Future<Result<List<Sale>>> getRecentSales({int limit = 50});
}

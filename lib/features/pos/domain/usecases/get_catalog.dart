import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/catalog_item.dart';
import '../repositories/pos_repository.dart';

class GetCatalog implements UseCase<List<CatalogItem>, String> {
  const GetCatalog(this._repository);

  final PosRepository _repository;

  @override
  Future<Result<List<CatalogItem>>> call(String query) => _repository.getCatalog(query: query.trim());
}

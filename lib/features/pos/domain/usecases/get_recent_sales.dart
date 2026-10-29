import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/sale.dart';
import '../repositories/pos_repository.dart';

class GetRecentSales implements UseCase<List<Sale>, NoParams> {
  const GetRecentSales(this._repository);

  final PosRepository _repository;

  @override
  Future<Result<List<Sale>>> call(NoParams params) => _repository.getRecentSales();
}

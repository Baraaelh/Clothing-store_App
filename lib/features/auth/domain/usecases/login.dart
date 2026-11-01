import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/session/session.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../repositories/auth_repository.dart';

class LoginParams extends Equatable {
  const LoginParams({required this.username, required this.password});

  final String username;
  final String password;

  @override
  List<Object?> get props => [username, password];
}

class Login implements UseCase<Session, LoginParams> {
  const Login(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<Session>> call(LoginParams params) {
    final username = params.username.trim();
    if (username.isEmpty) return Future.value(const Err(ValidationFailure('أدخل اسم المستخدم')));
    if (params.password.isEmpty) return Future.value(const Err(ValidationFailure('أدخل كلمة المرور')));
    return _repository.login(username: username, password: params.password);
  }
}

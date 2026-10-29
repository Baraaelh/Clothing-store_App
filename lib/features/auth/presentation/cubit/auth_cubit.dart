import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/session/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// قراءة الجلسة المحفوظة عند فتح التطبيق.
class AuthChecking extends AuthState {
  const AuthChecking();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.submitting = false, this.error, this.sessionExpired = false});

  final bool submitting;
  final String? error;

  /// خرج المستخدم لأن السيرفر رفض التوكن، لا لأنه ضغط "تسجيل الخروج".
  final bool sessionExpired;

  @override
  List<Object?> get props => [submitting, error, sessionExpired];
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  final Session session;

  @override
  List<Object?> get props => [session];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository, this._login) : super(const AuthChecking());

  final AuthRepository _repository;
  final Login _login;

  Future<void> restore() async {
    final session = await _repository.restoreSession();
    emit(session == null ? const AuthUnauthenticated() : AuthAuthenticated(session));
  }

  Future<void> login(String username, String password) async {
    final current = state;
    if (current is AuthUnauthenticated && current.submitting) return;
    emit(const AuthUnauthenticated(submitting: true));
    final result = await _login(LoginParams(username: username, password: password));
    emit(result.fold((f) => AuthUnauthenticated(error: f.message), AuthAuthenticated.new));
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }

  /// السيرفر رد بـ 401 أثناء المزامنة.
  Future<void> sessionExpired() async {
    if (state is! AuthAuthenticated) return;
    await _repository.logout();
    emit(const AuthUnauthenticated(sessionExpired: true));
  }
}

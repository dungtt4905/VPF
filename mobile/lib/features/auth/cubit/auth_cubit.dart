import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/services/sync_service.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  final SyncService _sync;
  AuthCubit(this._repo, this._sync) : super(AuthInitial());

  /// Bật tự động đồng bộ và chạy một vòng ngay (không chặn UI).
  void _startSync() {
    _sync.startAutoSync();
    unawaited(_sync.syncNow());
  }

  Future<void> checkAuthStatus() async {
    final isLogged = await _repo.isLoggedIn();
    if (isLogged) {
      emit(AuthAuthenticated());
      _startSync();
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      await _repo.login(email, password);
      emit(AuthAuthenticated());
      _startSync();
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> register(String email, String password, String name) async {
    emit(AuthLoading());
    try {
      await _repo.register(email, password, name);
      emit(AuthAuthenticated());
      _startSync();
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> logout() async {
    emit(AuthLoading());
    await _repo.logout();
    emit(AuthUnauthenticated());
  }
}

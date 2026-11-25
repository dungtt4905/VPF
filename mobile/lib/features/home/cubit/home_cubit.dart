import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/repositories/transaction_repository.dart';
import '../../../models/transaction_model.dart';

abstract class HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<TransactionModel> transactions;
  HomeLoaded(this.transactions);
}

class HomeCubit extends Cubit<HomeState> {
  final TransactionRepository _repository;
  StreamSubscription? _subscription;

  HomeCubit(this._repository) : super(HomeLoading()) {
    _subscription = _repository.watchAllTransactions().listen((transactions) {
      emit(HomeLoaded(transactions));
    });
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

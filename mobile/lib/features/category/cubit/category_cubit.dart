import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/repositories/category_repository.dart';
import '../../../models/category_model.dart';
import '../../../models/enums.dart';

abstract class CategoryState {}

class CategoryInitial extends CategoryState {}

class CategoryLoaded extends CategoryState {
  final List<CategoryModel> categories;
  CategoryLoaded(this.categories);
}

class CategoryCubit extends Cubit<CategoryState> {
  final CategoryRepository _repository;
  StreamSubscription? _subscription;

  CategoryCubit(this._repository) : super(CategoryInitial()) {
    _subscription = _repository.watchAllCategories().listen((categories) {
      emit(CategoryLoaded(categories));
    });
  }

  Future<void> addCategory(String name, String icon, String color, TransactionType type, {String? parentId}) async {
    final cat = CategoryModel()
      ..syncId = const Uuid().v4()
      ..name = name
      ..icon = icon
      ..color = color
      ..type = type
      ..parentId = parentId;
    await _repository.saveCategory(cat);
  }

  /// Cập nhật category đã có (giữ nguyên id, syncId, createdAt, isPredefined...).
  Future<void> updateCategory(CategoryModel existing,
      {required String name, required String icon, required String color, String? parentId}) async {
    existing
      ..name = name
      ..icon = icon
      ..color = color
      ..parentId = parentId;
    await _repository.saveCategory(existing);
  }

  Future<void> deleteCategory(int id) async {
    await _repository.deleteCategory(id);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

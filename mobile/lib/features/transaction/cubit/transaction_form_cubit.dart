import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/repositories/transaction_repository.dart';
import '../../../core/services/image_storage_service.dart';
import '../../../models/transaction_model.dart';
import '../../../models/enums.dart';

abstract class TransactionFormState {}

class TransactionFormInitial extends TransactionFormState {}

class TransactionFormLoading extends TransactionFormState {}

class TransactionFormSuccess extends TransactionFormState {}

class TransactionFormFailure extends TransactionFormState {
  final String error;
  TransactionFormFailure(this.error);
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  final TransactionRepository _transactionRepo;
  final ImageStorageService _imageService;

  TransactionFormCubit(this._transactionRepo, this._imageService) : super(TransactionFormInitial());

  Future<void> saveTransaction({
    int? id,
    required double amount,
    required String categoryId,
    required String paymentMethod,
    required String? note,
    required TransactionType type,
    required DateTime transactionAt,
    File? rawImageFile,
    String? existingImagePath,
    String? existingThumbnailPath,
    bool removeImage = false,
    String? syncId,
    String? categoryName,
  }) async {
    emit(TransactionFormLoading());
    try {
      String? localFull = removeImage ? null : existingImagePath;
      String? localThumb = removeImage ? null : existingThumbnailPath;

      if (rawImageFile != null) {
        final result = await _imageService.processImageFile(rawImageFile.path);
        if (result != null) {
          localFull = result.$1;
          localThumb = result.$2;
        }
      }

      final trimmedNote = note?.trim() ?? '';
      final title = trimmedNote.isNotEmpty
          ? trimmedNote
          : ((categoryName?.trim().isNotEmpty ?? false) ? categoryName!.trim() : 'Giao dịch');

      final txn = TransactionModel()
        ..amount = amount
        ..categoryId = categoryId
        ..title = title
        ..type = type
        ..paymentMethod = paymentMethod
        ..note = note
        ..localImagePath = localFull
        ..localThumbnailPath = localThumb
        ..transactionAt = transactionAt;

      if (id != null) {
        txn.id = id;
        final original = await _transactionRepo.getById(id);
        if (original != null) {
          txn.createdAt = original.createdAt;
          // Không đổi ảnh -> giữ thông tin ảnh cloud để SyncService không upload lại.
          if (rawImageFile == null && !removeImage) {
            txn.cloudImageUrl = original.cloudImageUrl;
            txn.cloudImageKey = original.cloudImageKey;
          }
        }
      }
      if (syncId != null) {
        txn.syncId = syncId;
      } else {
        txn.syncId = const Uuid().v4();
      }

      await _transactionRepo.saveTransaction(txn);

      // Đổi/xóa ảnh: dọn file ảnh cũ (best-effort, lỗi bỏ qua).
      if (removeImage || rawImageFile != null) {
        for (final old in [existingImagePath, existingThumbnailPath]) {
          if (old == null || old == localFull || old == localThumb) continue;
          try {
            final f = File(old);
            if (f.existsSync()) await f.delete();
          } catch (_) {}
        }
      }
      emit(TransactionFormSuccess());
      // Upload ảnh lên cloud ở nền, không chặn UI; lỗi/offline sẽ được thử lại ở lần sau.
      unawaited(_transactionRepo.uploadPendingImages().catchError((_) {}));
    } catch (e) {
      emit(TransactionFormFailure(e.toString()));
    }
  }

  Future<void> deleteTransaction(int id) async {
    emit(TransactionFormLoading());
    try {
      await _transactionRepo.deleteTransaction(id);
      emit(TransactionFormSuccess());
    } catch (e) {
      emit(TransactionFormFailure(e.toString()));
    }
  }
}

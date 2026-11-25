import 'package:isar/isar.dart';
import '../../models/transaction_model.dart';
import '../services/cloud_image_service.dart';

class TransactionRepository {
  final Isar isar;

  final CloudImageService _cloudImages;
  bool _uploading = false;

  TransactionRepository(this.isar, this._cloudImages);

  Stream<List<TransactionModel>> watchAllTransactions() {
    return isar.transactionModels
        .filter()
        .deletedAtIsNull()
        .sortByTransactionAtDesc()
        .watch(fireImmediately: true);
  }

  Stream<List<TransactionModel>> watchTransactionsByMonth(DateTime date) {
    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 0, 23, 59, 59);

    return isar.transactionModels
        .filter()
        .deletedAtIsNull()
        .and()
        .transactionAtBetween(startOfMonth, endOfMonth)
        .sortByTransactionAtDesc()
        .watch(fireImmediately: true);
  }

  Future<List<TransactionModel>> getAll() => isar.transactionModels.filter().deletedAtIsNull().findAll();

  Future<void> saveTransaction(TransactionModel transaction) async {
    final now = DateTime.now().toUtc();
    transaction.updatedAt = now;
    transaction.isSynced = false;

    if (transaction.id == Isar.autoIncrement) {
      transaction.createdAt = now;
    } else {
      // Sửa: luôn giữ createdAt gốc (tránh LateInitializationError và mất dữ liệu).
      final original = await isar.transactionModels.get(transaction.id);
      if (original != null) {
        transaction.createdAt = original.createdAt;
      } else {
        transaction.createdAt = now;
      }
    }

    await isar.writeTxn(() async {
      await isar.transactionModels.put(transaction);
    });
  }

  /// Upload các ảnh còn nằm ở máy lên cloud. An toàn khi gọi nhiều lần (offline sẽ bỏ qua, lần sau thử lại).
  Future<void> uploadPendingImages() async {
    if (_uploading) return;
    _uploading = true;
    try {
      final pending = await isar.transactionModels
          .filter()
          .deletedAtIsNull()
          .and()
          .localImagePathIsNotNull()
          .and()
          .cloudImageUrlIsNull()
          .findAll();

      for (final t in pending) {
        final uploaded = await _cloudImages.upload(t.localImagePath!);
        if (uploaded == null) continue;

        // Đọc lại bản mới nhất: người dùng có thể đã sửa/xóa giao dịch trong lúc upload.
        final latest = await isar.transactionModels.get(t.id);
        if (latest == null || latest.localImagePath != t.localImagePath || latest.cloudImageUrl != null) continue;
        latest.cloudImageUrl = uploaded.url;
        latest.cloudImageKey = uploaded.key;
        await saveTransaction(latest);
      }
    } finally {
      _uploading = false;
    }
  }

  Future<TransactionModel?> getById(int id) => isar.transactionModels.get(id);

  Future<void> deleteTransaction(int id) => deleteTransactions([id]);

  /// Xóa mềm nhiều giao dịch trong một lần ghi: hoặc xóa được hết, hoặc không xóa gì.
  Future<void> deleteTransactions(Iterable<int> ids) async {
    final idList = ids.toList();
    await isar.writeTxn(() async {
      final now = DateTime.now().toUtc();
      final found = (await isar.transactionModels.getAll(idList))
          .whereType<TransactionModel>()
          .where((t) => t.deletedAt == null)
          .toList();
      for (final t in found) {
        t.deletedAt = now;
        t.updatedAt = now;
        t.isSynced = false;
      }
      await isar.transactionModels.putAll(found);
    });
  }
}

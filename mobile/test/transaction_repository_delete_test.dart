import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/repositories/transaction_repository.dart';
import 'package:mobile/core/services/cloud_image_service.dart';
import 'package:mobile/models/enums.dart';
import 'package:mobile/models/transaction_model.dart';

class _FakeImages implements CloudImageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

TransactionModel _tx(String syncId) => TransactionModel()
  ..syncId = syncId
  ..categoryId = 'food'
  ..title = syncId
  ..amount = 1000
  ..type = TransactionType.expense
  ..paymentMethod = 'CASH'
  ..isSynced = true
  ..transactionAt = DateTime(2026, 11, 10)
  ..createdAt = DateTime(2026, 11, 10)
  ..updatedAt = DateTime(2026, 11, 10);

void main() {
  setUpAll(() => Isar.initializeIsarCore(download: true));

  test('deleteTransactions xóa mềm đúng các id được chọn và đánh dấu cần đồng bộ', () async {
    final dir = await Directory.systemTemp.createTemp('isar_delete_test');
    final isar = await Isar.open([TransactionModelSchema], directory: dir.path, name: 'delete_test');
    addTearDown(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });
    final repo = TransactionRepository(isar, _FakeImages());
    late List<int> ids;
    await isar.writeTxn(() async {
      ids = await isar.transactionModels.putAll([_tx('a'), _tx('b'), _tx('c')]);
    });

    await repo.deleteTransactions([ids[0], ids[2], 9999]);

    expect((await repo.getAll()).map((t) => t.syncId), ['b']);
    final removed = (await repo.getById(ids[0]))!;
    expect(removed.deletedAt, isNotNull);
    expect(removed.isSynced, isFalse);
    expect((await repo.getById(ids[1]))!.isSynced, isTrue);
  });
}

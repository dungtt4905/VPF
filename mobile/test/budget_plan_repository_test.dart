import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/repositories/budget_plan_repository.dart';
import 'package:mobile/core/services/secure_storage_service.dart';
import 'package:mobile/models/budget_category_model.dart';
import 'package:mobile/models/budget_jar_model.dart';
import 'package:mobile/models/budget_plan_model.dart';
import 'package:mobile/models/category_model.dart';
import 'package:mobile/models/enums.dart';
import 'package:mobile/models/transaction_model.dart';

class _FakeStorage implements SecureStorageService {
  @override
  Future<String?> getUserId() async => 'user-1';
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}


CategoryModel _cat(String id, String name, {String? parent}) => CategoryModel()
  ..syncId = id
  ..name = name
  ..parentId = parent
  ..type = TransactionType.expense
  ..createdAt = DateTime(2026, 1, 1)
  ..updatedAt = DateTime(2026, 1, 1);

void main() {
  late Isar isar;
  late Directory dir;
  late BudgetPlanRepository repo;
  final nov = DateTime(2026, 11, 10);
  final dec = DateTime(2026, 12, 3);

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('isar_plan_test');
    isar = await Isar.open(
      [
        TransactionModelSchema,
        CategoryModelSchema,
        BudgetPlanModelSchema,
        BudgetJarModelSchema,
        BudgetCategoryModelSchema,
      ],
      directory: dir.path,
      name: 'test_${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = BudgetPlanRepository(isar, _FakeStorage());
    await isar.writeTxn(() async {
      await isar.categoryModels.put(_cat('needs', 'Thiết yếu'));
      await isar.categoryModels.put(_cat('food', 'Ăn uống', parent: 'needs'));
      await isar.categoryModels.put(_cat('bus', 'Di chuyển', parent: 'needs'));
      await isar.categoryModels.put(_cat('fun', 'Giải trí'));
    });
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });


  Future<BudgetPlanModel> planOf(DateTime month) async => (await repo.planFor(month))!;

  Future<BudgetJarModel> newJar(String name, Set<String> cats, {DateTime? now, double amount = 1000000}) =>
      repo.saveJar(
        name: name,
        amount: amount,
        alertThreshold: 80,
        rollover: false,
        isTotal: false,
        categoryIds: cats,
        now: now ?? nov,
      );

  Future<Set<String>> linkedTo(BudgetJarModel jar) async =>
      (await repo.linksOf(jar.planId)).where((l) => l.jarId == jar.syncId).map((l) => l.categoryId).toSet();

  group('sang tháng mới', () {
    test('sao chép hũ, liên kết danh mục và thu nhập từ kế hoạch gần nhất; đặt lại "đã trả"', () async {
      final rent = await newJar('Tiền nhà', {}, amount: 5000000);
      final food = await newJar('Ăn uống', {'food', 'bus'});
      await repo.setPaid(rent.syncId, true);
      await repo.applyPlan(income: 20000000, amountByJar: {}, now: nov);

      await repo.ensureCurrentPlan(now: dec);

      final decPlan = await planOf(dec);
      expect(decPlan.expectedIncome, 20000000);
      final jars = await repo.jarsOf(decPlan.syncId);
      expect(jars.map((j) => j.jarKey).toSet(), {rent.jarKey, food.jarKey});
      expect(jars.firstWhere((j) => j.jarKey == rent.jarKey).paidAt, isNull);
      final foodDec = jars.firstWhere((j) => j.jarKey == food.jarKey);
      expect(await linkedTo(foodDec), {'food', 'bus'});

      // Kế hoạch tháng 11 giữ nguyên (vẫn đã trả).
      final novRent = (await repo.jarsOf((await planOf(nov)).syncId)).firstWhere((j) => j.jarKey == rent.jarKey);
      expect(novRent.paidAt, isNotNull);
    });

    test('id kế hoạch/hũ xác định: dựng lại trên thiết bị khác ra cùng id', () async {
      await newJar('Ăn uống', {'food'});
      await repo.ensureCurrentPlan(now: dec);
      final planId = (await planOf(dec)).syncId;
      final jarIds = (await repo.jarsOf(planId)).map((j) => j.syncId).toSet();

      await isar.writeTxn(() async {
        await isar.budgetPlanModels.filter().periodStartEqualTo(DateTime(2026, 12, 1)).deleteAll();
        await isar.budgetJarModels.filter().planIdEqualTo(planId).deleteAll();
        await isar.budgetCategoryModels.filter().planIdEqualTo(planId).deleteAll();
      });
      await repo.ensureCurrentPlan(now: dec);
      expect((await planOf(dec)).syncId, planId);
      expect((await repo.jarsOf(planId)).map((j) => j.syncId).toSet(), jarIds);
    });
  });

  group('hũ', () {
    test('tạo hũ nhiều danh mục và hũ cam kết (không danh mục)', () async {
      final food = await newJar('Nhu cầu', {'food', 'bus'});
      final rent = await newJar('Tiền nhà', {}, amount: 5000000);
      expect(await linkedTo(food), {'food', 'bus'});
      expect(await linkedTo(rent), isEmpty);
      expect(food.jarKey, isNot(rent.jarKey));
    });

    test('một danh mục chỉ thuộc một hũ trong kế hoạch: chọn lại sẽ chuyển từ hũ cũ sang', () async {
      final a = await newJar('A', {'food', 'bus'});
      final b = await newJar('B', {'food'});
      expect(await linkedTo(b), {'food'});
      expect(await linkedTo(a), {'bus'});
    });

    test('quan hệ cha/con cũng được tính là trùng: chọn danh mục cha lấy các con khỏi hũ khác', () async {
      final a = await newJar('A', {'food'});
      final b = await newJar('B', {'needs'});
      expect(await linkedTo(a), isEmpty);
      expect(await linkedTo(b), {'needs'});
    });

    test('sửa hũ: đổi danh mục, hạn mức; kế hoạch tháng trước không bị đụng tới', () async {
      final jar = await newJar('Ăn uống', {'food'});
      await repo.ensureCurrentPlan(now: dec);
      final decJar = (await repo.jarsOf((await planOf(dec)).syncId)).single;
      await repo.saveJar(
        jarSyncId: decJar.syncId,
        name: 'Ăn uống',
        amount: 2000000,
        alertThreshold: 90,
        rollover: true,
        isTotal: false,
        categoryIds: {'food', 'fun'},
        now: dec,
      );

      expect(await linkedTo(decJar), {'food', 'fun'});
      final novJar = (await repo.jarsOf((await planOf(nov)).syncId)).single;
      expect(novJar.syncId, jar.syncId);
      expect(novJar.amount, 1000000);
      expect(await linkedTo(novJar), {'food'});
    });

    test('xóa hũ chỉ xóa ở kế hoạch hiện tại, kế hoạch tháng trước giữ nguyên', () async {
      await newJar('Ăn uống', {'food'});
      await repo.ensureCurrentPlan(now: dec);
      final decJar = (await repo.jarsOf((await planOf(dec)).syncId)).single;
      await repo.deleteJar(decJar.syncId);

      expect(await repo.jarsOf((await planOf(dec)).syncId), isEmpty);
      expect(await repo.linksOf((await planOf(dec)).syncId), isEmpty);
      expect(await repo.jarsOf((await planOf(nov)).syncId), hasLength(1));
      expect(await repo.linksOf((await planOf(nov)).syncId), hasLength(1));
    });

    test('đánh dấu đã trả / bỏ đánh dấu', () async {
      final rent = await newJar('Tiền nhà', {}, amount: 5000000);
      await repo.setPaid(rent.syncId, true);
      expect((await isar.budgetJarModels.getBySyncId(rent.syncId))!.paidAt, isNotNull);
      await repo.setPaid(rent.syncId, false);
      expect((await isar.budgetJarModels.getBySyncId(rent.syncId))!.paidAt, isNull);
    });

    test('đổi hũ cam kết thành hũ có danh mục thì xóa trạng thái đã trả', () async {
      final rent = await newJar('Tiền nhà', {}, amount: 5000000);
      await repo.setPaid(rent.syncId, true);
      await repo.moveCategory('fun', rent.syncId);
      final after = (await isar.budgetJarModels.getBySyncId(rent.syncId))!;
      expect(after.paidAt, isNull);
      expect(await linkedTo(after), {'fun'});
    });

    test('moveCategory lấy danh mục khỏi hũ cũ', () async {
      final a = await newJar('A', {'fun'});
      final b = await newJar('B', {'bus'});
      await repo.moveCategory('fun', b.syncId);
      expect(await linkedTo(a), isEmpty);
      expect(await linkedTo(b), {'bus', 'fun'});
    });
  });

  group('kế hoạch tháng', () {
    test('applyPlan lưu thu nhập và chỉ ghi hũ có thay đổi', () async {
      final a = await newJar('A', {'fun'}, amount: 1000000);
      final b = await newJar('B', {'bus'}, amount: 2000000);
      await isar.writeTxn(() async {
        for (final j in await isar.budgetJarModels.where().findAll()) {
          await isar.budgetJarModels.put(j..isSynced = true);
        }
      });

      await repo.applyPlan(income: 15000000, amountByJar: {a.syncId: 1500000, b.syncId: 2000000}, now: nov);

      expect((await planOf(nov)).expectedIncome, 15000000);
      final ja = (await isar.budgetJarModels.getBySyncId(a.syncId))!;
      final jb = (await isar.budgetJarModels.getBySyncId(b.syncId))!;
      expect(ja.amount, 1500000);
      expect(ja.isSynced, isFalse);
      expect(jb.isSynced, isTrue); // không đổi -> không phải đồng bộ lại
    });

    test('currentSpecs tự tạo kế hoạch cho tháng mới và dựng spec theo hũ', () async {
      await newJar('Ăn uống', {'food', 'bus'});
      final specs = await repo.currentSpecs(now: dec);
      expect(specs, hasLength(1));
      expect(specs.single.categoryIds, {'food', 'bus'});
      expect(specs.single.history.keys, [DateTime(2026, 11, 1)]);
    });
  });
}

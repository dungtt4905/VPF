import 'package:isar/isar.dart';
import '../../models/category_model.dart';
import '../../models/enums.dart';
import '../../models/transaction_model.dart';

class CategoryRepository {
  final Isar isar;

  CategoryRepository(this.isar);

  /// UUID v4 cố định cho danh mục mặc định (giống nhau trên mọi thiết bị).
  static const String idNeeds = '6f1c2a10-3b4d-4e5f-8a01-0d1e2f3a4b01';
  static const String idWants = '6f1c2a10-3b4d-4e5f-8a02-0d1e2f3a4b02';
  static const String idSavings = '6f1c2a10-3b4d-4e5f-8a03-0d1e2f3a4b03';
  static const String idIncome = '6f1c2a10-3b4d-4e5f-8a04-0d1e2f3a4b04';
  static const String idFood = '6f1c2a10-3b4d-4e5f-8b01-0d1e2f3a4c01';
  static const String idTransport = '6f1c2a10-3b4d-4e5f-8b02-0d1e2f3a4c02';
  static const String idBills = '6f1c2a10-3b4d-4e5f-8b03-0d1e2f3a4c03';
  static const String idShopping = '6f1c2a10-3b4d-4e5f-8b04-0d1e2f3a4c04';
  static const String idEntertainment = '6f1c2a10-3b4d-4e5f-8b05-0d1e2f3a4c05';
  static const String idEmergency = '6f1c2a10-3b4d-4e5f-8b06-0d1e2f3a4c06';
  static const String idInvest = '6f1c2a10-3b4d-4e5f-8b07-0d1e2f3a4c07';
  static const String idSalary = '6f1c2a10-3b4d-4e5f-8b08-0d1e2f3a4c08';

  Stream<List<CategoryModel>> watchAllCategories() {
    return isar.categoryModels.filter().deletedAtIsNull().watch(fireImmediately: true);
  }

  Future<List<CategoryModel>> getAll() => isar.categoryModels.filter().deletedAtIsNull().findAll();

  Future<void> saveCategory(CategoryModel category) async {
    final now = DateTime.now().toUtc();
    category.updatedAt = now;
    category.isSynced = false;

    if (category.id == Isar.autoIncrement) {
      category.createdAt = now;
    }

    await isar.writeTxn(() async {
      await isar.categoryModels.put(category);
    });
  }

  Future<CategoryModel?> getById(int id) => isar.categoryModels.get(id);

  Future<void> deleteCategory(int id) async {
    final category = await isar.categoryModels.get(id);
    if (category != null) {
      final now = DateTime.now().toUtc();
      category.deletedAt = now;
      category.updatedAt = now;
      category.isSynced = false;
      await isar.writeTxn(() async {
        await isar.categoryModels.put(category);
      });
    }
  }

  Future<void> seedDefaultCategories() async {
    final now = DateTime.now().toUtc();

    CategoryModel c(String syncId, String name, String icon, String color, TransactionType type,
        {String? parentId}) {
      return CategoryModel()
        ..syncId = syncId
        ..name = name
        ..icon = icon
        ..color = color
        ..type = type
        ..isPredefined = true
        ..parentId = parentId
        ..isSynced = false
        ..createdAt = now
        ..updatedAt = now;
    }

    final defaults = [
      c(idNeeds, 'Thiết yếu', 'home', '#FF5722', TransactionType.expense),
      c(idWants, 'Mong muốn', 'star', '#E91E63', TransactionType.expense),
      c(idSavings, 'Tiết kiệm/Đầu tư', 'savings', '#4CAF50', TransactionType.expense),
      c(idIncome, 'Thu nhập', 'attach_money', '#009688', TransactionType.income),
      c(idFood, 'Ăn uống', 'restaurant', '#FF9800', TransactionType.expense, parentId: idNeeds),
      c(idTransport, 'Di chuyển', 'directions_car', '#2196F3', TransactionType.expense, parentId: idNeeds),
      c(idBills, 'Nhà cửa/Hóa đơn', 'receipt', '#795548', TransactionType.expense, parentId: idNeeds),
      c(idShopping, 'Mua sắm', 'shopping_bag', '#9C27B0', TransactionType.expense, parentId: idWants),
      c(idEntertainment, 'Giải trí', 'movie', '#673AB7', TransactionType.expense, parentId: idWants),
      c(idEmergency, 'Quỹ dự phòng', 'security', '#8BC34A', TransactionType.expense, parentId: idSavings),
      c(idInvest, 'Đầu tư', 'trending_up', '#3F51B5', TransactionType.expense, parentId: idSavings),
      c(idSalary, 'Lương', 'account_balance_wallet', '#009688', TransactionType.income, parentId: idIncome),
    ];

    await isar.writeTxn(() async {
      for (final cat in defaults) {
        // Đã có (seed trước đó hoặc đã sync về từ server) -> bỏ qua, tránh nhân đôi.
        final existing = await isar.categoryModels.getBySyncId(cat.syncId);
        if (existing != null) continue;
        await isar.categoryModels.put(cat);
      }
    });

    await _cleanupLegacySeeds(defaults);
    await _migrateNameBasedCategoryIds();
  }

  /// Ánh xạ tên danh mục hardcode cũ (từ các màn Add/Edit trước đây) -> UUID cố định.
  static const Map<String, String> legacyNameToId = {
    'Food': idFood,
    'Food > Fast food': idFood,
    'Food > Restaurants': idFood,
    'Food > Drinks': idFood,
    'Transport': idTransport,
    'Transport > Taxi': idTransport,
    'Shopping': idShopping,
    'Shopping > Clothes': idShopping,
    'Entertainment > Movies': idEntertainment,
    'Bills': idBills,
    'Bills > Electricity': idBills,
  };

  /// Chuyển giao dịch cũ có categoryId là tên (vd "Food") sang UUID. Idempotent.
  Future<void> _migrateNameBasedCategoryIds() async {
    final now = DateTime.now().toUtc();
    await isar.writeTxn(() async {
      for (final entry in legacyNameToId.entries) {
        final txns = await isar.transactionModels.filter().categoryIdEqualTo(entry.key).findAll();
        if (txns.isEmpty) continue;
        for (final t in txns) {
          t.categoryId = entry.value;
          t.updatedAt = now;
          t.isSynced = false;
        }
        await isar.transactionModels.putAll(txns);
      }
    });
  }

  /// Dọn các danh mục mặc định cũ (seed bằng UUID ngẫu nhiên): chuyển giao dịch và
  /// danh mục con sang UUID cố định tương ứng (khớp theo tên + loại), rồi soft-delete
  /// bản cũ để việc xóa được sync lên server. Idempotent.
  Future<void> _cleanupLegacySeeds(List<CategoryModel> defaults) async {
    final fixedIds = defaults.map((d) => d.syncId).toSet();
    final newByKey = {for (final d in defaults) '${d.type.name}|${d.name}': d.syncId};
    final now = DateTime.now().toUtc();

    await isar.writeTxn(() async {
      final legacy = await isar.categoryModels
          .filter()
          .isPredefinedEqualTo(true)
          .deletedAtIsNull()
          .findAll();

      for (final old in legacy) {
        if (fixedIds.contains(old.syncId)) continue;
        final newId = newByKey['${old.type.name}|${old.name}'];

        if (newId != null) {
          final txns = await isar.transactionModels.filter().categoryIdEqualTo(old.syncId).findAll();
          for (final t in txns) {
            t.categoryId = newId;
            t.updatedAt = now;
            t.isSynced = false;
          }
          await isar.transactionModels.putAll(txns);

          final children = await isar.categoryModels.filter().parentIdEqualTo(old.syncId).findAll();
          for (final ch in children) {
            ch.parentId = newId;
            ch.updatedAt = now;
            ch.isSynced = false;
          }
          await isar.categoryModels.putAll(children);
        }

        old
          ..deletedAt = now
          ..updatedAt = now
          ..isSynced = false;
        await isar.categoryModels.put(old);
      }
    });
  }
}

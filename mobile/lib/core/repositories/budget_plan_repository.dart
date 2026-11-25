import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../../models/budget_category_model.dart';
import '../../models/budget_jar_model.dart';
import '../../models/budget_plan_model.dart';
import '../../models/category_model.dart';
import '../budget/budget_spec.dart';
import '../services/secure_storage_service.dart';

/// Kế hoạch ngân sách theo tháng: mỗi tháng một [BudgetPlanModel], chứa các hũ ([BudgetJarModel]); mỗi hũ có thể
/// gắn nhiều danh mục qua [BudgetCategoryModel]. Đây là nguồn dữ liệu duy nhất của ngân sách.
class BudgetPlanRepository {
  final Isar isar;
  final SecureStorageService _storage;

  BudgetPlanRepository(this.isar, this._storage);

  static const _uuid = Uuid();

  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime nextMonthStart(DateTime d) => DateTime(d.year, d.month + 1, 1);

  // Id xác định (uuid v5) từ userId + nội dung: hai thiết bị cùng tạo "kế hoạch tháng 11" hay cùng sao chép một hũ
  // sang tháng mới sẽ ra cùng một id, nên đồng bộ gộp lại thay vì nhân đôi.
  String _planId(String user, DateTime start) =>
      _uuid.v5(Namespace.url.value, 'vpf/$user/plan/${start.year}-${start.month}');
  String _jarId(String planId, String jarKey) => _uuid.v5(Namespace.url.value, 'vpf/jar/$planId/$jarKey');
  String _linkId(String jarId, String categoryId) => _uuid.v5(Namespace.url.value, 'vpf/link/$jarId/$categoryId');

  Future<String> _user() async => await _storage.getUserId() ?? 'local';

  // ---- đọc ----

  Stream<List<BudgetPlanModel>> watchPlans() =>
      isar.budgetPlanModels.filter().deletedAtIsNull().watch(fireImmediately: true);
  Stream<List<BudgetJarModel>> watchJars() =>
      isar.budgetJarModels.filter().deletedAtIsNull().watch(fireImmediately: true);
  Stream<List<BudgetCategoryModel>> watchLinks() =>
      isar.budgetCategoryModels.filter().deletedAtIsNull().watch(fireImmediately: true);

  Future<BudgetPlanModel?> planFor(DateTime month) =>
      isar.budgetPlanModels.filter().deletedAtIsNull().periodStartEqualTo(monthStart(month)).findFirst();

  Future<List<BudgetJarModel>> jarsOf(String planId) =>
      isar.budgetJarModels.filter().planIdEqualTo(planId).deletedAtIsNull().findAll();

  Future<List<BudgetCategoryModel>> linksOf(String planId) =>
      isar.budgetCategoryModels.filter().planIdEqualTo(planId).deletedAtIsNull().findAll();

  /// Cấu hình tính toán của các hũ trong kế hoạch tháng chứa [now] (tự tạo kế hoạch nếu tháng mới chưa có).
  Future<List<BudgetSpec>> currentSpecs({DateTime? now}) async {
    final at = now ?? DateTime.now();
    if (await planFor(at) == null) await ensureCurrentPlan(now: at);
    return BudgetSpec.fromJars(
      plans: await isar.budgetPlanModels.filter().deletedAtIsNull().findAll(),
      jars: await isar.budgetJarModels.filter().deletedAtIsNull().findAll(),
      links: await isar.budgetCategoryModels.filter().deletedAtIsNull().findAll(),
      now: at,
    );
  }

  // ---- khởi tạo / sang tháng mới ----

  /// Bảo đảm có kế hoạch cho tháng chứa [now]: tháng mới thì sao chép từ kế hoạch gần nhất (các hũ, liên kết danh
  /// mục, thu nhập dự kiến; trạng thái "đã trả" được đặt lại). Idempotent; gọi lúc khởi động, khi mở màn ngân sách
  /// và sau mỗi lần kéo dữ liệu về.
  Future<void> ensureCurrentPlan({DateTime? now}) async {
    final user = await _user();
    final month = monthStart(now ?? DateTime.now());
    await isar.writeTxn(() => _ensurePlan(user, month));
  }

  Future<BudgetPlanModel> _ensurePlan(String user, DateTime month) async {
    final existing = await isar.budgetPlanModels.filter().periodStartEqualTo(month).deletedAtIsNull().findFirst();
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    final prev =
        await isar.budgetPlanModels.filter().deletedAtIsNull().periodStartLessThan(month).sortByPeriodStartDesc().findFirst();
    final plan = BudgetPlanModel()
      ..syncId = _planId(user, month)
      ..periodStart = month
      ..periodEnd = nextMonthStart(month)
      ..expectedIncome = prev?.expectedIncome ?? 0
      ..createdAt = now
      ..updatedAt = now;
    await isar.budgetPlanModels.put(plan);

    if (prev != null) {
      final jars = await isar.budgetJarModels.filter().planIdEqualTo(prev.syncId).deletedAtIsNull().findAll();
      for (final j in jars) {
        final copy = BudgetJarModel()
          ..syncId = _jarId(plan.syncId, j.jarKey)
          ..planId = plan.syncId
          ..jarKey = j.jarKey
          ..name = j.name
          ..amount = j.amount
          ..alertThreshold = j.alertThreshold
          ..rollover = j.rollover
          ..isTotal = j.isTotal
          ..createdAt = now
          ..updatedAt = now;
        await isar.budgetJarModels.put(copy);
        final links = await isar.budgetCategoryModels.filter().jarIdEqualTo(j.syncId).deletedAtIsNull().findAll();
        for (final l in links) {
          await isar.budgetCategoryModels.put(BudgetCategoryModel()
            ..syncId = _linkId(copy.syncId, l.categoryId)
            ..jarId = copy.syncId
            ..planId = plan.syncId
            ..categoryId = l.categoryId
            ..categoryName = l.categoryName
            ..createdAt = now
            ..updatedAt = now);
        }
      }
    }
    return plan;
  }

  // ---- ghi ----

  /// Tạo hũ mới (jarSyncId == null) hoặc sửa hũ của kế hoạch tháng hiện tại. Các kế hoạch cũ không bị đụng tới.
  /// Danh mục đã nằm ở hũ khác trong kế hoạch (kể cả quan hệ cha/con) sẽ được chuyển sang hũ này.
  Future<BudgetJarModel> saveJar({
    String? jarSyncId,
    required String name,
    required double amount,
    required int alertThreshold,
    required bool rollover,
    required bool isTotal,
    required Set<String> categoryIds,
    DateTime? now,
  }) async {
    final user = await _user();
    final month = monthStart(now ?? DateTime.now());
    final catMap = {for (final c in await isar.categoryModels.where().findAll()) c.syncId: c};
    return isar.writeTxn(() async {
      final plan = await _ensurePlan(user, month);
      final stamp = DateTime.now().toUtc();
      var jar = jarSyncId == null ? null : await isar.budgetJarModels.getBySyncId(jarSyncId);
      if (jar == null) {
        final key = _uuid.v4();
        jar = BudgetJarModel()
          ..syncId = _jarId(plan.syncId, key)
          ..planId = plan.syncId
          ..jarKey = key
          ..createdAt = stamp;
      }
      jar
        ..name = name.trim()
        ..amount = amount
        ..alertThreshold = alertThreshold
        ..rollover = rollover
        ..isTotal = isTotal
        ..deletedAt = null
        ..updatedAt = stamp
        ..isSynced = false;
      // Đổi sang hũ có danh mục thì không còn "đã trả" thủ công.
      if (isTotal || categoryIds.isNotEmpty) jar.paidAt = null;
      await isar.budgetJarModels.put(jar);
      await _applyLinks(plan, jar, isTotal ? <String>{} : categoryIds, catMap);
      return jar;
    });
  }

  /// Chuyển một danh mục vào hũ [jarSyncId] (lấy khỏi hũ khác nếu đang ở đó).
  Future<void> moveCategory(String categoryId, String jarSyncId) async {
    final catMap = {for (final c in await isar.categoryModels.where().findAll()) c.syncId: c};
    await isar.writeTxn(() async {
      final jar = await isar.budgetJarModels.getBySyncId(jarSyncId);
      if (jar == null || jar.deletedAt != null) return;
      final plan = await isar.budgetPlanModels.getBySyncId(jar.planId);
      if (plan == null) return;
      final own = await isar.budgetCategoryModels.filter().jarIdEqualTo(jar.syncId).deletedAtIsNull().findAll();
      await _applyLinks(plan, jar, {...own.map((l) => l.categoryId), categoryId}, catMap);
      jar
        ..paidAt = null
        ..updatedAt = DateTime.now().toUtc()
        ..isSynced = false;
      await isar.budgetJarModels.put(jar);
    });
  }

  /// Xóa hũ (và liên kết danh mục của nó) khỏi kế hoạch hiện tại. Các kế hoạch cũ giữ nguyên.
  Future<void> deleteJar(String jarSyncId) async {
    await isar.writeTxn(() async {
      final jar = await isar.budgetJarModels.getBySyncId(jarSyncId);
      if (jar != null && jar.deletedAt == null) await _removeJar(jar);
    });
  }

  /// Đánh dấu hũ cam kết (tiền nhà, trả nợ) đã trả hoặc chưa trả trong kỳ hiện tại.
  Future<void> setPaid(String jarSyncId, bool paid) async {
    await isar.writeTxn(() async {
      final jar = await isar.budgetJarModels.getBySyncId(jarSyncId);
      if (jar == null) return;
      final now = DateTime.now().toUtc();
      jar
        ..paidAt = paid ? now : null
        ..updatedAt = now
        ..isSynced = false;
      await isar.budgetJarModels.put(jar);
    });
  }

  /// Lưu kế hoạch tháng: thu nhập dự kiến và hạn mức của các hũ (chỉ ghi hũ có thay đổi).
  Future<void> applyPlan({required double income, required Map<String, double> amountByJar, DateTime? now}) async {
    final user = await _user();
    final month = monthStart(now ?? DateTime.now());
    await isar.writeTxn(() async {
      final plan = await _ensurePlan(user, month);
      final stamp = DateTime.now().toUtc();
      if (income > 0 && plan.expectedIncome != income) {
        plan
          ..expectedIncome = income
          ..updatedAt = stamp
          ..isSynced = false;
        await isar.budgetPlanModels.put(plan);
      }
      for (final e in amountByJar.entries) {
        final jar = await isar.budgetJarModels.getBySyncId(e.key);
        if (jar == null || jar.deletedAt != null || jar.amount == e.value || e.value <= 0) continue;
        jar
          ..amount = e.value
          ..updatedAt = stamp
          ..isSynced = false;
        await isar.budgetJarModels.put(jar);
      }
    });
  }

  // ---- bên trong writeTxn ----

  static bool _overlaps(Map<String, CategoryModel> catMap, String a, String b) {
    if (a == b) return true;
    bool isAncestor(String ancestor, String of) {
      final seen = <String>{};
      String? cur = catMap[of]?.parentId;
      while (cur != null && seen.add(cur)) {
        if (cur == ancestor) return true;
        cur = catMap[cur]?.parentId;
      }
      return false;
    }

    return isAncestor(a, b) || isAncestor(b, a);
  }

  /// Đặt danh sách danh mục của hũ đúng bằng [ids]; lấy các danh mục đó (và danh mục cha/con của chúng) khỏi hũ khác.
  Future<void> _applyLinks(
    BudgetPlanModel plan,
    BudgetJarModel jar,
    Set<String> ids,
    Map<String, CategoryModel> catMap,
  ) async {
    final now = DateTime.now().toUtc();
    final planLinks = await isar.budgetCategoryModels.filter().planIdEqualTo(plan.syncId).deletedAtIsNull().findAll();

    for (final l in planLinks) {
      if (l.jarId == jar.syncId) {
        if (!ids.contains(l.categoryId)) await _softDeleteLink(l, now);
      } else if (ids.any((id) => _overlaps(catMap, id, l.categoryId))) {
        await _softDeleteLink(l, now);
      }
    }

    final have = planLinks.where((l) => l.jarId == jar.syncId).map((l) => l.categoryId).toSet();
    for (final id in ids) {
      if (have.contains(id)) continue;
      final linkId = _linkId(jar.syncId, id);
      final name = catMap[id]?.name ?? 'Danh mục đã xóa';
      final link = await isar.budgetCategoryModels.getBySyncId(linkId);
      if (link == null) {
        await isar.budgetCategoryModels.put(BudgetCategoryModel()
          ..syncId = linkId
          ..jarId = jar.syncId
          ..planId = plan.syncId
          ..categoryId = id
          ..categoryName = name
          ..createdAt = now
          ..updatedAt = now);
      } else {
        link
          ..categoryName = name
          ..deletedAt = null
          ..updatedAt = now
          ..isSynced = false;
        await isar.budgetCategoryModels.put(link);
      }
    }
  }

  Future<void> _removeJar(BudgetJarModel j) async {
    final now = DateTime.now().toUtc();
    final links = await isar.budgetCategoryModels.filter().jarIdEqualTo(j.syncId).deletedAtIsNull().findAll();
    for (final l in links) {
      await _softDeleteLink(l, now);
    }
    j
      ..deletedAt = now
      ..updatedAt = now
      ..isSynced = false;
    await isar.budgetJarModels.put(j);
  }

  Future<void> _softDeleteLink(BudgetCategoryModel l, DateTime now) async {
    l
      ..deletedAt = now
      ..updatedAt = now
      ..isSynced = false;
    await isar.budgetCategoryModels.put(l);
  }
}

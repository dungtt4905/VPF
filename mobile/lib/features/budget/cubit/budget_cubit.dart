import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import '../../../core/budget/budget_progress.dart';
import '../../../core/budget/budget_spec.dart';
import '../../../core/repositories/budget_plan_repository.dart';
import '../../../core/repositories/category_repository.dart';
import '../../../core/repositories/transaction_repository.dart';
import '../../../models/budget_category_model.dart';
import '../../../models/budget_jar_model.dart';
import '../../../models/budget_plan_model.dart';
import '../../../models/category_model.dart';
import '../../../models/enums.dart';
import '../../../models/transaction_model.dart';

/// Một hũ ngân sách của kế hoạch tháng hiện tại cùng tiến độ và lịch sử.
class BudgetData {
  final BudgetJarModel jar;
  final BudgetSpec spec;
  final BudgetProgress progress;

  /// Các danh mục của hũ (rỗng với hũ tổng và hũ cam kết).
  final List<CategoryModel> categories;

  /// Kết quả các kỳ đã kết thúc (cũ -> mới, tối đa [BudgetCalc.maxLookback] kỳ).
  final List<BudgetPeriodResult> history;

  BudgetData(this.jar, this.spec, this.progress, this.categories, [this.history = const []]);

  String get name => jar.name;
  bool get isTotal => jar.isTotal;

  /// Hũ cam kết (tiền nhà, trả nợ): không gắn danh mục, chỉ có đã trả / chưa trả.
  bool get commitment => spec.commitment;
  bool get paid => jar.paidAt != null;

  double get usedAmount => progress.used;

  /// Số kỳ liên tiếp gần nhất giữ được ngân sách.
  int get streak => BudgetCalc.streak(history);
}

/// Chi tiêu của một danh mục trong tháng nhưng chưa thuộc hũ nào.
class UnassignedSpend {
  final CategoryModel category;
  final double amount;
  const UnassignedSpend(this.category, this.amount);
}

abstract class BudgetState {}

class BudgetLoading extends BudgetState {}

class BudgetLoaded extends BudgetState {
  final List<BudgetData> budgets;
  final double totalBudget;
  final double totalSpent;

  /// Tiến độ của thẻ "Tổng ngân sách"; null khi chưa có hũ nào.
  final BudgetProgress? totalProgress;
  final List<CategoryModel> expenseCategories;

  /// Chi tiêu tháng này chưa thuộc hũ nào, nhiều nhất lên đầu (rỗng nếu chưa có hũ hoặc có hũ tổng).
  final List<UnassignedSpend> unassigned;

  /// Thu nhập dự kiến của kế hoạch tháng này (0 = chưa nhập).
  final double expectedIncome;

  /// categoryId -> hũ (syncId, tên) đang chứa danh mục đó trong kế hoạch hiện tại.
  final Map<String, ({String jarId, String jarName})> owners;

  BudgetLoaded(
    this.budgets,
    this.totalBudget,
    this.totalSpent,
    this.totalProgress,
    this.expenseCategories, {
    this.unassigned = const [],
    this.expectedIncome = 0,
    this.owners = const {},
  });

  double get unassignedTotal => unassigned.fold(0.0, (s, u) => s + u.amount);
}

class BudgetCubit extends Cubit<BudgetState> {
  final TransactionRepository _txRepo;
  final CategoryRepository _catRepo;
  final BudgetPlanRepository _planRepo;
  StreamSubscription? _subscription;

  BudgetCubit(this._txRepo, this._catRepo, this._planRepo) : super(BudgetLoading()) {
    _init();
  }

  Future<void> _init() async {
    // Tháng mới: sao chép kế hoạch tháng trước trước khi hiển thị (idempotent).
    await _planRepo.ensureCurrentPlan();
    if (isClosed) return;
    _subscription = CombineLatestStream.list<dynamic>([
      _txRepo.watchAllTransactions(),
      _catRepo.watchAllCategories(),
      _planRepo.watchPlans(),
      _planRepo.watchJars(),
      _planRepo.watchLinks(),
    ]).listen((v) {
      emit(_calculate(
        (v[0] as List).cast<TransactionModel>(),
        (v[1] as List).cast<CategoryModel>(),
        (v[2] as List).cast<BudgetPlanModel>(),
        (v[3] as List).cast<BudgetJarModel>(),
        (v[4] as List).cast<BudgetCategoryModel>(),
      ));
    });
  }

  BudgetLoaded _calculate(
    List<TransactionModel> txs,
    List<CategoryModel> cats,
    List<BudgetPlanModel> plans,
    List<BudgetJarModel> jars,
    List<BudgetCategoryModel> links,
  ) {
    final now = DateTime.now();
    final catMap = {for (var c in cats) c.syncId: c};
    final expenseCats = cats.where((c) => c.type == TransactionType.expense).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final specs = BudgetSpec.fromJars(plans: plans, jars: jars, links: links, now: now);
    final currentStart = DateTime(now.year, now.month, 1);
    final plan = plans.where((p) => p.periodStart == currentStart).firstOrNull;
    final jarByKey = {
      for (final j in jars)
        if (plan != null && j.planId == plan.syncId) j.jarKey: j,
    };

    double grandTotalBudget = 0;
    double grandTotalSpent = 0;
    final budgetDataList = <BudgetData>[];
    final owners = <String, ({String jarId, String jarName})>{};

    for (final spec in specs) {
      final jar = jarByKey[spec.key]!;
      // Tiến độ luôn tính theo chu kỳ hiện tại, biên nửa mở [start, end).
      final progress = BudgetCalc.progress(spec, txs, catMap, now);
      final history = BudgetCalc.pastResults(spec, txs, catMap, now);
      final ids = spec.categoryIds ?? const <String>{};
      for (final id in ids) {
        owners[id] = (jarId: jar.syncId, jarName: jar.name);
      }
      budgetDataList.add(BudgetData(
        jar,
        spec,
        progress,
        [for (final id in ids) if (catMap[id] != null) catMap[id]!],
        history,
      ));
    }
    budgetDataList.sort((a, b) => a.jar.createdAt.compareTo(b.jar.createdAt));

    // Tổng toàn cục chỉ cộng hũ "tổng" nếu có, tránh đếm trùng khi có cả hũ tổng và hũ theo danh mục.
    final totalJars = budgetDataList.where((d) => d.isTotal).toList();
    final counted = totalJars.isNotEmpty ? totalJars : budgetDataList;
    for (var d in counted) {
      grandTotalBudget += d.progress.limit; // hạn mức hiệu lực (đã gồm số dư chuyển kỳ)
      grandTotalSpent += d.usedAmount;
    }

    BudgetProgress? totalProgress;
    if (counted.isNotEmpty) {
      final (start, end) = BudgetCalc.periodWindow(BudgetPeriod.monthly, now);
      totalProgress = BudgetProgress(
        used: grandTotalSpent,
        limit: grandTotalBudget,
        threshold: totalJars.length == 1 ? totalJars.first.spec.alertThreshold : 80,
        start: start,
        end: end,
        now: now,
      );
    }

    // Chi tiêu tháng này chưa vào hũ nào (chỉ khi đã có hũ và không có hũ tổng).
    final unassigned = <UnassignedSpend>[];
    if (budgetDataList.isNotEmpty && totalJars.isEmpty) {
      final covered = {for (final d in budgetDataList) ...?d.spec.categoryIds};
      final (start, end) = BudgetCalc.periodWindow(BudgetPeriod.monthly, now);
      final byCat = <String, double>{};
      for (final t in txs) {
        if (t.type != TransactionType.expense || !BudgetCalc.inWindow(t.transactionAt, start, end)) continue;
        final id = catMap.containsKey(t.categoryId)
            ? t.categoryId
            : (CategoryRepository.legacyNameToId[t.categoryId] ?? t.categoryId);
        if (!catMap.containsKey(id)) continue;
        if (covered.any((c) => BudgetCalc.belongsTo(id, c, catMap))) continue;
        byCat[id] = (byCat[id] ?? 0) + t.amount;
      }
      unassigned.addAll([for (final e in byCat.entries) UnassignedSpend(catMap[e.key]!, e.value)]
        ..sort((a, b) => b.amount.compareTo(a.amount)));
    }

    return BudgetLoaded(
      budgetDataList,
      grandTotalBudget,
      grandTotalSpent,
      totalProgress,
      expenseCats,
      unassigned: unassigned,
      expectedIncome: plan?.expectedIncome ?? 0,
      owners: owners,
    );
  }

  /// Tạo hũ mới (editing == null) hoặc sửa hũ của kế hoạch tháng này. `isTotal` = hũ tổng (mọi khoản chi).
  /// Hũ không có danh mục (và không phải hũ tổng) là hũ cam kết.
  Future<void> saveJar({
    BudgetJarModel? editing,
    required String name,
    required double amount,
    required int alertThreshold,
    required bool rollover,
    required bool isTotal,
    required Set<String> categoryIds,
  }) async {
    final isNew = editing == null;
    await _planRepo.saveJar(
      jarSyncId: editing?.syncId,
      name: name,
      amount: amount,
      alertThreshold: alertThreshold,
      rollover: rollover,
      isTotal: isTotal,
      categoryIds: categoryIds,
    );
  }

  Future<void> deleteJar(String jarSyncId) => _planRepo.deleteJar(jarSyncId);

  Future<void> setPaid(String jarSyncId, bool paid) => _planRepo.setPaid(jarSyncId, paid);

  /// Xếp một danh mục (đang chưa thuộc hũ nào) vào hũ [jarSyncId].
  Future<void> moveCategory(String categoryId, String jarSyncId) => _planRepo.moveCategory(categoryId, jarSyncId);

  /// Lưu kế hoạch tháng: thu nhập dự kiến và hạn mức mới của các hũ (theo syncId của hũ).
  Future<void> applyPlan({required double income, required Map<String, double> amountByJar}) =>
      _planRepo.applyPlan(income: income, amountByJar: amountByJar);

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

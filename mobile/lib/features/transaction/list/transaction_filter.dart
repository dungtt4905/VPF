import '../../../core/repositories/category_repository.dart';
import '../../../models/budget_category_model.dart';
import '../../../models/budget_jar_model.dart';
import '../../../models/budget_plan_model.dart';
import '../../../models/enums.dart';
import '../../../models/transaction_model.dart';

/// Bộ lọc danh sách giao dịch. Các nhóm kết hợp bằng AND; trong một nhóm (danh mục, ngân sách) là OR.
class TransactionFilter {
  /// null = cả chi lẫn thu.
  final TransactionType? type;
  final Set<String> categoryIds;

  /// jarKey của các hũ ngân sách được chọn.
  final Set<String> jarKeys;

  /// Chọn thêm "Chưa có ngân sách": khoản chi không thuộc hũ nào.
  final bool noBudget;
  final double? minAmount;
  final double? maxAmount;

  const TransactionFilter({
    this.type,
    this.categoryIds = const {},
    this.jarKeys = const {},
    this.noBudget = false,
    this.minAmount,
    this.maxAmount,
  });

  static const empty = TransactionFilter();

  bool get hasBudgetFilter => jarKeys.isNotEmpty || noBudget;

  /// Số nhóm bộ lọc đang bật (hiện trên nút lọc).
  int get activeCount =>
      (type != null ? 1 : 0) +
      (categoryIds.isNotEmpty ? 1 : 0) +
      (hasBudgetFilter ? 1 : 0) +
      (minAmount != null || maxAmount != null ? 1 : 0);

  bool get isActive => activeCount > 0;

  /// Đổi từng trường; truyền `clearType` / `clearMin` / `clearMax` để đưa về null.
  TransactionFilter copyWith({
    TransactionType? type,
    bool clearType = false,
    Set<String>? categoryIds,
    Set<String>? jarKeys,
    bool? noBudget,
    double? minAmount,
    bool clearMin = false,
    double? maxAmount,
    bool clearMax = false,
  }) =>
      TransactionFilter(
        type: clearType ? null : (type ?? this.type),
        categoryIds: categoryIds ?? this.categoryIds,
        jarKeys: jarKeys ?? this.jarKeys,
        noBudget: noBudget ?? this.noBudget,
        minAmount: clearMin ? null : (minAmount ?? this.minAmount),
        maxAmount: clearMax ? null : (maxAmount ?? this.maxAmount),
      );

  /// [childrenOf]: parentId -> id các danh mục con (chọn danh mục cha thì gồm cả con).
  /// [jarKeyOf]: hũ của giao dịch (null nếu không thuộc hũ nào), xem [BudgetResolver].
  List<TransactionModel> apply(
    List<TransactionModel> txs, {
    Map<String, List<String>> childrenOf = const {},
    String? Function(TransactionModel)? jarKeyOf,
  }) {
    final cats = <String>{
      for (final id in categoryIds) ...[id, ...?childrenOf[id]],
    };
    return txs.where((t) {
      if (type != null && t.type != type) return false;
      if (minAmount != null && t.amount < minAmount!) return false;
      if (maxAmount != null && t.amount > maxAmount!) return false;
      if (cats.isNotEmpty && !cats.contains(CategoryRepository.legacyNameToId[t.categoryId] ?? t.categoryId)) {
        return false;
      }
      if (hasBudgetFilter) {
        // Ngân sách chỉ áp dụng cho khoản chi.
        if (t.type != TransactionType.expense) return false;
        final key = jarKeyOf?.call(t);
        final ok = key == null ? noBudget : jarKeys.contains(key);
        if (!ok) return false;
      }
      return true;
    }).toList();
  }
}

/// Suy ra hũ ngân sách của một giao dịch: danh mục + tháng của giao dịch -> liên kết trong kế hoạch tháng đó.
/// Nhờ vậy giao dịch cũ vẫn thuộc đúng hũ của tháng của nó dù sau này đổi hũ.
class BudgetResolver {
  final Map<DateTime, String> _planByMonth;
  final Map<String, Map<String, String>> _jarKeyByPlanCategory; // planId -> categoryId -> jarKey

  BudgetResolver._(this._planByMonth, this._jarKeyByPlanCategory);

  factory BudgetResolver({
    required List<BudgetPlanModel> plans,
    required List<BudgetJarModel> jars,
    required List<BudgetCategoryModel> links,
  }) {
    final jarKeyById = {for (final j in jars) j.syncId: j.jarKey};
    final byPlan = <String, Map<String, String>>{};
    for (final l in links) {
      final key = jarKeyById[l.jarId];
      if (key == null) continue;
      byPlan.putIfAbsent(l.planId, () => {})[l.categoryId] = key;
    }
    return BudgetResolver._({for (final p in plans) p.periodStart: p.syncId}, byPlan);
  }

  String? jarKeyOf(TransactionModel t) {
    final planId = _planByMonth[DateTime(t.transactionAt.year, t.transactionAt.month, 1)];
    if (planId == null) return null;
    final map = _jarKeyByPlanCategory[planId];
    if (map == null) return null;
    return map[t.categoryId] ?? map[CategoryRepository.legacyNameToId[t.categoryId]];
  }
}

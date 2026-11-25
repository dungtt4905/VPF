import '../../models/budget_category_model.dart';
import '../../models/budget_jar_model.dart';
import '../../models/budget_plan_model.dart';
import '../../models/enums.dart';

/// Cấu hình của một hũ trong một kỳ đã qua (ảnh chụp lấy từ kế hoạch của kỳ đó).
class PeriodSnapshot {
  final double amount;

  /// null = mọi khoản chi; rỗng = không danh mục nào.
  final Set<String>? categoryIds;

  /// Hũ cam kết đã được đánh dấu "đã trả" trong kỳ đó.
  final bool paid;

  const PeriodSnapshot(this.amount, this.categoryIds, {this.paid = false});
}

/// Thứ mà [BudgetCalc] tính tiến độ trên đó: một hũ cùng cấu hình hiện tại và cấu hình của các kỳ đã qua.
/// Thuần dữ liệu, không phụ thuộc Isar hay UI.
class BudgetSpec {
  /// Định danh ổn định qua các kỳ (jarKey).
  final String key;
  final String name;
  final double amount;
  final bool rollover;
  final int alertThreshold;
  final BudgetPeriod period;

  /// Thời điểm hũ bắt đầu được theo dõi: kỳ chứa ngày này là kỳ đầu tiên được xét lịch sử.
  final DateTime createdAt;

  /// Các danh mục thuộc hũ. null = hũ tổng (mọi khoản chi); rỗng = hũ cam kết (không gắn danh mục).
  final Set<String>? categoryIds;

  /// Hũ cam kết đã đánh dấu "đã trả" trong kỳ hiện tại.
  final bool paid;

  /// Cấu hình của các kỳ đã qua, theo đầu kỳ. Kỳ nào không có thì dùng cấu hình hiện tại.
  final Map<DateTime, PeriodSnapshot> history;

  /// Đầu kỳ hiện tại (để phân biệt "đã trả" của kỳ này với các kỳ trước).
  final DateTime? currentStart;

  const BudgetSpec({
    required this.key,
    this.name = '',
    required this.amount,
    required this.rollover,
    required this.alertThreshold,
    required this.period,
    required this.createdAt,
    required this.categoryIds,
    this.paid = false,
    this.history = const {},
    this.currentStart,
  });

  bool get isTotal => categoryIds == null;

  /// Hũ cam kết: không gắn danh mục nào, "chi" khi người dùng đánh dấu đã trả.
  bool get commitment => categoryIds != null && categoryIds!.isEmpty;

  /// Hạn mức gốc của kỳ bắt đầu ở [periodStart].
  double amountFor(DateTime periodStart) => history[periodStart]?.amount ?? amount;

  /// Danh mục của hũ trong kỳ bắt đầu ở [periodStart].
  Set<String>? categoriesFor(DateTime periodStart) {
    final h = history[periodStart];
    return h != null ? h.categoryIds : categoryIds;
  }

  /// Hũ cam kết đã trả trong kỳ bắt đầu ở [periodStart].
  bool paidFor(DateTime periodStart) =>
      currentStart == null || periodStart == currentStart ? paid : (history[periodStart]?.paid ?? false);

  /// Dựng spec cho các hũ của kế hoạch tháng chứa [now]. Cấu hình các kỳ đã qua lấy từ hũ cùng `jarKey` ở các kế
  /// hoạch trước đó; ngày bắt đầu theo dõi là ngày tạo sớm nhất của hũ cùng `jarKey`.
  static List<BudgetSpec> fromJars({
    required List<BudgetPlanModel> plans,
    required List<BudgetJarModel> jars,
    required List<BudgetCategoryModel> links,
    required DateTime now,
  }) {
    final currentStart = DateTime(now.year, now.month, 1);
    final planById = {for (final p in plans) p.syncId: p};
    BudgetPlanModel? current;
    for (final p in plans) {
      if (p.periodStart == currentStart) current = p;
    }
    if (current == null) return const [];

    final idsByJar = <String, Set<String>>{};
    for (final l in links) {
      idsByJar.putIfAbsent(l.jarId, () => <String>{}).add(l.categoryId);
    }
    final jarsByKey = <String, List<BudgetJarModel>>{};
    for (final j in jars) {
      jarsByKey.putIfAbsent(j.jarKey, () => []).add(j);
    }

    Set<String>? idsOf(BudgetJarModel j) => j.isTotal ? null : (idsByJar[j.syncId] ?? const <String>{});

    final result = <BudgetSpec>[];
    for (final jar in jars.where((j) => j.planId == current!.syncId)) {
      final sameKey = jarsByKey[jar.jarKey]!;
      final history = <DateTime, PeriodSnapshot>{};
      var since = jar.createdAt.toLocal();
      for (final other in sameKey) {
        if (other.createdAt.toLocal().isBefore(since)) since = other.createdAt.toLocal();
        final plan = planById[other.planId];
        if (plan == null || !plan.periodStart.isBefore(currentStart)) continue;
        history[plan.periodStart] = PeriodSnapshot(other.amount, idsOf(other), paid: other.paidAt != null);
      }
      result.add(BudgetSpec(
        key: jar.jarKey,
        name: jar.name,
        amount: jar.amount,
        rollover: jar.rollover,
        alertThreshold: jar.alertThreshold,
        period: BudgetPeriod.monthly,
        createdAt: since,
        categoryIds: idsOf(jar),
        paid: jar.paidAt != null,
        history: history,
        currentStart: currentStart,
      ));
    }
    return result;
  }
}

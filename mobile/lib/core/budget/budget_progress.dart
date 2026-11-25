import 'dart:math';
import 'budget_spec.dart';
import '../../models/category_model.dart';
import '../../models/enums.dart';
import '../../models/transaction_model.dart';
import '../repositories/category_repository.dart';

/// Mức độ của một ngân sách, tăng dần theo độ nghiêm trọng.
enum BudgetLevel { ok, pace, warning, exceeded }

/// Tiến độ của một ngân sách trong một kỳ (tuần/tháng). Thuần tính toán, không phụ thuộc UI.
class BudgetProgress {
  final double used;

  /// Hạn mức hiệu lực của kỳ: hạn mức gốc cộng số dư chuyển từ kỳ trước ([carry]) nếu bật rollover.
  final double limit;
  final int threshold;

  /// Số dư (dương) hoặc số vượt (âm) chuyển từ kỳ trước; 0 nếu không bật rollover.
  final double carry;

  /// Kỳ [start, end), biên nửa mở.
  final DateTime start;
  final DateTime end;
  final DateTime now;

  /// Hũ cam kết (tiền nhà, trả nợ): không có mức "sắp hết"/"vượt", chỉ có đã trả hoặc chưa trả.
  final bool commitment;

  const BudgetProgress({
    required this.used,
    required this.limit,
    required this.threshold,
    required this.start,
    required this.end,
    required this.now,
    this.carry = 0,
    this.commitment = false,
  });

  /// Dự báo chỉ có ý nghĩa sau từng này ngày của kỳ (tránh một khoản lớn đầu kỳ làm dự báo sai).
  static const minDaysForForecast = 3;

  // Hạn mức hiệu lực có thể về 0 khi rollover bù hết (đã vượt nặng kỳ trước): có chi là vượt.
  double get pct => limit > 0 ? used / limit * 100 : (used > 0 ? 100 : 0);
  double get remaining => limit - used;

  int get totalDays => (end.difference(start).inHours / 24).round().clamp(1, 366);

  /// Chỉ số ngày hiện tại trong kỳ (0 = ngày đầu).
  int get dayIndex {
    final today = DateTime(now.year, now.month, now.day);
    return (today.difference(start).inHours / 24).round().clamp(0, totalDays - 1);
  }

  /// Số ngày còn lại của kỳ, tính cả hôm nay.
  int get daysLeft => totalDays - dayIndex;

  /// Phần trăm thời gian đã trôi qua của kỳ (cho vạch "mức lý tưởng").
  double get elapsedPct {
    final total = end.difference(start).inMinutes;
    if (total <= 0) return 0;
    return (now.difference(start).inMinutes / total * 100).clamp(0.0, 100.0);
  }

  /// Số tiền có thể chi mỗi ngày cho đến hết kỳ (0 nếu đã hết/vượt).
  double get dailyAllowance => remaining > 0 ? remaining / daysLeft : 0;

  bool get canForecast => dayIndex + 1 >= minDaysForForecast;

  /// Tốc độ chi trung bình mỗi ngày (tính cả hôm nay).
  double get dailyRate => used / (dayIndex + 1);

  /// Tổng chi dự kiến cuối kỳ nếu giữ nguyên tốc độ; null nếu chưa đủ dữ liệu.
  double? get projectedTotal => canForecast ? dailyRate * totalDays : null;

  /// Ngày dự kiến chạm hạn mức; null nếu đã vượt, chưa đủ dữ liệu hoặc không vượt trong kỳ.
  DateTime? get projectedExceedDate {
    final projected = projectedTotal;
    if (projected == null || limit <= 0 || used >= limit || projected <= limit || dailyRate <= 0) {
      return null;
    }
    final daysToLimit = (limit / dailyRate).ceil(); // ngày thứ k (1-based)
    return DateTime(start.year, start.month, start.day + daysToLimit - 1);
  }

  BudgetLevel get level {
    if (commitment) return BudgetLevel.ok;
    if (limit <= 0 && used <= 0) return BudgetLevel.ok;
    if (pct >= 100) return BudgetLevel.exceeded;
    if (pct >= threshold) return BudgetLevel.warning;
    final projected = projectedTotal;
    if (projected != null && projected > limit) return BudgetLevel.pace;
    return BudgetLevel.ok;
  }

  BudgetProgress withUsed(double newUsed) => BudgetProgress(
        used: newUsed,
        limit: limit,
        threshold: threshold,
        start: start,
        end: end,
        now: now,
        carry: carry,
        commitment: commitment,
      );
}

/// Kết quả của một kỳ đã kết thúc.
class BudgetPeriodResult {
  final DateTime start;
  final DateTime end;

  /// Hạn mức hiệu lực của kỳ đó (đã gồm số dư chuyển từ kỳ trước nếu bật rollover).
  final double limit;
  final double used;

  const BudgetPeriodResult({required this.start, required this.end, required this.limit, required this.used});

  bool get met => used <= limit;
  double get pct => limit > 0 ? used / limit * 100 : (used > 0 ? 100 : 0);
}

/// Các hàm tính ngân sách dùng chung cho màn Ngân sách, form giao dịch và thông báo.
class BudgetCalc {
  BudgetCalc._();

  /// Cửa sổ thời gian [start, end) của chu kỳ chứa [now].
  static (DateTime, DateTime) periodWindow(BudgetPeriod period, DateTime now) {
    return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 1));
  }

  static bool inWindow(DateTime t, DateTime start, DateTime end) => !t.isBefore(start) && t.isBefore(end);

  /// Giao dịch thuộc [budgetCategoryId] nếu trùng id hoặc là con (nhiều cấp) của nó.
  static bool belongsTo(String txCategoryId, String budgetCategoryId, Map<String, CategoryModel> catMap) {
    final visited = <String>{};
    String? current = catMap.containsKey(txCategoryId)
        ? txCategoryId
        : (CategoryRepository.legacyNameToId[txCategoryId] ?? txCategoryId);
    while (current != null && visited.add(current)) {
      if (current == budgetCategoryId) return true;
      current = catMap[current]?.parentId;
    }
    return false;
  }

  /// Tổng chi của [budget] trong kỳ chứa [now]. Bỏ qua giao dịch có id = [excludeTxId].
  static double usedAmount(
    BudgetSpec budget,
    List<TransactionModel> txs,
    Map<String, CategoryModel> catMap,
    DateTime now, {
    int? excludeTxId,
  }) {
    final (start, end) = periodWindow(budget.period, now);
    final ids = budget.categoriesFor(start);
    // Hũ cam kết không có giao dịch: coi như đã chi đủ hạn mức khi được đánh dấu đã trả.
    if (ids != null && ids.isEmpty) return budget.paidFor(start) ? budget.amountFor(start) : 0;
    double used = 0;
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      if (excludeTxId != null && t.id == excludeTxId) continue;
      if (!inWindow(t.transactionAt, start, end)) continue;
      if (ids == null || ids.any((id) => belongsTo(t.categoryId, id, catMap))) {
        used += t.amount;
      }
    }
    return used;
  }

  static BudgetProgress progress(
    BudgetSpec budget,
    List<TransactionModel> txs,
    Map<String, CategoryModel> catMap,
    DateTime now, {
    int? excludeTxId,
  }) {
    final (start, end) = periodWindow(budget.period, now);

    // Rollover: số dư (hoặc số vượt) của kỳ liền trước chuyển sang kỳ này.
    var carry = 0.0;
    if (budget.rollover) {
      final past = pastResults(budget, txs, catMap, now);
      if (past.isNotEmpty) carry = _carryAfter(budget, past.last);
    }

    return BudgetProgress(
      used: usedAmount(budget, txs, catMap, now, excludeTxId: excludeTxId),
      limit: budget.amountFor(start) + carry,
      threshold: budget.alertThreshold,
      start: start,
      end: end,
      now: now,
      carry: carry,
      commitment: budget.commitment,
    );
  }

  /// Số dư chuyển sang kỳ sau. Số vượt không được làm hạn mức kỳ sau âm.
  static double _carryAfter(BudgetSpec budget, BudgetPeriodResult r) =>
      max(-budget.amountFor(r.start), r.limit - r.used);

  /// Đầu kỳ liền trước kỳ bắt đầu ở [start].
  static DateTime previousStart(BudgetPeriod period, DateTime start) => DateTime(start.year, start.month - 1, 1);

  /// Số kỳ tối đa được xét ngược về trước (cũng là độ sâu chuỗi rollover).
  static const maxLookback = 12;

  /// Kết quả các kỳ đã kết thúc, từ cũ đến mới, chỉ từ kỳ chứa ngày tạo ngân sách trở đi.
  /// Hạn mức mỗi kỳ dùng hạn mức gốc hiện tại (app không lưu lịch sử thay đổi hạn mức).
  static List<BudgetPeriodResult> pastResults(
    BudgetSpec budget,
    List<TransactionModel> txs,
    Map<String, CategoryModel> catMap,
    DateTime now, {
    int maxPeriods = maxLookback,
  }) {
    final (currentStart, _) = periodWindow(budget.period, now);
    final (firstStart, _) = periodWindow(budget.period, budget.createdAt.toLocal());

    // Gom đầu kỳ từ kỳ liền trước ngược về, dừng ở kỳ tạo ngân sách hoặc khi đủ số kỳ.
    final starts = <DateTime>[];
    var cursor = previousStart(budget.period, currentStart);
    while (!cursor.isBefore(firstStart) && starts.length < maxPeriods) {
      starts.add(cursor);
      cursor = previousStart(budget.period, cursor);
    }

    final results = <BudgetPeriodResult>[];
    var carry = 0.0;
    for (final s in starts.reversed) {
      // Giữa kỳ, now = đầu kỳ s để tái dùng periodWindow/usedAmount.
      final (start, end) = periodWindow(budget.period, s);
      final used = usedAmount(budget, txs, catMap, s);
      final base = budget.amountFor(start);
      final limit = budget.rollover ? base + carry : base;
      final r = BudgetPeriodResult(start: start, end: end, limit: limit, used: used);
      results.add(r);
      if (budget.rollover) carry = _carryAfter(budget, r);
    }
    return results;
  }

  /// Số kỳ liên tiếp (tính từ kỳ gần nhất) giữ được ngân sách.
  static int streak(List<BudgetPeriodResult> pastChronological) {
    var n = 0;
    for (final r in pastChronological.reversed) {
      if (!r.met) break;
      n++;
    }
    return n;
  }
}

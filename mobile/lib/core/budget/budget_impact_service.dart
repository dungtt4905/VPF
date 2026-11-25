import '../currency/currency_format.dart';
import '../repositories/budget_plan_repository.dart';
import 'budget_spec.dart';
import '../../models/category_model.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';
import 'budget_progress.dart';

/// Ảnh hưởng của một giao dịch chi tiêu lên một ngân sách.
class BudgetImpact {
  final BudgetSpec spec;
  final CategoryModel? category;

  /// Trạng thái hiện đang lưu (có tính giao dịch cũ nếu đang sửa).
  final BudgetProgress before;

  /// Trạng thái nếu lưu giao dịch này.
  final BudgetProgress after;

  const BudgetImpact(this.spec, this.category, this.before, this.after);

  String get name => spec.name.isNotEmpty ? spec.name : (category?.name ?? 'Tổng ngân sách');

  /// Giao dịch này làm ngân sách vượt hạn mức (hoặc làm vượt thêm khi đã vượt).
  bool get causesExceed => after.level == BudgetLevel.exceeded && after.used > before.used;

  /// Giao dịch này đẩy ngân sách từ mức an toàn lên ngưỡng cảnh báo hoặc vượt.
  bool get crossesAlert =>
      after.used > before.used &&
      (after.level == BudgetLevel.warning || after.level == BudgetLevel.exceeded) &&
      before.level != after.level;
}

class BudgetImpactService {
  final TransactionRepository _txRepo;
  final CategoryRepository _catRepo;

  final BudgetPlanRepository _planRepo;

  BudgetImpactService(this._txRepo, this._catRepo, this._planRepo);

  /// Tính ảnh hưởng của một khoản chi lên các ngân sách liên quan.
  /// [excludeTxId]: id giao dịch đang sửa, được thay bằng [amount] thay vì cộng thêm.
  /// Giao dịch nằm ngoài kỳ hiện tại không ảnh hưởng ngân sách nào.
  Future<List<BudgetImpact>> evaluate({
    required String categoryId,
    required double amount,
    required DateTime txDate,
    int? excludeTxId,
    DateTime? now,
  }) async {
    if (amount <= 0) return const [];
    final at = now ?? DateTime.now();
    final specs = await _planRepo.currentSpecs(now: at);
    if (specs.isEmpty) return const [];
    final txs = await _txRepo.getAll();
    final cats = await _catRepo.getAll();
    final catMap = {for (final c in cats) c.syncId: c};

    final result = <BudgetImpact>[];
    for (final spec in specs) {
      // Danh mục của hũ mà khoản chi này thuộc về (null nếu là hũ tổng).
      String? matched;
      final ids = spec.categoryIds;
      if (ids != null) {
        matched = ids.where((id) => BudgetCalc.belongsTo(categoryId, id, catMap)).firstOrNull;
        if (matched == null) continue;
      }
      final (start, end) = BudgetCalc.periodWindow(spec.period, at);
      if (!BudgetCalc.inWindow(txDate, start, end)) continue;

      final before = BudgetCalc.progress(spec, txs, catMap, at);
      final base = BudgetCalc.usedAmount(spec, txs, catMap, at, excludeTxId: excludeTxId);
      final after = before.withUsed(base + amount);
      result.add(BudgetImpact(spec, matched != null ? catMap[matched] : null, before, after));
    }
    // Nghiêm trọng nhất lên đầu.
    result.sort((a, b) {
      final byLevel = b.after.level.index.compareTo(a.after.level.index);
      return byLevel != 0 ? byLevel : b.after.pct.compareTo(a.after.pct);
    });
    return result;
  }

  /// Câu cảnh báo ngắn sau khi lưu, hoặc null nếu không có gì đáng nói.
  static String? warningMessage(List<BudgetImpact> impacts) {
    final hits = impacts.where((i) => i.crossesAlert || i.causesExceed).toList();
    if (hits.isEmpty) return null;
    final top = hits.first;
    final money = CurrencyFormat.vnd;
    if (top.after.level == BudgetLevel.exceeded) {
      return 'Ngân sách ${top.name} đã vượt ${money.compact(top.after.used - top.after.limit)}';
    }
    return 'Bạn đã dùng ${top.after.pct.round()}% ngân sách ${top.name}';
  }
}

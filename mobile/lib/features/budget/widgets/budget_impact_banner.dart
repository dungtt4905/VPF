import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/budget/budget_impact_service.dart';
import '../../../core/budget/budget_progress.dart';
import '../../../core/currency/currency_format.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../budget_save_guard.dart';

/// Hiện ảnh hưởng của khoản chi đang nhập lên ngân sách, trước khi người dùng bấm Lưu.
/// Tự ẩn khi không phải chi tiêu, chưa nhập số tiền hoặc không có ngân sách liên quan.
class BudgetImpactBanner extends StatefulWidget {
  final TextEditingController amountController;
  final String? categoryId;
  final DateTime date;
  final bool isExpense;

  /// Id giao dịch đang sửa: số tiền cũ được thay bằng số mới thay vì cộng dồn.
  final int? excludeTxId;

  const BudgetImpactBanner({
    super.key,
    required this.amountController,
    required this.categoryId,
    required this.date,
    required this.isExpense,
    this.excludeTxId,
  });

  @override
  State<BudgetImpactBanner> createState() => _BudgetImpactBannerState();
}

class _BudgetImpactBannerState extends State<BudgetImpactBanner> {
  List<BudgetImpact> _impacts = const [];
  Timer? _debounce;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    widget.amountController.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant BudgetImpactBanner old) {
    super.didUpdateWidget(old);
    if (old.amountController != widget.amountController) {
      old.amountController.removeListener(_schedule);
      widget.amountController.addListener(_schedule);
    }
    if (old.categoryId != widget.categoryId ||
        old.date != widget.date ||
        old.isExpense != widget.isExpense ||
        old.excludeTxId != widget.excludeTxId) {
      _schedule();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.amountController.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _evaluate);
  }

  Future<void> _evaluate() async {
    final amount = parseAmount(widget.amountController.text);
    final categoryId = widget.categoryId;
    if (!widget.isExpense || categoryId == null || amount == null || amount <= 0) {
      if (_impacts.isNotEmpty && mounted) setState(() => _impacts = const []);
      return;
    }
    final request = ++_request;
    final impacts = await getIt<BudgetImpactService>().evaluate(
      categoryId: categoryId,
      amount: amount,
      txDate: widget.date,
      excludeTxId: widget.excludeTxId,
    );
    // Bỏ kết quả cũ nếu người dùng đã gõ tiếp.
    if (!mounted || request != _request) return;
    setState(() => _impacts = impacts);
  }

  @override
  Widget build(BuildContext context) {
    if (_impacts.isEmpty) return const SizedBox.shrink();
    final shown = _impacts.take(2).toList();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(children: [for (final i in shown) _row(i)]),
    );
  }

  Widget _row(BudgetImpact i) {
    final money = CurrencyFormat.vnd;
    final level = i.after.level;
    final Color color;
    final Color soft;
    final IconData icon;
    switch (level) {
      case BudgetLevel.exceeded:
        color = AppColors.expense;
        soft = AppColors.expenseSoft;
        icon = Icons.error_outline;
      case BudgetLevel.warning:
        color = const Color(0xFFB26B00);
        soft = AppColors.warningSoft;
        icon = Icons.warning_amber_rounded;
      case BudgetLevel.pace:
      case BudgetLevel.ok:
        color = AppColors.primaryDark;
        soft = AppColors.primarySoft;
        icon = Icons.account_balance_wallet_outlined;
    }

    final remaining = i.after.remaining;
    final text = remaining < 0
        ? '${i.name}: sẽ vượt ${money.compact(-remaining)} (${i.after.pct.round()}%)'
        : '${i.name}: còn ${money.compact(i.before.remaining)} → sau giao dịch còn ${money.compact(remaining)}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

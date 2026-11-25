import 'package:flutter/material.dart';
import '../../core/budget/budget_progress.dart';
import '../../core/currency/currency_format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'cubit/budget_cubit.dart';

/// Lịch sử các kỳ đã qua của một ngân sách: đạt/vượt từng kỳ và chuỗi kỳ liên tiếp giữ được.
Future<void> showBudgetHistory(BuildContext context, BudgetData item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero))),
    builder: (_) => _HistorySheet(item: item),
  );
}

class _HistorySheet extends StatelessWidget {
  final BudgetData item;
  const _HistorySheet({required this.item});

  static const _shown = 6;

  String _label(BudgetPeriodResult r) {
    return 'Tháng ${r.start.month}/${r.start.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = item.name;
    final all = item.history;
    final recent = all.reversed.take(_shown).toList(); // mới nhất trước
    final met = recent.where((r) => r.met).length;
    final streak = item.streak;
    const unit = 'tháng';

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lịch sử · $name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.jar.rollover
                    ? 'Đã tính số dư chuyển kỳ. Hạn mức mỗi kỳ lấy theo kế hoạch của kỳ đó (kỳ chưa có kế hoạch dùng mức hiện tại).'
                    : 'Hạn mức mỗi kỳ lấy theo kế hoạch của kỳ đó (kỳ chưa có kế hoạch dùng mức hiện tại).',
                style: AppText.caption,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text('Chưa có kỳ nào kết thúc. Kết quả sẽ hiện khi hết $unit đầu tiên.',
                        textAlign: TextAlign.center, style: AppText.caption.copyWith(fontSize: 13)),
                  ),
                )
              else ...[
                Row(
                  children: [
                    _chip(Icons.local_fire_department_rounded, '$streak $unit liên tiếp',
                        streak >= 2 ? AppColors.warningSoft : AppColors.background,
                        streak >= 2 ? const Color(0xFFB26B00) : AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    _chip(Icons.check_circle_outline, 'Giữ được $met/${recent.length} $unit', AppColors.primarySoft,
                        AppColors.primaryDark),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [for (final r in recent) _row(r)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _row(BudgetPeriodResult r) {
    final money = CurrencyFormat.vnd;
    final color = r.met ? AppColors.primary : AppColors.expense;
    final diff = r.limit - r.used;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(r.met ? Icons.check_circle : Icons.cancel, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(_label(r), style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(
                diff >= 0 ? 'Dư ${money.compact(diff)}' : 'Vượt ${money.compact(-diff)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: (r.pct / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('${money.compact(r.used)} / ${money.compact(r.limit)} · ${r.pct.round()}%', style: AppText.caption),
        ],
      ),
    );
  }
}

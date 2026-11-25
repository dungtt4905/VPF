import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/budget/budget_progress.dart';
import '../../core/di/injection.dart';
import 'cubit/budget_cubit.dart';
import '../../core/currency/currency_format.dart';
import '../../shared/widgets/money_text.dart';
import '../category/category_style.dart';
import 'budget_form_sheet.dart';
import 'budget_history_sheet.dart';
import 'budget_plan_sheet.dart';
import 'budget_unassigned_sheet.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BudgetCubit(getIt(), getIt(), getIt()),
      child: const _BudgetView(),
    );
  }
}

class _BudgetView extends StatefulWidget {
  const _BudgetView();

  @override
  State<_BudgetView> createState() => _BudgetViewState();
}

typedef _Status = ({Color color, Color soft, Color text, String label, IconData icon});

class _BudgetViewState extends State<_BudgetView> {
  static const _warningText = Color(0xFFB26B00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<BudgetCubit, BudgetState>(
          builder: (context, state) {
            if (state is BudgetLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (state is! BudgetLoaded) return const SizedBox.shrink();

            final data = state;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: AppSpacing.lg),
                  _buildAlertBanner(data.budgets),
                  _buildTotalBudgetSection(data),
                  if (data.unassigned.isNotEmpty) _buildUnassigned(context, data),
                  const SizedBox(height: AppSpacing.xl),
                  _buildBudgetList(data.budgets),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---- Trạng thái: ổn (xanh) / đi nhanh (xanh dương) / sắp hết (vàng) / vượt (đỏ) ----
  _Status _status(BudgetLevel level) {
    switch (level) {
      case BudgetLevel.exceeded:
        return (
          color: AppColors.expense,
          soft: AppColors.expenseSoft,
          text: AppColors.expense,
          label: 'Vượt ngân sách',
          icon: Icons.error_outline,
        );
      case BudgetLevel.warning:
        return (
          color: AppColors.warning,
          soft: AppColors.warningSoft,
          text: _warningText,
          label: 'Sắp hết',
          icon: Icons.warning_amber_rounded,
        );
      case BudgetLevel.pace:
        return (
          color: AppColors.balance,
          soft: AppColors.balanceSoft,
          text: AppColors.balance,
          label: 'Đi nhanh',
          icon: Icons.trending_up_rounded,
        );
      case BudgetLevel.ok:
        return (
          color: AppColors.primary,
          soft: AppColors.primarySoft,
          text: AppColors.primaryDark,
          label: 'Ổn định',
          icon: Icons.check_circle_outline,
        );
    }
  }

  /// "Có thể chi ~85K/ngày · còn 12 ngày", hoặc câu dự báo vượt nếu có.
  String? _paceHint(BudgetProgress p) {
    if (p.level == BudgetLevel.exceeded) return null;
    final money = CurrencyFormat.vnd;
    final exceedDate = p.projectedExceedDate;
    if (exceedDate != null && p.level != BudgetLevel.warning) {
      return 'Với tốc độ này sẽ hết vào ${DateFormat('dd/MM').format(exceedDate)}';
    }
    return 'Có thể chi ~${money.compact(p.dailyAllowance)}/ngày · còn ${p.daysLeft} ngày';
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      );

  Widget _statusChip(_Status s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: s.soft, borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 14, color: s.text),
          const SizedBox(width: AppSpacing.xs),
          Text(s.label, style: TextStyle(color: s.text, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// [markerPct]: vạch "mức lý tưởng hôm nay" (phần trăm thời gian đã trôi qua của kỳ).
  Widget _progressBar(double pct, Color color, {double? markerPct}) {
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: LinearProgressIndicator(
        value: (pct / 100).clamp(0.0, 1.0),
        minHeight: 10,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
    if (markerPct == null) return bar;
    return LayoutBuilder(
      builder: (context, c) {
        final x = (markerPct / 100).clamp(0.0, 1.0) * c.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            bar,
            Positioned(
              left: (x - 1).clamp(0.0, c.maxWidth - 2),
              top: -3,
              bottom: -3,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text('Ngân sách', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ),
        GestureDetector(
          onTap: () => showBudgetPlan(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle, border: Border.all(color: AppColors.primary)),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: () => showBudgetForm(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  /// Danh sách "Cần chú ý": tối đa 3 ngân sách không ở trạng thái ổn, nghiêm trọng nhất lên đầu.
  Widget _buildAlertBanner(List<BudgetData> budgets) {
    final hits = budgets.where((b) => b.jar.amount > 0 && b.progress.level != BudgetLevel.ok).toList()
      ..sort(_bySeverity);
    if (hits.isEmpty) return const SizedBox.shrink();

    final shown = hits.take(3).toList();
    final worst = _status(shown.first.progress.level);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: worst.soft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: worst.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cần chú ý', style: TextStyle(color: worst.text, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          for (final item in shown) _attentionRow(item),
          if (hits.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('và ${hits.length - shown.length} ngân sách khác',
                  style: TextStyle(color: worst.text, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  /// Nghiêm trọng nhất lên đầu, cùng mức thì dùng nhiều hơn lên trước.
  static int _bySeverity(BudgetData a, BudgetData b) {
    final byLevel = b.progress.level.index.compareTo(a.progress.level.index);
    return byLevel != 0 ? byLevel : b.progress.pct.compareTo(a.progress.pct);
  }

  Widget _attentionRow(BudgetData item) {
    final p = item.progress;
    final s = _status(p.level);
    final name = item.name;
    final String text;
    switch (p.level) {
      case BudgetLevel.exceeded:
        text = 'Ngân sách $name đã vượt ${(p.pct - 100).round()}%';
      case BudgetLevel.warning:
        text = 'Bạn đã dùng ${p.pct.round()}% ngân sách $name';
      case BudgetLevel.pace:
        final d = p.projectedExceedDate;
        text = d != null
            ? 'Ngân sách $name đi nhanh, dự kiến hết vào ${DateFormat('dd/MM').format(d)}'
            : 'Ngân sách $name đang đi nhanh hơn kế hoạch';
      case BudgetLevel.ok:
        text = '';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(s.icon, color: s.text, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: s.text, fontSize: 13, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildTotalBudgetSection(BudgetLoaded data) {
    final total = data.totalBudget;
    final spent = data.totalSpent;
    final remaining = total - spent;
    final progress = data.totalProgress;
    final pct = total > 0 ? spent / total * 100 : 0.0;
    final s = _status(progress?.level ?? BudgetLevel.ok);
    final hint = progress != null && total > 0 ? _paceHint(progress) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng ngân sách tháng ${DateTime.now().month}', style: AppText.caption.copyWith(fontSize: 13)),
              if (total > 0) _statusChip(s),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(total, style: AppText.moneyHero.copyWith(color: AppColors.textPrimary)),
          ),
          const SizedBox(height: AppSpacing.lg),
          _progressBar(pct, s.color, markerPct: total > 0 ? progress?.elapsedPct : null),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(hint, style: AppText.caption.copyWith(color: s.text, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _miniStat('Đã chi', spent, AppColors.textPrimary, '${pct.round()}%')),
              Container(width: 1, height: 36, color: AppColors.border),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: remaining >= 0
                    ? _miniStat('Còn lại', remaining, AppColors.primaryDark, null)
                    : _miniStat('Vượt', -remaining, AppColors.expense, null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value, Color color, String? trailing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppText.caption),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              Text(trailing, style: AppText.caption.copyWith(color: AppColors.textMuted)),
            ],
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(value, style: AppText.moneyMedium.copyWith(color: color), unitScale: 0.7),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, BudgetData item) async {
    final cubit = context.read<BudgetCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa hũ?'),
        content: Text('Xóa hũ "${item.name}" khỏi kế hoạch tháng này. Các tháng trước vẫn giữ nguyên.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (ok == true) await cubit.deleteJar(item.jar.syncId);
  }

  Widget _buildBudgetList(List<BudgetData> budgets) {
    if (budgets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 34),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Chưa có hũ nào', style: AppText.sectionTitle),
            const SizedBox(height: 6),
            Text(
              'Chia thu nhập vào các hũ chi tiêu để được cảnh báo khi sắp vượt.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => showBudgetForm(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tạo hũ'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => showBudgetPlan(context),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Lập kế hoạch tháng'),
            ),
          ],
        ),
      );
    }
    // Ngân sách nguy hiểm lên đầu.
    final sorted = [...budgets]..sort(_bySeverity);
    return Column(
      children: sorted.map((item) => _buildBudgetCard(item, context)).toList(),
    );
  }

  Widget _buildBudgetCard(BudgetData item, BuildContext context) {
    final single = item.categories.length == 1 ? item.categories.first : null;
    final catName = item.name;
    final catColor = single == null ? AppColors.primary : categoryColor(single.color);
    final amount = item.jar.amount;
    final p = item.progress;
    final pct = p.pct;
    final s = _status(p.level);
    final remaining = p.remaining;
    final hint = amount > 0 ? _paceHint(p) : null;
    final periodLabel = item.commitment ? 'Cố định' : (item.categories.length > 1 ? '${item.categories.length} danh mục' : 'Tháng');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: catColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(
                  single == null ? Icons.account_balance_wallet_outlined : categoryIcon(single.icon),
                  color: catColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(catName,
                        style: AppText.sectionTitle.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.xs)),
                          child: Text(periodLabel, style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            // Hạn mức hiệu lực; nếu bật rollover thì ghi rõ số dư/vượt chuyển từ kỳ trước.
                            p.carry == 0
                                ? 'Hạn mức ${CurrencyFormat.vnd.compact(p.limit)}'
                                : 'Hạn mức ${CurrencyFormat.vnd.compact(p.limit)} (${p.carry > 0 ? '+' : '-'}${CurrencyFormat.vnd.compact(p.carry.abs())} kỳ trước)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption,
                          ),
                        ),
                        if (item.streak >= 2) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.local_fire_department_rounded, size: 16, color: _warningText),
                          Text('${item.streak}', style: const TextStyle(color: _warningText, fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                onSelected: (v) {
                  if (v == 'edit') showBudgetForm(context, editing: item);
                  if (v == 'history') showBudgetHistory(context, item);
                  if (v == 'delete') _confirmDelete(context, item);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'history', child: Text('Lịch sử các kỳ')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: AppColors.expense))),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (item.commitment) ..._commitmentBody(item) else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(remaining >= 0 ? 'Còn lại' : 'Vượt', style: AppText.caption),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: MoneyText(
                        remaining.abs(),
                        style: AppText.moneyLarge.copyWith(color: remaining >= 0 ? AppColors.textPrimary : AppColors.expense),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _statusChip(s),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _progressBar(pct, s.color, markerPct: amount > 0 ? p.elapsedPct : null),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(hint, style: AppText.caption.copyWith(color: s.text, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Đã dùng ${CurrencyFormat.vnd.compact(item.usedAmount)} / ${CurrencyFormat.vnd.compact(p.limit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
              Text('${pct.round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: s.text)),
            ],
          ),
          ],
        ],
      ),
    );
  }

  /// Hũ cam kết (tiền nhà, trả nợ): không có giao dịch, chỉ có đã trả hoặc chưa trả trong tháng.
  List<Widget> _commitmentBody(BudgetData item) {
    return [
      Builder(builder: (context) {
        final paid = item.paid;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paid ? 'Đã trả tháng này' : 'Cần trả tháng này', style: AppText.caption),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: MoneyText(item.jar.amount,
                        style: AppText.moneyLarge.copyWith(color: paid ? AppColors.primaryDark : AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            paid
                ? OutlinedButton.icon(
                    onPressed: () => context.read<BudgetCubit>().setPaid(item.jar.syncId, false),
                    icon: const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                    label: const Text('Đã trả'),
                  )
                : ElevatedButton(
                    onPressed: () => context.read<BudgetCubit>().setPaid(item.jar.syncId, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                    ),
                    child: const Text('Đánh dấu đã trả', style: TextStyle(color: Colors.white)),
                  ),
          ],
        );
      }),
    ];
  }

  /// "Chưa vào hũ nào: X" kèm lối tắt xếp các danh mục đó vào hũ.
  Widget _buildUnassigned(BuildContext context, BudgetLoaded data) {
    final money = CurrencyFormat.vnd;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chưa vào hũ nào: ${money.compact(data.unassignedTotal)} (${data.unassigned.length} danh mục)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: () => showUnassignedSheet(context), child: const Text('Xếp vào hũ')),
        ],
      ),
    );
  }
}

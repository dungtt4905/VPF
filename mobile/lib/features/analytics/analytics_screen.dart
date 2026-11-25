import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/period_selector.dart';
import '../../shared/widgets/transaction_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/di/injection.dart';
import '../../core/currency/currency_format.dart';
import '../../core/repositories/category_repository.dart';
import '../category/category_style.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import 'cubit/analytics_cubit.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AnalyticsCubit(getIt(), getIt()),
      child: const _AnalyticsView(),
    );
  }
}

class _AnalyticsView extends StatefulWidget {
  const _AnalyticsView();

  @override
  State<_AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<_AnalyticsView> {
  String _formatMoneyShort(double amount) => CurrencyFormat.vnd.compact(amount);

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<AnalyticsCubit, AnalyticsState>(
          builder: (context, state) {
            if (state is AnalyticsLoading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (state is! AnalyticsLoaded) return const SizedBox.shrink();

            final data = state.data;
            final isEmpty = data.totalExpense == 0 && data.totalIncome == 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(data),
                  const SizedBox(height: AppSpacing.md),
                  _buildPeriodSelector(data),
                  const SizedBox(height: 20),
                  _buildStatCardsRow(data),
                  const SizedBox(height: AppSpacing.lg),
                  _buildTrendCard(data),
                  const SizedBox(height: AppSpacing.xl),
                  if (isEmpty)
                    _buildEmptyState(data)
                  else ...[
                    _buildCategoryBreakdownSection(data),
                    const SizedBox(height: AppSpacing.xl),
                    _buildTopExpensesSection(data),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AnalyticsData data) {
    final isWeek = data.period == AnalyticsPeriod.week;
    Widget tab(String label, AnalyticsPeriod p) {
      final selected = data.period == p;
      return Expanded(
        child: GestureDetector(
          onTap: () => context.read<AnalyticsCubit>().setPeriod(p),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Phân tích',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          semanticsLabel: isWeek ? 'Phân tích theo tuần' : 'Phân tích theo tháng',
        ),
        Container(
          width: 150,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(children: [tab('Tuần', AnalyticsPeriod.week), tab('Tháng', AnalyticsPeriod.month)]),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(AnalyticsData data) {
    final cubit = context.read<AnalyticsCubit>();
    return PeriodSelector(
      period: data.period,
      start: data.start,
      end: data.end,
      isCurrent: data.isCurrent,
      onPrevious: cubit.previous,
      onNext: cubit.next,
      onCurrent: cubit.goToCurrent,
      onPick: cubit.jumpTo,
    );
  }

  Widget _buildStatCardsRow(AnalyticsData data) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.arrow_downward_rounded,
            title: 'Thu nhập',
            value: data.totalIncome,
            soft: AppColors.incomeSoft,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.arrow_upward_rounded,
            title: 'Chi tiêu',
            value: data.totalExpense,
            soft: AppColors.expenseSoft,
            color: AppColors.expense,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Số dư',
            value: data.balance,
            soft: AppColors.balanceSoft,
            color: AppColors.balance,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required double value,
    required Color soft,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(title, style: AppText.caption),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatMoneyShort(value),
              style: AppText.moneyLarge.copyWith(fontSize: 18, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(AnalyticsData data) {
    final hasPrev = data.previousExpense > 0;
    final noun = data.period.nounLower;
    final diff = data.totalExpense - data.previousExpense;
    final percent = hasPrev ? (diff.abs() / data.previousExpense * 100).round() : 0;
    final isUp = diff > 0; // chi nhiều hơn kỳ trước = xấu

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('So với $noun trước', style: AppText.caption.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                if (hasPrev)
                  Row(
                    children: [
                      Flexible(
                        child: Text(_formatMoneyShort(data.previousExpense),
                            style: AppText.moneyMedium.copyWith(color: AppColors.textMuted)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textMuted),
                      ),
                      Flexible(
                        child: Text(_formatMoneyShort(data.totalExpense),
                            style: AppText.moneyMedium.copyWith(color: AppColors.textPrimary)),
                      ),
                    ],
                  )
                else
                  Text('Chưa có dữ liệu chi tiêu $noun trước', style: AppText.caption),
              ],
            ),
          ),
          if (hasPrev && diff != 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isUp ? AppColors.expenseSoft : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isUp ? Icons.trending_up : Icons.trending_down,
                      size: 16, color: isUp ? AppColors.expense : AppColors.primaryDark),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${isUp ? '+' : '-'}$percent%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isUp ? AppColors.expense : AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AnalyticsData data) {
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
            child: const Icon(Icons.insights_outlined, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Chưa có dữ liệu ${data.period.nounLower} này', style: AppText.sectionTitle),
          const SizedBox(height: 6),
          Text(
            'Thêm giao dịch để xem biểu đồ chi tiêu theo danh mục.',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownSection(AnalyticsData data) {
    if (data.categoryBreakdowns.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chi tiêu theo danh mục', style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.lg),
          _buildDonut(data),
          const SizedBox(height: AppSpacing.lg),
          ...data.categoryBreakdowns.map(_buildCategoryRow),
        ],
      ),
    );
  }

  Widget _buildDonut(AnalyticsData data) {
    final items = data.categoryBreakdowns;
    return SizedBox(
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 66,
              sections: items
                  .map((i) => PieChartSectionData(
                        value: i.amount,
                        color: categoryColor(i.category.color),
                        radius: 24,
                        showTitle: false,
                      ))
                  .toList(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tổng chi', style: AppText.caption),
              const SizedBox(height: 2),
              MoneyText(
                data.totalExpense,
                style: AppText.moneyLarge.copyWith(fontSize: 20, color: AppColors.textPrimary),
                unitScale: 0.6,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(CategoryBreakdown item) {
    final color = categoryColor(item.category.color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.chip)),
                child: Icon(categoryIcon(item.category.icon), size: 18, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  item.category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormat.vnd.format(item.amount),
                    style: AppText.moneyMedium.copyWith(fontSize: 14, color: AppColors.textPrimary),
                  ),
                  Text('${item.percentage.round()}%', style: AppText.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: (item.percentage / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopExpensesSection(AnalyticsData data) {
    if (data.topExpenses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.isCurrent ? 'Chi tiêu lớn nhất ${data.period.nounLower} này' : 'Chi tiêu lớn nhất trong kỳ',
          style: AppText.sectionTitle,
        ),
        const SizedBox(height: AppSpacing.lg),
        Column(
          children: [
            for (var i = 0; i < data.topExpenses.length; i++)
              _buildExpenseCard(data.topExpenses[i], data.categories, i + 1),
          ],
        ),
      ],
    );
  }

  Widget _buildExpenseCard(TransactionModel item, Map<String, CategoryModel> categories, int rank) {
    final cat = categories[item.categoryId] ?? categories[CategoryRepository.legacyNameToId[item.categoryId]];
    final catName = cat?.name ?? 'Khác';
    final catColor = categoryColor(cat?.color);
    final hasPhoto = item.localThumbnailPath != null || item.localImagePath != null || item.cloudImageUrl != null;

    Widget thumb;
    if (item.localThumbnailPath != null || item.localImagePath != null) {
      thumb = SafeFileImage(
        path: item.localThumbnailPath,
        fallbackPath: item.localImagePath,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
      );
    } else if (item.cloudImageUrl != null) {
      thumb = Image.network(
        item.cloudImageUrl!,
        errorBuilder: (_, __, ___) => const SafeFileImage(path: null),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
      );
    } else {
      thumb = Container(
        width: 56,
        height: 56,
        color: catColor.withValues(alpha: 0.14),
        child: Icon(categoryIcon(cat?.icon), color: catColor),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(AppRadius.md), child: thumb),
              Positioned(
                top: -6,
                left: -6,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank == 1 ? AppColors.warning : AppColors.textPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(hasPhoto ? Icons.photo_outlined : categoryIcon(cat?.icon), size: 13, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(catName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _formatMoneyShort(item.amount),
            style: AppText.moneyMedium.copyWith(color: AppColors.expense),
          ),
        ],
      ),
    );
  }
}

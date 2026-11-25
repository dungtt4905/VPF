import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/currency/currency_format.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/enums.dart';
import '../../../models/transaction_model.dart';
import '../../../shared/widgets/period_selector.dart';
import '../../../shared/widgets/transaction_image.dart';
import '../../analytics/cubit/analytics_cubit.dart' show AnalyticsPeriod;
import '../../category/category_style.dart';
import '../../../core/repositories/category_repository.dart';
import '../edit_transaction_screen.dart';
import '../payment_methods.dart';
import 'transaction_filter_sheet.dart';
import 'transaction_list_cubit.dart';

/// Danh sách giao dịch dạng text (không ảnh), lọc theo loại/danh mục/ngân sách/số tiền, xem theo tuần hoặc tháng.
class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TransactionListCubit(getIt(), getIt(), getIt()),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  String _money(double v) => CurrencyFormat.vnd.format(v);

  Future<void> _openFilter(BuildContext context, TransactionListData d) async {
    final cubit = context.read<TransactionListCubit>();
    final result = await showTransactionFilterSheet(
      context,
      initial: d.filter,
      categories: d.categories.values.toList(),
      jars: d.jars,
    );
    if (result != null) cubit.setFilter(result);
  }

  Future<void> _confirmDelete(BuildContext context, int count) async {
    final cubit = context.read<TransactionListCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text('Xóa $count giao dịch?'),
        content: Text('Bạn có chắc muốn xóa $count giao dịch đã chọn? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
            ),
            child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await cubit.deleteSelected();
      messenger.showSnackBar(SnackBar(content: Text('Đã xóa $count giao dịch')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Không xóa được giao dịch, vui lòng thử lại')));
    }
  }

  void _openEdit(BuildContext context, TransactionModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditTransactionScreen(
        id: item.id,
        syncId: item.syncId,
        title: item.title,
        category: item.categoryId,
        amount: item.amount,
        paymentMethod: item.paymentMethod,
        note: item.note,
        imageUrl: item.cloudImageUrl,
        localImagePath: item.localImagePath,
        localThumbnailPath: item.localThumbnailPath,
        date: item.transactionAt,
        type: item.type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionListCubit, TransactionListState>(
      builder: (context, state) {
        final selecting = state is TransactionListLoaded && state.isSelecting;
        // Đang chọn để xóa thì nút Back chỉ thoát chế độ chọn, chưa rời màn hình.
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.read<TransactionListCubit>().stopSelecting();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: state is TransactionListLoaded
                  ? _body(context, state)
                  : const Center(child: CircularProgressIndicator()),
            ),
            bottomNavigationBar: state is TransactionListLoaded && state.isSelecting ? _deleteBar(context, state) : null,
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, TransactionListLoaded state) {
    final d = state.data;
    final cubit = context.read<TransactionListCubit>();
    return Column(
      children: [
        _header(context, state),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: PeriodSelector(
            period: d.period,
            start: d.start,
            end: d.end,
            isCurrent: d.isCurrent,
            onPrevious: cubit.previous,
            onNext: cubit.next,
            onCurrent: cubit.goToCurrent,
            onPick: cubit.jumpTo,
          ),
        ),
        _activeFilters(context, d),
        _summary(d),
        if (state.isSelecting) _selectAll(context, state),
        Expanded(child: d.items.isEmpty ? _empty(context, d) : _list(context, state)),
      ],
    );
  }

  Widget _selectAll(BuildContext context, TransactionListLoaded state) {
    final cubit = context.read<TransactionListCubit>();
    final enabled = state.data.items.isNotEmpty;
    return Padding(
      // Lề thêm 1px để ô này thẳng cột với checkbox trong thẻ (thẻ có viền 1px).
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page + 1),
      child: InkWell(
        onTap: enabled ? cubit.toggleSelectAll : null,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Row(
          children: [
            Checkbox(
              tristate: true,
              value: state.isAllSelected ? true : (state.selected!.isEmpty ? false : null),
              onChanged: enabled ? (_) => cubit.toggleSelectAll() : null,
              activeColor: AppColors.primary,
            ),
            const Text('Chọn tất cả',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _deleteBar(BuildContext context, TransactionListLoaded state) {
    final count = state.selected!.length;
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: context.read<TransactionListCubit>().stopSelecting,
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: count == 0 ? null : () => _confirmDelete(context, count),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: Text('Xóa ($count)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, TransactionListLoaded state) {
    final d = state.data;
    final cubit = context.read<TransactionListCubit>();
    Widget tab(String label, AnalyticsPeriod p) {
      final selected = d.period == p;
      return Expanded(
        child: GestureDetector(
          onTap: () => cubit.setPeriod(p),
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

    final count = d.filter.activeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back),
          ),
          // Màn hẹp thì tiêu đề tự thu nhỏ, không xuống dòng.
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('Giao dịch',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ),
          ),
          Container(
            width: 112,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.card)),
            child: Row(children: [tab('Tuần', AnalyticsPeriod.week), tab('Tháng', AnalyticsPeriod.month)]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            backgroundColor: AppColors.primary,
            child: IconButton.filledTonal(
              onPressed: () => _openFilter(context, d),
              tooltip: 'Bộ lọc',
              style: IconButton.styleFrom(backgroundColor: AppColors.primarySoft, foregroundColor: AppColors.primaryDark),
              icon: const Icon(Icons.filter_list_rounded),
            ),
          ),
          IconButton(
            // Không có gì để xóa thì khóa nút; đang chọn thì luôn bấm được để thoát.
            onPressed: state.isSelecting ? cubit.stopSelecting : (d.items.isEmpty ? null : cubit.startSelecting),
            tooltip: state.isSelecting ? 'Hủy chọn' : 'Xóa',
            visualDensity: VisualDensity.compact,
            color: AppColors.expense,
            icon: Icon(state.isSelecting ? Icons.close : Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  /// Chip các bộ lọc đang bật; bấm dấu x để bỏ từng nhóm.
  Widget _activeFilters(BuildContext context, TransactionListData d) {
    final f = d.filter;
    if (!f.isActive) return const SizedBox(height: AppSpacing.sm);
    final cubit = context.read<TransactionListCubit>();

    final chips = <Widget>[];
    Widget chip(String group, String label) => InputChip(
          label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
          onDeleted: () => cubit.removeGroup(group),
          deleteIconColor: AppColors.primaryDark,
          backgroundColor: AppColors.primarySoft,
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        );

    if (f.type != null) chips.add(chip('type', f.type == TransactionType.expense ? 'Chi' : 'Thu'));
    if (f.categoryIds.isNotEmpty) {
      final names = [for (final id in f.categoryIds) d.categories[id]?.name ?? 'Khác'];
      chips.add(chip('category', names.length <= 2 ? names.join(', ') : '${names.length} danh mục'));
    }
    if (f.hasBudgetFilter) {
      final names = <String>[
        for (final j in d.jars)
          if (f.jarKeys.contains(j.key)) j.name,
        if (f.noBudget) 'Chưa có ngân sách',
      ];
      chips.add(chip('budget', names.isEmpty ? 'Ngân sách' : (names.length <= 2 ? names.join(', ') : '${names.length} ngân sách')));
    }
    if (f.minAmount != null || f.maxAmount != null) {
      final label = f.minAmount != null && f.maxAmount != null
          ? '${CurrencyFormat.vnd.compact(f.minAmount!)} – ${CurrencyFormat.vnd.compact(f.maxAmount!)}'
          : f.minAmount != null
              ? 'Từ ${CurrencyFormat.vnd.compact(f.minAmount!)}'
              : 'Đến ${CurrencyFormat.vnd.compact(f.maxAmount!)}';
      chips.add(chip('amount', label));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: AppSpacing.sm, children: chips),
      ),
    );
  }

  Widget _summary(TransactionListData d) {
    final filtered = d.filter.isActive;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
      child: Row(
        children: [
          Text(filtered ? '${d.items.length}/${d.periodCount} giao dịch' : '${d.items.length} giao dịch', style: AppText.caption),
          const SizedBox(width: AppSpacing.md),
          // Phần tiền co lại vừa chỗ còn lại thay vì tràn khi số lớn.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (d.totalExpense > 0)
                    Text('Chi ${_money(d.totalExpense)}', style: AppText.moneySmall.copyWith(color: AppColors.expense)),
                  if (d.totalExpense > 0 && d.totalIncome > 0) const SizedBox(width: AppSpacing.md),
                  if (d.totalIncome > 0)
                    Text('Thu ${_money(d.totalIncome)}', style: AppText.moneySmall.copyWith(color: AppColors.income)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, TransactionListData d) {
    final filtered = d.filter.isActive;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(filtered ? Icons.filter_alt_off_outlined : Icons.receipt_long_outlined, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(filtered ? 'Không có giao dịch khớp bộ lọc' : 'Không có giao dịch trong kỳ này', style: AppText.caption),
          if (filtered)
            TextButton(onPressed: context.read<TransactionListCubit>().clearFilter, child: const Text('Xóa bộ lọc')),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, TransactionListLoaded state) {
    final d = state.data;
    // Nhóm theo ngày (items đã sắp mới nhất trước nên thứ tự nhóm cũng vậy).
    final groups = <DateTime, List<TransactionModel>>{};
    for (final t in d.items) {
      final k = DateTime(t.transactionAt.year, t.transactionAt.month, t.transactionAt.day);
      groups.putIfAbsent(k, () => []).add(t);
    }
    final days = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final items = groups[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dayHeader(day, items),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var j = 0; j < items.length; j++) ...[
                    if (j > 0) Divider(height: 1, indent: state.isSelecting ? 112 : 64, color: AppColors.border),
                    if (state.isSelecting) _selectableRow(context, state, items[j]) else _row(context, d, items[j]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dayHeader(DateTime day, List<TransactionModel> items) {
    final spent = items.where((t) => t.type == TransactionType.expense).fold<double>(0, (s, t) => s + t.amount);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(DateFormat('EEEE, d/M/yyyy', 'vi').format(day),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const Spacer(),
          if (spent > 0) Text('-${CurrencyFormat.vnd.compact(spent)}', style: AppText.moneySmall.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _leading(TransactionModel t, dynamic cat, Color color) {
    final radius = BorderRadius.circular(AppRadius.chip);
    Widget? image;
    if (t.localThumbnailPath != null || t.localImagePath != null) {
      image = SafeFileImage(path: t.localThumbnailPath, fallbackPath: t.localImagePath, cacheWidth: 150, fit: BoxFit.cover);
    } else if (t.cloudImageUrl != null) {
      image = Image.network(t.cloudImageUrl!,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SafeFileImage(path: null));
    }
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: radius),
      child: image ?? Icon(categoryIcon(cat?.icon), color: color, size: 20),
    );
  }

  /// Chỉ checkbox mới chọn giao dịch; bấm vùng thông tin vẫn mở màn sửa để xem lại.
  Widget _selectableRow(BuildContext context, TransactionListLoaded state, TransactionModel t) {
    return Row(
      key: ValueKey(t.id),
      children: [
        Checkbox(
          value: state.selected!.contains(t.id),
          onChanged: (_) => context.read<TransactionListCubit>().toggleSelected(t.id),
          activeColor: AppColors.primary,
          semanticLabel: 'Chọn ${t.title}',
        ),
        Expanded(child: _row(context, state.data, t)),
      ],
    );
  }

  Widget _row(BuildContext context, TransactionListData d, TransactionModel t) {
    final cat = d.categories[t.categoryId] ?? d.categories[CategoryRepository.legacyNameToId[t.categoryId]];
    final color = categoryColor(cat?.color);
    final catName = cat?.name ?? (t.categoryId.length >= 32 && t.categoryId.contains('-') ? 'Chưa phân loại' : t.categoryId);
    final isExpense = t.type == TransactionType.expense;
    final hasNote = t.note != null && t.note!.isNotEmpty;

    return InkWell(
      onTap: () => _openEdit(context, t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            _leading(t, cat, color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    [catName, DateFormat('HH:mm').format(t.transactionAt), paymentLabel(t.paymentMethod)].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                  if (hasNote)
                    Text(t.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${isExpense ? '-' : '+'}${_money(t.amount)}',
                  style: AppText.moneyMedium.copyWith(color: isExpense ? AppColors.expense : AppColors.income),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

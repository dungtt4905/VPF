import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/currency/currency_format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../category/category_style.dart';
import 'cubit/budget_cubit.dart';

/// Các danh mục có chi tiêu trong tháng nhưng chưa thuộc hũ nào; chọn một hũ để xếp từng danh mục vào.
Future<void> showUnassignedSheet(BuildContext context) {
  final cubit = context.read<BudgetCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero))),
    builder: (_) => BlocProvider.value(value: cubit, child: const _UnassignedSheet()),
  );
}

class _UnassignedSheet extends StatelessWidget {
  const _UnassignedSheet();

  /// Chọn hũ đích rồi chuyển danh mục vào. Hũ tổng không nhận danh mục riêng nên không có trong danh sách.
  Future<void> _assign(BuildContext context, UnassignedSpend u, List<BudgetData> jars) async {
    final cubit = context.read<BudgetCubit>();
    final target = await showDialog<BudgetData>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Xếp "${u.category.name}" vào hũ'),
        children: [
          for (final j in jars)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, j),
              child: Text(j.name, style: const TextStyle(fontSize: 15)),
            ),
        ],
      ),
    );
    if (target != null) await cubit.moveCategory(u.category.syncId, target.jar.syncId);
  }

  @override
  Widget build(BuildContext context) {
    final money = CurrencyFormat.vnd;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: BlocBuilder<BudgetCubit, BudgetState>(
            builder: (context, state) {
              if (state is! BudgetLoaded) return const SizedBox.shrink();
              final jars = state.budgets.where((b) => !b.isTotal).toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chưa vào hũ nào', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Chi tiêu tháng này của các danh mục chưa thuộc hũ nào.', style: AppText.caption),
                  const SizedBox(height: AppSpacing.lg),
                  if (state.unassigned.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: Text('Mọi khoản chi đã nằm trong hũ.', style: AppText.caption)),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final u in state.unassigned)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(categoryIcon(u.category.icon), color: categoryColor(u.category.color)),
                              title: Text(u.category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(money.compact(u.amount), style: AppText.caption),
                              trailing: TextButton(
                                onPressed: jars.isEmpty ? null : () => _assign(context, u, jars),
                                child: const Text('Chọn hũ'),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

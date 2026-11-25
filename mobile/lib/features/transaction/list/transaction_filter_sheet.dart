import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/currency/amount_input_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/category_model.dart';
import '../../../models/enums.dart';
import 'transaction_filter.dart';
import 'transaction_list_cubit.dart';

/// Mở bảng lọc; trả về bộ lọc mới khi bấm "Áp dụng" (null nếu đóng mà không áp dụng).
Future<TransactionFilter?> showTransactionFilterSheet(
  BuildContext context, {
  required TransactionFilter initial,
  required List<CategoryModel> categories,
  required List<JarOption> jars,
}) {
  return showModalBottomSheet<TransactionFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
    ),
    builder: (_) => _FilterSheet(initial: initial, categories: categories, jars: jars),
  );
}

class _FilterSheet extends StatefulWidget {
  final TransactionFilter initial;
  final List<CategoryModel> categories;
  final List<JarOption> jars;
  const _FilterSheet({required this.initial, required this.categories, required this.jars});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TransactionType? _type = widget.initial.type;
  late Set<String> _categoryIds = {...widget.initial.categoryIds};
  late Set<String> _jarKeys = {...widget.initial.jarKeys};
  late bool _noBudget = widget.initial.noBudget;
  late final TextEditingController _min = TextEditingController(
      text: widget.initial.minAmount == null ? '' : AmountInputFormatter.format(widget.initial.minAmount!));
  late final TextEditingController _max = TextEditingController(
      text: widget.initial.maxAmount == null ? '' : AmountInputFormatter.format(widget.initial.maxAmount!));
  String? _error;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  double? _parse(String s) {
    final digits = s.replaceAll('.', '');
    return digits.isEmpty ? null : double.tryParse(digits);
  }

  void _setType(TransactionType? t) {
    setState(() {
      _type = t;
      // Bỏ các danh mục không còn thuộc loại đang chọn.
      if (t != null) {
        final valid = {for (final c in widget.categories.where((c) => c.type == t)) c.syncId};
        _categoryIds = _categoryIds.where(valid.contains).toSet();
      }
      // Ngân sách chỉ áp dụng cho khoản chi.
      if (t == TransactionType.income) {
        _jarKeys = {};
        _noBudget = false;
      }
    });
  }

  void _reset() {
    setState(() {
      _type = null;
      _categoryIds = {};
      _jarKeys = {};
      _noBudget = false;
      _min.clear();
      _max.clear();
      _error = null;
    });
  }

  void _apply() {
    final min = _parse(_min.text);
    final max = _parse(_max.text);
    if (min != null && max != null && min > max) {
      setState(() => _error = 'Số tiền "Từ" phải nhỏ hơn hoặc bằng "Đến"');
      return;
    }
    Navigator.pop(
      context,
      TransactionFilter(
        type: _type,
        categoryIds: _categoryIds,
        jarKeys: _jarKeys,
        noBudget: _noBudget,
        minAmount: min,
        maxAmount: max,
      ),
    );
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: AppColors.primarySoft,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
        ),
      );

  void _toggle(Set<String> set, String id) => setState(() => set.contains(id) ? set.remove(id) : set.add(id));

  Widget _amountField(String label, TextEditingController c) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, const AmountInputFormatter()],
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: label,
            suffixText: 'đ',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories.where((c) => _type == null || c.type == _type).toList()
      ..sort((a, b) => a.type != b.type ? a.type.index.compareTo(b.type.index) : a.name.compareTo(b.name));
    final budgetDisabled = _type == TransactionType.income;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.sm, AppSpacing.sm),
            child: Row(
              children: [
                const Expanded(child: Text('Bộ lọc', style: AppText.sectionTitle)),
                TextButton(onPressed: _reset, child: const Text('Đặt lại')),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(
                    'Loại giao dịch',
                    Wrap(spacing: AppSpacing.sm, children: [
                      _chip('Tất cả', _type == null, () => _setType(null)),
                      _chip('Chi', _type == TransactionType.expense, () => _setType(TransactionType.expense)),
                      _chip('Thu', _type == TransactionType.income, () => _setType(TransactionType.income)),
                    ]),
                  ),
                  _section(
                    'Danh mục',
                    cats.isEmpty
                        ? const Text('Chưa có danh mục', style: AppText.caption)
                        : Wrap(spacing: AppSpacing.sm, children: [
                            for (final c in cats) _chip(c.name, _categoryIds.contains(c.syncId), () => _toggle(_categoryIds, c.syncId)),
                          ]),
                  ),
                  if (!budgetDisabled)
                    _section(
                      'Ngân sách (khoản chi)',
                      Wrap(spacing: AppSpacing.sm, children: [
                        for (final j in widget.jars) _chip(j.name, _jarKeys.contains(j.key), () => _toggle(_jarKeys, j.key)),
                        _chip('Chưa có ngân sách', _noBudget, () => setState(() => _noBudget = !_noBudget)),
                      ]),
                    ),
                  _section(
                    'Số tiền',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _amountField('Từ', _min),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
                          _amountField('Đến', _max),
                        ]),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.expense)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: const Text('Áp dụng', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

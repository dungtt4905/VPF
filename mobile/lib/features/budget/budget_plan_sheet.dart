import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/budget/budget_planner.dart';
import '../../core/currency/amount_input_formatter.dart';
import '../../core/currency/currency_format.dart';
import 'budget_form_sheet.dart';
import 'budget_save_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../category/category_style.dart';
import 'cubit/budget_cubit.dart';

/// Lập kế hoạch tháng: nhập thu nhập dự kiến rồi chia cho các hũ theo % (hoặc nhập thẳng số tiền).
/// Không dựa trên giao dịch nên dùng được ngay từ đầu tháng. Thu nhập được lưu vào kế hoạch của tháng.
Future<void> showBudgetPlan(BuildContext context) async {
  final cubit = context.read<BudgetCubit>();
  final state = cubit.state;
  if (state is! BudgetLoaded) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero))),
    builder: (_) => BlocProvider.value(value: cubit, child: _PlanSheet(state: state)),
  );
}

class _RowState {
  final BudgetData data;
  final TextEditingController pct = TextEditingController();
  final TextEditingController amt;

  /// true nếu người dùng nhập % gần nhất (số tiền suy ra từ %); false thì % suy ra từ số tiền.
  bool byPercent = false;

  _RowState(this.data) : amt = TextEditingController(text: AmountInputFormatter.format(data.jar.amount));

  String get id => data.jar.syncId;
  double get amount => parseAmount(amt.text) ?? 0;

  void dispose() {
    pct.dispose();
    amt.dispose();
  }
}

class _PlanSheet extends StatefulWidget {
  final BudgetLoaded state;
  const _PlanSheet({required this.state});

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  late final TextEditingController _income;
  late final List<_RowState> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    _income = TextEditingController(text: s.expectedIncome > 0 ? AmountInputFormatter.format(s.expectedIncome) : '');
    // Hũ tổng không tham gia chia thu nhập.
    _rows = [for (final b in s.budgets.where((b) => !b.isTotal)) _RowState(b)];
    _syncPercents();
  }

  @override
  void dispose() {
    _income.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double get _incomeValue => parseAmount(_income.text) ?? 0;

  static double? _parsePercent(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  static String _fmtPercent(double v) {
    if (v <= 0) return '';
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  /// Tính lại ô còn lại của mỗi dòng theo thu nhập hiện tại (không kích hoạt onChanged).
  void _syncPercents() {
    final income = _incomeValue;
    for (final r in _rows) {
      if (r.byPercent) {
        final a = BudgetPlanner.amountFromPercent(income, _parsePercent(r.pct.text) ?? 0);
        r.amt.text = a > 0 ? AmountInputFormatter.format(a) : '';
      } else {
        r.pct.text = _fmtPercent(BudgetPlanner.percentFromAmount(income, r.amount));
      }
    }
  }

  void _onPercentChanged(_RowState r) {
    r.byPercent = true;
    final a = BudgetPlanner.amountFromPercent(_incomeValue, _parsePercent(r.pct.text) ?? 0);
    r.amt.text = a > 0 ? AmountInputFormatter.format(a) : '';
    setState(() {});
  }

  void _onAmountChanged(_RowState r) {
    r.byPercent = false;
    r.pct.text = _fmtPercent(BudgetPlanner.percentFromAmount(_incomeValue, r.amount));
    setState(() {});
  }

  double get _allocated => _rows.fold(0.0, (s, r) => s + r.amount);

  /// Mở form hũ mới rồi thêm các hũ vừa tạo vào danh sách.
  Future<void> _addJar() async {
    final cubit = context.read<BudgetCubit>();
    await showBudgetForm(context);
    final s = cubit.state;
    if (!mounted || s is! BudgetLoaded) return;
    final known = _rows.map((r) => r.id).toSet();
    setState(() {
      for (final b in s.budgets.where((b) => !b.isTotal && !known.contains(b.jar.syncId))) {
        _rows.add(_RowState(b));
      }
      _syncPercents();
    });
  }

  Future<void> _save() async {
    final cubit = context.read<BudgetCubit>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    await cubit.applyPlan(
      income: _incomeValue,
      amountByJar: {for (final r in _rows) if (r.amount > 0) r.id: r.amount},
    );
    nav.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Đã lưu kế hoạch tháng')));
  }

  @override
  Widget build(BuildContext context) {
    final money = CurrencyFormat.vnd;
    final income = _incomeValue;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kế hoạch tháng ${DateTime.now().month}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Chia thu nhập vào các hũ chi tiêu. Nhập % hoặc số tiền đều được.',
                style: AppText.caption.copyWith(fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _income,
                keyboardType: TextInputType.number,
                inputFormatters: const [AmountInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Thu nhập dự kiến mỗi tháng',
                  suffixText: money.symbol,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                ),
                onChanged: (_) {
                  _syncPercents();
                  setState(() {});
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (_rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text(
                      'Chưa có hũ nào. Hãy thêm hũ đầu tiên.',
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(fontSize: 13),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [for (final r in _rows) _itemRow(r, income > 0)],
                  ),
                ),
              TextButton.icon(
                onPressed: _addJar,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm hũ mới'),
              ),
              if (_rows.isNotEmpty) ...[
                const Divider(height: AppSpacing.xl),
                _summary(income, _allocated),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                    ),
                    child: const Text('Lưu kế hoạch',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemRow(_RowState r, bool hasIncome) {
    final single = r.data.categories.length == 1 ? r.data.categories.first : null;
    final color = single == null ? AppColors.primary : categoryColor(single.color);
    InputDecoration deco({String? suffix}) => InputDecoration(
          isDense: true,
          suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(single == null ? Icons.account_balance_wallet_outlined : categoryIcon(single.icon),
                  size: 20, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(r.data.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: r.pct,
                  enabled: hasIncome,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: deco(suffix: '%'),
                  onChanged: (_) => _onPercentChanged(r),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: r.amt,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  inputFormatters: const [AmountInputFormatter()],
                  decoration: deco(suffix: CurrencyFormat.vnd.symbol),
                  onChanged: (_) => _onAmountChanged(r),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summary(double income, double allocated) {
    final money = CurrencyFormat.vnd;
    if (income <= 0) {
      return _line('Tổng đã phân bổ', money.compact(allocated), AppColors.textPrimary);
    }
    final pct = allocated / income * 100;
    final over = allocated > income;
    final color = over ? AppColors.expense : AppColors.primaryDark;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (allocated / income).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.primarySoft,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _line(
          'Đã phân bổ ${_fmtPercent(pct).isEmpty ? '0' : _fmtPercent(pct)}%',
          over ? 'Vượt ${money.compact(allocated - income)}' : 'Còn ${money.compact(income - allocated)}',
          color,
        ),
      ],
    );
  }

  Widget _line(String label, String value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.caption.copyWith(fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      );
}

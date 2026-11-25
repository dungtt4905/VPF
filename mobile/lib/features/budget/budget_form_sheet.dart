import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/currency/amount_input_formatter.dart';
import '../../core/currency/currency_format.dart';
import 'budget_save_guard.dart';
import '../../models/category_model.dart';
import '../category/category_style.dart';
import 'cubit/budget_cubit.dart';

/// Mở form thêm (editing == null) hoặc sửa một hũ ngân sách của kế hoạch tháng này.
Future<void> showBudgetForm(BuildContext context, {BudgetData? editing}) {
  final cubit = context.read<BudgetCubit>();
  final state = cubit.state;
  if (state is! BudgetLoaded) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero))),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _JarForm(editing: editing, state: state),
    ),
  );
}

/// Chừa chỗ cho bàn phím bên dưới form. Tách riêng để chỉ widget này dựng lại khi bàn phím trượt.
class _KeyboardPadding extends StatelessWidget {
  final Widget child;
  const _KeyboardPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final available = mq.size.height - keyboard - mq.padding.top - 16;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboard),
      child: SizedBox(height: (available * 0.9).clamp(240.0, mq.size.height), child: child),
    );
  }
}

class _JarForm extends StatefulWidget {
  final BudgetData? editing;
  final BudgetLoaded state;

  const _JarForm({required this.editing, required this.state});

  @override
  State<_JarForm> createState() => _JarFormState();
}

class _JarFormState extends State<_JarForm> {
  static const _green = AppColors.primary;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  final FocusNode _nameFocus = FocusNode();
  late Set<String> _selected;
  late bool _isTotal;
  late double _threshold;
  late bool _rollover;
  String? _nameError;
  String? _amountError;

  late final Map<String, CategoryModel> _catMap;
  late final List<CategoryModel> _parents;
  late final Map<String, List<CategoryModel>> _children;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _catMap = {for (final c in widget.state.expenseCategories) c.syncId: c};
    _parents = widget.state.expenseCategories.where((c) => c.parentId == null || !_catMap.containsKey(c.parentId)).toList();
    _children = {};
    for (final c in widget.state.expenseCategories) {
      if (c.parentId != null && _catMap.containsKey(c.parentId)) {
        _children.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _amountCtrl = TextEditingController(text: e == null ? '' : AmountInputFormatter.format(e.jar.amount));
    _selected = {...?e?.spec.categoryIds};
    _isTotal = e?.isTotal ?? false;
    _threshold = (e?.jar.alertThreshold ?? 80).toDouble().clamp(50, 100);
    _rollover = e?.jar.rollover ?? false;
    if (e == null) _focusAfterOpen();
  }

  /// Mở bàn phím sau khi form đã trượt lên xong. Nếu mở ngay (autofocus), bàn phím và form cùng
  /// animate một lúc nên bị giật.
  void _focusAfterOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) {
        _nameFocus.requestFocus();
        return;
      }
      late final AnimationStatusListener listener;
      listener = (status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(listener);
        if (mounted) _nameFocus.requestFocus();
      };
      animation.addStatusListener(listener);
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _commitment => !_isTotal && _selected.isEmpty;

  bool _isAncestor(String ancestor, String of) {
    final seen = <String>{};
    String? cur = _catMap[of]?.parentId;
    while (cur != null && seen.add(cur)) {
      if (cur == ancestor) return true;
      cur = _catMap[cur]?.parentId;
    }
    return false;
  }

  bool _overlaps(String a, String b) => a == b || _isAncestor(a, b) || _isAncestor(b, a);

  void _toggle(CategoryModel c, bool on) {
    setState(() {
      if (on) {
        _selected.add(c.syncId);
        // Chọn danh mục cha thì các con đã được bao gồm.
        _selected.removeWhere((id) => id != c.syncId && _isAncestor(c.syncId, id));
      } else {
        _selected.remove(c.syncId);
      }
    });
  }

  /// Tên các hũ khác đang giữ danh mục trùng (kể cả quan hệ cha/con) với lựa chọn hiện tại.
  Set<String> _conflictingJars() {
    final names = <String>{};
    final myJarId = widget.editing?.jar.syncId;
    for (final id in _selected) {
      for (final o in widget.state.owners.entries) {
        if (o.value.jarId != myJarId && _overlaps(id, o.key)) names.add(o.value.jarName);
      }
    }
    return names;
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final amount = parseAmount(_amountCtrl.text);
    setState(() {
      _nameError = name.isEmpty ? 'Vui lòng đặt tên hũ' : null;
      _amountError = amount == null || amount <= 0 ? 'Vui lòng nhập số tiền hợp lệ' : null;
    });
    if (_nameError != null || _amountError != null) return;

    final conflicts = _isTotal ? <String>{} : _conflictingJars();
    if (conflicts.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chuyển danh mục sang hũ này?'),
          content: Text('Một số danh mục đang nằm trong hũ ${conflicts.join(', ')}. '
              'Mỗi danh mục chỉ thuộc một hũ, nên chúng sẽ được chuyển sang hũ "$name".'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Chuyển')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final cubit = context.read<BudgetCubit>();
    final nav = Navigator.of(context);
    await cubit.saveJar(
      editing: widget.editing?.jar,
      name: name,
      amount: amount!,
      alertThreshold: _threshold.round(),
      rollover: _rollover,
      isTotal: _isTotal,
      categoryIds: _isTotal ? <String>{} : _selected,
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final currency = CurrencyFormat.vnd;
    final isEdit = widget.editing != null;

    // Chỉ widget bọc ngoài phụ thuộc vào chiều cao bàn phím, nên khi bàn phím trượt lên
    // phần nội dung form không bị dựng lại mỗi khung hình.
    final rows = _isTotal ? const <Widget>[] : [for (final p in _parents) ..._categoryRows(p)];
    return _KeyboardPadding(
      child: RepaintBoundary(
        // Danh mục dựng lười (SliverList) và chiều cao cố định theo màn hình, nên form
        // không phải đo lại toàn bộ checkbox mỗi khung hình khi trượt lên / bàn phím mở.
        child: CustomScrollView(
          shrinkWrap: false,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(isEdit ? 'Sửa hũ' : 'Hũ mới', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Tên hũ (ví dụ: Ăn uống, Tiền nhà)',
                  errorText: _nameError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: const [AmountInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Hạn mức mỗi tháng',
                  suffixText: currency.symbol,
                  errorText: _amountError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                ),
                onChanged: (_) {
                  if (_amountError != null) setState(() => _amountError = null);
                },
              ),
              if (widget.editing?.isTotal ?? false)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: _green,
                  title: const Text('Tính mọi khoản chi (hũ tổng)', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: _isTotal,
                  onChanged: (v) => setState(() => _isTotal = v),
                ),
              if (!_isTotal) ...[
                const SizedBox(height: AppSpacing.sm),
                const Text('Danh mục trong hũ', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
              ],
                ],
              ),
            ),
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) => rows[i],
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              if (!_commitment) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Cảnh báo khi dùng ${_threshold.round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: _threshold,
                  min: 50,
                  max: 100,
                  divisions: 10,
                  activeColor: _green,
                  label: '${_threshold.round()}%',
                  onChanged: (v) => setState(() => _threshold = v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: _green,
                  title: const Text('Chuyển số dư sang kỳ sau', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Tiền dư được cộng vào kỳ sau, khoản vượt sẽ bị trừ bớt.'),
                  value: _rollover,
                  onChanged: (v) => setState(() => _rollover = v),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                  ),
                  child: Text(isEdit ? 'Lưu thay đổi' : 'Tạo hũ',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _categoryRows(CategoryModel parent) {
    final parentOn = _selected.contains(parent.syncId);
    return [
      _categoryTile(parent, checked: parentOn, enabled: true, indent: 0),
      for (final child in _children[parent.syncId] ?? const <CategoryModel>[])
        _categoryTile(child, checked: parentOn || _selected.contains(child.syncId), enabled: !parentOn, indent: 28),
    ];
  }

  Widget _categoryTile(CategoryModel c, {required bool checked, required bool enabled, required double indent}) {
    final owner = widget.state.owners[c.syncId];
    final otherJar = owner != null && owner.jarId != widget.editing?.jar.syncId ? owner.jarName : null;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: _green,
        value: checked,
        onChanged: enabled ? (v) => _toggle(c, v == true) : null,
        title: Row(children: [
          Icon(categoryIcon(c.icon), size: 18, color: categoryColor(c.color)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
        ]),
        subtitle: otherJar == null ? null : Text('Đang ở hũ $otherJar', style: AppText.caption),
      ),
    );
  }
}

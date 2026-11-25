import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import '../../../core/repositories/budget_plan_repository.dart';
import '../../../core/repositories/category_repository.dart';
import '../../../core/repositories/transaction_repository.dart';
import '../../../models/budget_category_model.dart';
import '../../../models/budget_jar_model.dart';
import '../../../models/budget_plan_model.dart';
import '../../../models/category_model.dart';
import '../../../models/enums.dart';
import '../../../models/transaction_model.dart';
import '../../analytics/cubit/analytics_cubit.dart' show AnalyticsPeriod, AnalyticsPeriodX;
import 'transaction_filter.dart';

class JarOption {
  final String key;
  final String name;
  const JarOption(this.key, this.name);
}

class TransactionListData {
  final AnalyticsPeriod period;
  final DateTime start;
  final DateTime end;
  final bool isCurrent;
  final TransactionFilter filter;
  final List<TransactionModel> items; // đã lọc, mới nhất trước
  final int periodCount; // số giao dịch trong kỳ trước khi lọc
  final double totalIncome;
  final double totalExpense;
  final Map<String, CategoryModel> categories; // syncId -> category
  final List<JarOption> jars;

  const TransactionListData({
    required this.period,
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.filter,
    required this.items,
    required this.periodCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.categories,
    required this.jars,
  });
}

abstract class TransactionListState {}

class TransactionListLoading extends TransactionListState {}

class TransactionListLoaded extends TransactionListState {
  final TransactionListData data;

  /// id các giao dịch đang được tick; null nghĩa là không ở chế độ chọn để xóa.
  final Set<int>? selected;
  TransactionListLoaded(this.data, {this.selected});

  bool get isSelecting => selected != null;
  bool get isAllSelected => data.items.isNotEmpty && selected?.length == data.items.length;
}

typedef _Selection = ({AnalyticsPeriod period, DateTime anchor});

class TransactionListCubit extends Cubit<TransactionListState> {
  final TransactionRepository _txRepo;
  final CategoryRepository _catRepo;
  final BudgetPlanRepository _planRepo;
  StreamSubscription? _subscription;

  final _selection = BehaviorSubject<_Selection>.seeded(
    (period: AnalyticsPeriod.month, anchor: DateTime.now()),
  );
  final _filter = BehaviorSubject<TransactionFilter>.seeded(TransactionFilter.empty);

  TransactionListCubit(this._txRepo, this._catRepo, this._planRepo) : super(TransactionListLoading()) {
    _subscription = Rx.combineLatest7<List<TransactionModel>, List<CategoryModel>, List<BudgetPlanModel>,
        List<BudgetJarModel>, List<BudgetCategoryModel>, _Selection, TransactionFilter, TransactionListData>(
      _txRepo.watchAllTransactions(),
      _catRepo.watchAllCategories(),
      _planRepo.watchPlans(),
      _planRepo.watchJars(),
      _planRepo.watchLinks(),
      _selection,
      _filter,
      _compute,
    ).listen(_onData);
  }

  /// Giao dịch bị ẩn (đổi bộ lọc, đổi kỳ, bị xóa...) sẽ tự bỏ tick: chỉ xóa được thứ đang nhìn thấy.
  void _onData(TransactionListData d) {
    final current = state;
    final selected = current is TransactionListLoaded ? current.selected : null;
    emit(TransactionListLoaded(d, selected: selected?.intersection({for (final t in d.items) t.id})));
  }

  // ---- Chọn nhiều để xóa ----

  void startSelecting() => _select((_) => <int>{});

  void stopSelecting() => _select((_) => null);

  void toggleSelected(int id) => _select((current) {
        final selected = current.selected;
        if (selected == null) return null;
        return selected.contains(id) ? selected.difference({id}) : {...selected, id};
      });

  /// Chọn tất cả giao dịch đang hiển thị, hoặc bỏ chọn hết nếu đã chọn đủ.
  void toggleSelectAll() => _select((current) {
        if (!current.isSelecting) return null;
        return current.isAllSelected ? <int>{} : {for (final t in current.data.items) t.id};
      });

  Future<void> deleteSelected() async {
    final current = state;
    if (current is! TransactionListLoaded) return;
    final ids = current.selected;
    if (ids == null || ids.isEmpty) return;
    await _txRepo.deleteTransactions(ids);
    if (!isClosed) stopSelecting();
  }

  void _select(Set<int>? Function(TransactionListLoaded current) change) {
    final current = state;
    if (current is TransactionListLoaded) {
      emit(TransactionListLoaded(current.data, selected: change(current)));
    }
  }

  // ---- Kỳ (cùng logic với màn Phân tích) ----

  void setPeriod(AnalyticsPeriod period) {
    final sel = _selection.value;
    if (sel.period != period) _selection.add((period: period, anchor: sel.anchor));
  }

  void jumpTo(DateTime date) {
    final now = DateTime.now();
    _selection.add((period: _selection.value.period, anchor: date.isAfter(now) ? now : date));
  }

  void goToCurrent() => jumpTo(DateTime.now());

  void previous() {
    final sel = _selection.value;
    _selection.add((period: sel.period, anchor: sel.period.previousStart(sel.period.startOf(sel.anchor))));
  }

  void next() {
    final sel = _selection.value;
    final nextStart = sel.period.nextStart(sel.period.startOf(sel.anchor));
    if (nextStart.isAfter(DateTime.now())) return;
    _selection.add((period: sel.period, anchor: nextStart));
  }

  // ---- Bộ lọc ----

  void setFilter(TransactionFilter f) => _filter.add(f);
  void clearFilter() => _filter.add(TransactionFilter.empty);

  /// Bỏ riêng từng nhóm (dùng cho chip "đang lọc").
  void removeGroup(String group) {
    final f = _filter.value;
    _filter.add(switch (group) {
      'type' => f.copyWith(clearType: true),
      'category' => f.copyWith(categoryIds: {}),
      'budget' => f.copyWith(jarKeys: {}, noBudget: false),
      'amount' => f.copyWith(clearMin: true, clearMax: true),
      _ => f,
    });
  }

  // ---- Tính toán ----

  TransactionListData _compute(
    List<TransactionModel> txs,
    List<CategoryModel> cats,
    List<BudgetPlanModel> plans,
    List<BudgetJarModel> jars,
    List<BudgetCategoryModel> links,
    _Selection sel,
    TransactionFilter filter,
  ) {
    final start = sel.period.startOf(sel.anchor);
    final end = sel.period.nextStart(start);
    final now = DateTime.now();

    final inPeriod = txs.where((t) => !t.transactionAt.isBefore(start) && t.transactionAt.isBefore(end)).toList();

    final childrenOf = <String, List<String>>{};
    for (final c in cats) {
      final p = c.parentId;
      if (p != null) childrenOf.putIfAbsent(p, () => []).add(c.syncId);
    }
    final resolver = BudgetResolver(plans: plans, jars: jars, links: links);

    final items = filter.apply(inPeriod, childrenOf: childrenOf, jarKeyOf: resolver.jarKeyOf)
      ..sort((a, b) => b.transactionAt.compareTo(a.transactionAt));

    var income = 0.0, expense = 0.0;
    for (final t in items) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    // Các hũ của kế hoạch tháng hiện tại có gắn danh mục (hũ tổng/hũ cam kết không có gì để lọc).
    final current = plans.where((p) => p.periodStart == DateTime(now.year, now.month, 1)).firstOrNull;
    final jarOptions = <JarOption>[];
    if (current != null) {
      final linked = {for (final l in links.where((l) => l.planId == current.syncId)) l.jarId};
      final list = jars.where((j) => j.planId == current.syncId && !j.isTotal && linked.contains(j.syncId)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final j in list) {
        jarOptions.add(JarOption(j.jarKey, j.name));
      }
    }

    return TransactionListData(
      period: sel.period,
      start: start,
      end: end,
      isCurrent: !now.isBefore(start) && now.isBefore(end),
      filter: filter,
      items: items,
      periodCount: inPeriod.length,
      totalIncome: income,
      totalExpense: expense,
      categories: {for (final c in cats) c.syncId: c},
      jars: jarOptions,
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _selection.close();
    _filter.close();
    return super.close();
  }
}

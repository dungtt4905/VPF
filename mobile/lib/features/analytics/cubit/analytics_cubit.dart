import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import '../../../core/repositories/transaction_repository.dart';
import '../../../core/repositories/category_repository.dart';
import '../../../models/transaction_model.dart';
import '../../../models/category_model.dart';
import '../../../models/enums.dart';

enum AnalyticsPeriod { week, month }

extension AnalyticsPeriodX on AnalyticsPeriod {
  /// Đầu kỳ chứa [d]: tuần bắt đầu từ thứ Hai, tháng từ ngày 1.
  DateTime startOf(DateTime d) => switch (this) {
        AnalyticsPeriod.week => DateTime(d.year, d.month, d.day - (d.weekday - 1)),
        AnalyticsPeriod.month => DateTime(d.year, d.month, 1),
      };

  /// Đầu kỳ liền sau [start] (cũng là cận trên loại trừ của kỳ hiện tại).
  DateTime nextStart(DateTime start) => switch (this) {
        AnalyticsPeriod.week => DateTime(start.year, start.month, start.day + 7),
        AnalyticsPeriod.month => DateTime(start.year, start.month + 1, 1),
      };

  DateTime previousStart(DateTime start) => switch (this) {
        AnalyticsPeriod.week => DateTime(start.year, start.month, start.day - 7),
        AnalyticsPeriod.month => DateTime(start.year, start.month - 1, 1),
      };

  String get nounLower => this == AnalyticsPeriod.week ? 'tuần' : 'tháng';
}

class AnalyticsData {
  final AnalyticsPeriod period;
  final DateTime start; // đầu kỳ đang xem
  final DateTime end; // đầu kỳ kế tiếp (loại trừ)
  final bool isCurrent; // đang xem kỳ hiện tại
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final List<CategoryBreakdown> categoryBreakdowns;
  final List<TransactionModel> topExpenses;
  final double previousExpense; // chi tiêu kỳ trước, để so sánh xu hướng
  final Map<String, CategoryModel> categories; // syncId -> category

  AnalyticsData({
    required this.period,
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.categoryBreakdowns,
    required this.topExpenses,
    required this.previousExpense,
    required this.categories,
  });
}

class CategoryBreakdown {
  final CategoryModel category;
  final double amount;
  final double percentage;
  CategoryBreakdown({required this.category, required this.amount, required this.percentage});
}

abstract class AnalyticsState {}

class AnalyticsLoading extends AnalyticsState {}

class AnalyticsLoaded extends AnalyticsState {
  final AnalyticsData data;
  AnalyticsLoaded(this.data);
}

class AnalyticsCubit extends Cubit<AnalyticsState> {
  final TransactionRepository _txRepo;
  final CategoryRepository _catRepo;
  StreamSubscription? _subscription;

  // Kỳ đang xem: loại kỳ + một ngày bất kỳ nằm trong kỳ đó (giữ nguyên khi đổi tuần <-> tháng).
  final _selection = BehaviorSubject<({AnalyticsPeriod period, DateTime anchor})>.seeded(
    (period: AnalyticsPeriod.month, anchor: DateTime.now()),
  );

  AnalyticsCubit(this._txRepo, this._catRepo) : super(AnalyticsLoading()) {
    _init();
  }

  void _init() {
    _subscription = CombineLatestStream.combine3(
      _txRepo.watchAllTransactions(),
      _catRepo.watchAllCategories(),
      _selection,
      (List<TransactionModel> txs, List<CategoryModel> cats, sel) =>
          _calculateAnalytics(txs, cats, sel.period, sel.anchor),
    ).listen((data) {
      emit(AnalyticsLoaded(data));
    });
  }

  // ---- Chọn kỳ ----

  void setPeriod(AnalyticsPeriod period) {
    final sel = _selection.value;
    if (sel.period == period) return;
    _selection.add((period: period, anchor: sel.anchor));
  }

  /// Nhảy tới kỳ chứa [date] (không cho chọn tương lai).
  void jumpTo(DateTime date) {
    final now = DateTime.now();
    _selection.add((period: _selection.value.period, anchor: date.isAfter(now) ? now : date));
  }

  void goToCurrent() => jumpTo(DateTime.now());

  void previous() {
    final sel = _selection.value;
    _selection.add((period: sel.period, anchor: sel.period.previousStart(sel.period.startOf(sel.anchor))));
  }

  /// Sang kỳ sau; không vượt quá kỳ hiện tại.
  void next() {
    final sel = _selection.value;
    final nextStart = sel.period.nextStart(sel.period.startOf(sel.anchor));
    if (nextStart.isAfter(DateTime.now())) return;
    _selection.add((period: sel.period, anchor: nextStart));
  }

  // ---- Tính toán ----

  /// Khoảng nửa mở [start, end): giao dịch lúc đúng 00:00 đầu kỳ vẫn được tính.
  static bool _inRange(DateTime t, DateTime start, DateTime end) => !t.isBefore(start) && t.isBefore(end);

  /// Chuẩn hóa categoryId của giao dịch về UUID (hỗ trợ dữ liệu cũ lưu theo tên).
  static String _resolveCategoryId(String id, Map<String, CategoryModel> catMap) {
    if (catMap.containsKey(id)) return id;
    return CategoryRepository.legacyNameToId[id] ?? id;
  }

  AnalyticsData _calculateAnalytics(
    List<TransactionModel> txs,
    List<CategoryModel> cats,
    AnalyticsPeriod period,
    DateTime anchor,
  ) {
    final start = period.startOf(anchor);
    final end = period.nextStart(start);
    final previousStart = period.previousStart(start);
    final isCurrent = _inRange(DateTime.now(), start, end);

    final currentTxs = txs.where((t) => _inRange(t.transactionAt, start, end)).toList();
    final previousTxs = txs.where((t) => _inRange(t.transactionAt, previousStart, start)).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    double previousExpense = 0;

    final catMap = {for (var c in cats) c.syncId: c};
    final expenseByCategory = <String, double>{};

    for (var t in previousTxs) {
      if (t.type == TransactionType.expense) previousExpense += t.amount;
    }

    for (var t in currentTxs) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
        continue;
      }
      totalExpense += t.amount;
      final catId = _resolveCategoryId(t.categoryId, catMap);
      expenseByCategory[catId] = (expenseByCategory[catId] ?? 0) + t.amount;
    }

    final breakdowns = <CategoryBreakdown>[];
    expenseByCategory.forEach((catId, amount) {
      if (totalExpense <= 0) return;
      // Danh mục đã bị xóa/không tìm thấy: gộp vào mục "Khác" thay vì làm rớt dữ liệu.
      final cat = catMap[catId] ??
          (CategoryModel()
            ..syncId = catId
            ..name = 'Khác'
            ..icon = 'category'
            ..color = '#9E9E9E'
            ..type = TransactionType.expense);
      breakdowns.add(CategoryBreakdown(
        category: cat,
        amount: amount,
        percentage: (amount / totalExpense) * 100,
      ));
    });
    breakdowns.sort((a, b) => b.amount.compareTo(a.amount));

    final expenseTxs = currentTxs.where((t) => t.type == TransactionType.expense).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return AnalyticsData(
      period: period,
      start: start,
      end: end,
      isCurrent: isCurrent,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      categoryBreakdowns: breakdowns,
      topExpenses: expenseTxs.take(3).toList(),
      previousExpense: previousExpense,
      categories: catMap,
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _selection.close();
    return super.close();
  }
}

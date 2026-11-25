import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/core/di/injection.dart';
import 'package:mobile/core/repositories/budget_plan_repository.dart';
import 'package:mobile/core/repositories/category_repository.dart';
import 'package:mobile/core/repositories/transaction_repository.dart';
import 'package:mobile/features/transaction/list/transaction_filter.dart';
import 'package:mobile/features/transaction/list/transaction_list_cubit.dart';
import 'package:mobile/features/transaction/list/transaction_list_screen.dart';
import 'package:mobile/models/budget_category_model.dart';
import 'package:mobile/models/budget_jar_model.dart';
import 'package:mobile/models/budget_plan_model.dart';
import 'package:mobile/models/category_model.dart';
import 'package:mobile/models/enums.dart';
import 'package:mobile/models/transaction_model.dart';

class _FakeTransactions implements TransactionRepository {
  _FakeTransactions(this.items);
  List<TransactionModel> items;
  final deleted = <int>[];
  final _changes = StreamController<List<TransactionModel>>.broadcast();

  @override
  Stream<List<TransactionModel>> watchAllTransactions() async* {
    yield items;
    yield* _changes.stream;
  }

  @override
  Future<void> deleteTransactions(Iterable<int> ids) async {
    deleted.addAll(ids);
    items = items.where((t) => !deleted.contains(t.id)).toList();
    _changes.add(items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeCategories implements CategoryRepository {
  @override
  Stream<List<CategoryModel>> watchAllCategories() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakePlans implements BudgetPlanRepository {
  @override
  Stream<List<BudgetPlanModel>> watchPlans() => Stream.value([]);
  @override
  Stream<List<BudgetJarModel>> watchJars() => Stream.value([]);
  @override
  Stream<List<BudgetCategoryModel>> watchLinks() => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

TransactionModel _tx(int id, String title, TransactionType type) => TransactionModel()
  ..id = id
  ..syncId = 'tx-$id'
  ..categoryId = 'food'
  ..title = title
  ..amount = 10000.0 * id
  ..type = type
  ..paymentMethod = 'CASH'
  ..transactionAt = DateTime.now()
  ..createdAt = DateTime.now()
  ..updatedAt = DateTime.now();

void main() {
  late _FakeTransactions repo;

  setUpAll(() => initializeDateFormatting('vi'));

  setUp(() async {
    await getIt.reset();
    repo = _FakeTransactions([
      _tx(1, 'Ăn sáng', TransactionType.expense),
      _tx(2, 'Xăng xe', TransactionType.expense),
      _tx(3, 'Lương', TransactionType.income),
    ]);
    getIt.registerSingleton<TransactionRepository>(repo);
    getIt.registerSingleton<CategoryRepository>(_FakeCategories());
    getIt.registerSingleton<BudgetPlanRepository>(_FakePlans());
  });

  group('cubit', () {
    late TransactionListCubit cubit;
    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));
    TransactionListLoaded loaded() => cubit.state as TransactionListLoaded;

    setUp(() async {
      cubit = TransactionListCubit(repo, _FakeCategories(), _FakePlans());
      await settle();
    });
    tearDown(() => cubit.close());

    test('chọn tất cả chỉ gồm giao dịch khớp bộ lọc, và chỉ xóa những giao dịch đó', () async {
      cubit.setFilter(const TransactionFilter(type: TransactionType.expense));
      await settle();
      cubit.startSelecting();
      cubit.toggleSelectAll();
      expect(loaded().selected, {1, 2});
      expect(loaded().isAllSelected, isTrue);

      await cubit.deleteSelected();
      await settle();
      expect(repo.deleted..sort(), [1, 2]);
      expect(loaded().isSelecting, isFalse);
    });

    test('giao dịch bị lọc ẩn đi sẽ bỏ tick và không tick lại khi bỏ lọc', () async {
      cubit.startSelecting();
      cubit.toggleSelected(1);
      cubit.toggleSelected(3);
      cubit.setFilter(const TransactionFilter(type: TransactionType.expense));
      await settle();
      expect(loaded().selected, {1});
      cubit.clearFilter();
      await settle();
      expect(loaded().selected, {1});
    });

    test('đổi sang kỳ khác thì bỏ hết tick nhưng vẫn ở chế độ chọn', () async {
      cubit.startSelecting();
      cubit.toggleSelectAll();
      cubit.previous();
      await settle();
      expect(loaded().selected, isEmpty);
      expect(loaded().isAllSelected, isFalse);
    });

    test('không chọn gì thì không xóa', () async {
      cubit.startSelecting();
      await cubit.deleteSelected();
      expect(repo.deleted, isEmpty);
    });
  });

  testWidgets('màn danh sách: tick, xác nhận xóa, Back thoát chế độ chọn', (tester) async {
    // Màn hình hẹp 360dp để bắt lỗi tràn ở thanh tiêu đề.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: TransactionListScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.byTooltip('Xóa'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(4)); // 3 giao dịch + "Chọn tất cả"
    expect(find.text('Xóa (0)'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Ăn sáng'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Xóa (1)'), findsOneWidget);

    await tester.tap(find.text('Chọn tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa (3)'), findsOneWidget);
    await tester.tap(find.text('Chọn tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa (0)'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa 1 giao dịch?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Xóa'));
    await tester.pumpAndSettle();

    expect(repo.deleted, hasLength(1));
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Đã xóa 1 giao dịch'), findsOneWidget);
  });
}

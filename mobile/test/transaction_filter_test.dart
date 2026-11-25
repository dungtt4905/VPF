import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/repositories/category_repository.dart';
import 'package:mobile/features/transaction/list/transaction_filter.dart';
import 'package:mobile/models/budget_category_model.dart';
import 'package:mobile/models/budget_jar_model.dart';
import 'package:mobile/models/budget_plan_model.dart';
import 'package:mobile/models/enums.dart';
import 'package:mobile/models/transaction_model.dart';

TransactionModel _tx(String id, String cat, double amount, DateTime at, {TransactionType type = TransactionType.expense}) =>
    TransactionModel()
      ..syncId = id
      ..categoryId = cat
      ..title = id
      ..amount = amount
      ..type = type
      ..paymentMethod = 'cash'
      ..transactionAt = at
      ..createdAt = at
      ..updatedAt = at;

BudgetPlanModel _plan(String id, DateTime start) => BudgetPlanModel()
  ..syncId = id
  ..periodStart = start
  ..periodEnd = DateTime(start.year, start.month + 1, 1)
  ..createdAt = start
  ..updatedAt = start;

BudgetJarModel _jar(String id, String planId, String key) => BudgetJarModel()
  ..syncId = id
  ..planId = planId
  ..jarKey = key
  ..name = key
  ..amount = 1000
  ..createdAt = DateTime(2026, 1, 1)
  ..updatedAt = DateTime(2026, 1, 1);

BudgetCategoryModel _link(String jarId, String planId, String cat) => BudgetCategoryModel()
  ..syncId = '$jarId-$cat'
  ..jarId = jarId
  ..planId = planId
  ..categoryId = cat
  ..categoryName = cat
  ..createdAt = DateTime(2026, 1, 1)
  ..updatedAt = DateTime(2026, 1, 1);

void main() {
  final nov = DateTime(2026, 11, 10);
  final dec = DateTime(2026, 12, 5);
  final txs = [
    _tx('food-nov', 'food', 50000, nov),
    _tx('food-dec', 'food', 70000, dec),
    _tx('taxi-nov', 'taxi', 200000, nov),
    _tx('salary', 'salary', 9000000, nov, type: TransactionType.income),
  ];

  List<String> ids(List<TransactionModel> l) => l.map((t) => t.syncId).toList()..sort();

  test('bộ lọc rỗng giữ nguyên tất cả', () {
    expect(ids(TransactionFilter.empty.apply(txs)), ids(txs));
    expect(TransactionFilter.empty.activeCount, 0);
  });

  test('lọc theo loại chi/thu', () {
    expect(ids(const TransactionFilter(type: TransactionType.income).apply(txs)), ['salary']);
    expect(ids(const TransactionFilter(type: TransactionType.expense).apply(txs)), ['food-dec', 'food-nov', 'taxi-nov']);
  });

  test('lọc theo danh mục (OR trong nhóm) và gồm danh mục con', () {
    expect(ids(const TransactionFilter(categoryIds: {'food', 'taxi'}).apply(txs)), ['food-dec', 'food-nov', 'taxi-nov']);
    final child = [_tx('c', 'pho', 1, nov)];
    expect(ids(const TransactionFilter(categoryIds: {'food'}).apply(child, childrenOf: {'food': ['pho']})), ['c']);
    expect(const TransactionFilter(categoryIds: {'food'}).apply(child), isEmpty);
  });

  test('lọc theo số tiền, gồm cả biên', () {
    expect(ids(const TransactionFilter(minAmount: 70000, maxAmount: 200000).apply(txs)), ['food-dec', 'taxi-nov']);
    expect(ids(const TransactionFilter(minAmount: 1000000).apply(txs)), ['salary']);
    expect(ids(const TransactionFilter(maxAmount: 50000).apply(txs)), ['food-nov']);
  });

  test('kết hợp nhiều nhóm bằng AND', () {
    final f = const TransactionFilter(type: TransactionType.expense, categoryIds: {'food'}, minAmount: 60000);
    expect(ids(f.apply(txs)), ['food-dec']);
    expect(f.activeCount, 3);
  });

  group('ngân sách', () {
    // Tháng 11: hũ "eat" gồm food. Tháng 12: food chuyển sang hũ "other", taxi vào "eat".
    final resolver = BudgetResolver(
      plans: [_plan('p11', DateTime(2026, 11, 1)), _plan('p12', DateTime(2026, 12, 1))],
      jars: [_jar('j11-eat', 'p11', 'eat'), _jar('j12-eat', 'p12', 'eat'), _jar('j12-other', 'p12', 'other')],
      links: [_link('j11-eat', 'p11', 'food'), _link('j12-other', 'p12', 'food'), _link('j12-eat', 'p12', 'taxi')],
    );

    test('giao dịch thuộc hũ theo đúng tháng của nó', () {
      expect(resolver.jarKeyOf(txs[0]), 'eat'); // food tháng 11
      expect(resolver.jarKeyOf(txs[1]), 'other'); // food tháng 12
      expect(resolver.jarKeyOf(txs[2]), isNull); // taxi tháng 11: chưa có hũ
    });

    test('lọc theo hũ và "chưa có ngân sách"; thu nhập không khớp', () {
      expect(ids(const TransactionFilter(jarKeys: {'eat'}).apply(txs, jarKeyOf: resolver.jarKeyOf)), ['food-nov']);
      expect(ids(const TransactionFilter(noBudget: true).apply(txs, jarKeyOf: resolver.jarKeyOf)), ['taxi-nov']);
      expect(
        ids(const TransactionFilter(jarKeys: {'other'}, noBudget: true).apply(txs, jarKeyOf: resolver.jarKeyOf)),
        ['food-dec', 'taxi-nov'],
      );
    });

    test('danh mục lưu theo tên cũ vẫn khớp hũ', () {
      final legacy = _tx('old', 'Food', 1, nov);
      final r = BudgetResolver(
        plans: [_plan('p11', DateTime(2026, 11, 1))],
        jars: [_jar('j', 'p11', 'eat')],
        links: [_link('j', 'p11', CategoryRepository.legacyNameToId['Food']!)],
      );

      expect(r.jarKeyOf(legacy), 'eat');
    });
  });
}

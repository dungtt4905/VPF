import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/budget/budget_planner.dart';
import 'package:mobile/core/budget/budget_progress.dart';
import 'package:mobile/core/budget/budget_spec.dart';
import 'package:mobile/models/budget_category_model.dart';
import 'package:mobile/models/budget_jar_model.dart';
import 'package:mobile/models/budget_plan_model.dart';
import 'package:mobile/models/category_model.dart';
import 'package:mobile/models/enums.dart';
import 'package:mobile/models/transaction_model.dart';

BudgetSpec budget({
  String? categoryId,
  double amount = 3000000,
  BudgetPeriod period = BudgetPeriod.monthly,
  int threshold = 80,
  bool rollover = false,
  DateTime? createdAt,
}) =>
    BudgetSpec(
      key: 'b-${categoryId ?? 'total'}',
      amount: amount,
      rollover: rollover,
      alertThreshold: threshold,
      period: period,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      categoryIds: categoryId == null ? null : {categoryId},
    );

TransactionModel tx(double amount, DateTime at, {String category = 'food', int id = 0, TransactionType type = TransactionType.expense}) =>
    TransactionModel()
      ..id = id
      ..syncId = 't$id'
      ..categoryId = category
      ..title = 't'
      ..amount = amount
      ..type = type
      ..paymentMethod = 'Cash'
      ..transactionAt = at;

CategoryModel cat(String id, {String? parent}) => CategoryModel()
  ..syncId = id
  ..name = id
  ..parentId = parent;

void main() {
  // 11/2026 có 30 ngày.
  final day10 = DateTime(2026, 11, 10, 12);

  group('periodWindow', () {
    test('tháng: [mùng 1, mùng 1 tháng sau)', () {
      final (s, e) = BudgetCalc.periodWindow(BudgetPeriod.monthly, day10);
      expect(s, DateTime(2026, 11, 1));
      expect(e, DateTime(2026, 12, 1));
    });

    test('biên nửa mở: 0h ngày kế tiếp không thuộc kỳ', () {
      final (s, e) = BudgetCalc.periodWindow(BudgetPeriod.monthly, day10);
      expect(BudgetCalc.inWindow(DateTime(2026, 11, 30, 23, 59), s, e), isTrue);
      expect(BudgetCalc.inWindow(DateTime(2026, 12, 1), s, e), isFalse);
      expect(BudgetCalc.inWindow(DateTime(2026, 10, 31, 23, 59), s, e), isFalse);
    });
  });

  group('usedAmount', () {
    final catMap = {
      'needs': cat('needs'),
      'food': cat('food', parent: 'needs'),
      'movie': cat('movie', parent: 'wants'),
    };

    test('giao dịch danh mục con tính vào ngân sách danh mục cha', () {
      final used = BudgetCalc.usedAmount(
        budget(categoryId: 'needs'),
        [tx(100, DateTime(2026, 11, 3), category: 'food'), tx(50, DateTime(2026, 11, 4), category: 'movie')],
        catMap,
        day10,
      );
      expect(used, 100);
    });

    test('bỏ thu nhập, giao dịch kỳ khác và giao dịch bị loại trừ', () {
      final used = BudgetCalc.usedAmount(
        budget(),
        [
          tx(100, DateTime(2026, 11, 3), id: 1),
          tx(900, DateTime(2026, 11, 3), id: 2, type: TransactionType.income),
          tx(700, DateTime(2026, 10, 30), id: 3),
          tx(40, DateTime(2026, 11, 5), id: 4),
        ],
        catMap,
        day10,
        excludeTxId: 4,
      );
      expect(used, 100);
    });
  });

  group('BudgetProgress', () {
    BudgetProgress at(DateTime now, double used, {double limit = 3000000, int threshold = 80}) => BudgetProgress(
          used: used,
          limit: limit,
          threshold: threshold,
          start: DateTime(2026, 11, 1),
          end: DateTime(2026, 12, 1),
          now: now,
        );

    test('ngày còn lại và hạn mức mỗi ngày (ngày 10/30 -> còn 21 ngày)', () {
      final p = at(day10, 900000);
      expect(p.totalDays, 30);
      expect(p.dayIndex, 9);
      expect(p.daysLeft, 21);
      expect(p.dailyAllowance, closeTo(2100000 / 21, 0.001));
    });

    test('tháng 28 ngày (02/2027)', () {
      final p = BudgetProgress(
        used: 0,
        limit: 2800000,
        threshold: 80,
        start: DateTime(2027, 2, 1),
        end: DateTime(2027, 3, 1),
        now: DateTime(2027, 2, 1, 9),
      );
      expect(p.totalDays, 28);
      expect(p.daysLeft, 28);
    });

    test('đi đúng tốc độ -> ok', () {
      expect(at(day10, 1000000).level, BudgetLevel.ok); // 100k/ngày -> dự kiến 3tr, không vượt
    });

    test('đi nhanh hơn kế hoạch -> pace, kèm ngày dự kiến hết', () {
      final p = at(day10, 1500000); // 150k/ngày -> dự kiến 4.5tr
      expect(p.level, BudgetLevel.pace);
      expect(p.projectedExceedDate, DateTime(2026, 11, 20)); // 3tr / 150k = ngày thứ 20
    });

    test('chạm ngưỡng cảnh báo -> warning; >=100% -> exceeded', () {
      expect(at(day10, 2400000).level, BudgetLevel.warning);
      expect(at(day10, 3000000).level, BudgetLevel.exceeded);
      expect(at(day10, 3500000).dailyAllowance, 0);
    });

    test('không dự báo trong 2 ngày đầu kỳ dù chi lớn', () {
      final p = at(DateTime(2026, 11, 2, 9), 1000000); // 2 ngày: chưa đủ dữ liệu
      expect(p.canForecast, isFalse);
      expect(p.projectedTotal, isNull);
      expect(p.level, BudgetLevel.ok);
    });

    test('limit = 0 không gây chia cho 0: chưa chi thì ok, có chi thì vượt', () {
      expect(at(day10, 0, limit: 0).level, BudgetLevel.ok);
      final p = at(day10, 100, limit: 0);
      expect(p.pct, 100);
      expect(p.level, BudgetLevel.exceeded);
    });
  });

  group('lịch sử, streak và rollover', () {
    // Ngân sách tạo từ tháng 8/2026; hạn mức 1 triệu/tháng.
    BudgetSpec monthly({bool rollover = false}) =>
        budget(amount: 1000000, rollover: rollover, createdAt: DateTime(2026, 8, 15));

    final txs = [
      tx(600000, DateTime(2026, 8, 20), id: 1), // T8: dư 400K
      tx(1200000, DateTime(2026, 9, 5), id: 2), // T9: vượt 200K
      tx(900000, DateTime(2026, 10, 5), id: 3), // T10: dư 100K
      tx(300000, DateTime(2026, 11, 3), id: 4), // T11 (kỳ hiện tại)
    ];

    test('chỉ lấy các kỳ đã kết thúc, từ kỳ tạo ngân sách, cũ -> mới', () {
      final past = BudgetCalc.pastResults(monthly(), txs, {}, day10);
      expect(past.map((r) => r.start.month), [8, 9, 10]);
      expect(past.map((r) => r.used), [600000, 1200000, 900000]);
      expect(past.every((r) => r.limit == 1000000), isTrue);
    });

    test('streak: đếm các kỳ liên tiếp giữ được tính từ kỳ gần nhất', () {
      final past = BudgetCalc.pastResults(monthly(), txs, {}, day10);
      expect(BudgetCalc.streak(past), 1); // T10 đạt, T9 vượt -> dừng
    });

    test('không có kỳ nào kết thúc -> lịch sử rỗng, streak 0', () {
      final fresh = budget(amount: 1000000, createdAt: DateTime(2026, 11, 2));
      final past = BudgetCalc.pastResults(fresh, txs, {}, day10);
      expect(past, isEmpty);
      expect(BudgetCalc.streak(past), 0);
    });

    test('không bật rollover: hạn mức kỳ này giữ nguyên', () {
      final p = BudgetCalc.progress(monthly(), txs, {}, day10);
      expect(p.limit, 1000000);
      expect(p.carry, 0);
    });

    test('bật rollover: dư/vượt cộng dồn qua các kỳ (T8 +400K, T9 -200K => T10 limit 1.2tr? kiểm tra từng bước)', () {
      final past = BudgetCalc.pastResults(monthly(rollover: true), txs, {}, day10);
      // T8: 1.000K, dùng 600K -> carry +400K
      expect(past[0].limit, 1000000);
      // T9: 1.400K, dùng 1.200K -> carry +200K
      expect(past[1].limit, 1400000);
      // T10: 1.200K, dùng 900K -> carry +300K
      expect(past[2].limit, 1200000);

      final p = BudgetCalc.progress(monthly(rollover: true), txs, {}, day10);
      expect(p.carry, 300000);
      expect(p.limit, 1300000);
      expect(p.remaining, 1000000); // 1.3tr - 300K đã chi
    });

    test('rollover: số vượt không làm hạn mức kỳ sau âm', () {
      final over = [tx(5000000, DateTime(2026, 10, 5), id: 9)];
      final b = monthly(rollover: true);
      final p = BudgetCalc.progress(b, over, {}, day10);
      expect(p.carry, -1000000); // chặn ở -hạn mức gốc
      expect(p.limit, 0);
    });

  });

  group('BudgetPlanner', () {
    test('% <-> số tiền, làm tròn đến nghìn đồng', () {
      expect(BudgetPlanner.amountFromPercent(15000000, 30), 4500000);
      expect(BudgetPlanner.amountFromPercent(10333333, 10), 1033000);
      expect(BudgetPlanner.amountFromPercent(0, 30), 0);
      expect(BudgetPlanner.percentFromAmount(10000000, 2500000), 25);
      expect(BudgetPlanner.percentFromAmount(0, 100), 0);
    });
  });

  group('BudgetSpec.fromJars', () {
    BudgetPlanModel plan(String id, DateTime start) => BudgetPlanModel()
      ..syncId = id
      ..periodStart = start
      ..periodEnd = DateTime(start.year, start.month + 1, 1)
      ..createdAt = DateTime(2026, 1, 1)
      ..updatedAt = DateTime(2026, 1, 1);
    BudgetJarModel jar(String id, String planId, String key, double amount,
            {bool total = false, DateTime? created, DateTime? paidAt}) =>
        BudgetJarModel()
          ..syncId = id
          ..planId = planId
          ..jarKey = key
          ..name = key
          ..amount = amount
          ..isTotal = total
          ..paidAt = paidAt
          ..createdAt = created ?? DateTime(2026, 8, 1)
          ..updatedAt = DateTime(2026, 1, 1);
    BudgetCategoryModel link(String jarId, String planId, String categoryId) => BudgetCategoryModel()
      ..syncId = '$jarId-$categoryId'
      ..jarId = jarId
      ..planId = planId
      ..categoryId = categoryId
      ..categoryName = categoryId
      ..createdAt = DateTime(2026, 1, 1)
      ..updatedAt = DateTime(2026, 1, 1);

    final nov = plan('p-nov', DateTime(2026, 11, 1));
    final oct = plan('p-oct', DateTime(2026, 10, 1));

    test('không có kế hoạch cho tháng hiện tại -> không có spec', () {
      expect(BudgetSpec.fromJars(plans: [oct], jars: [jar('j-oct', 'p-oct', 'a', 1)], links: [], now: day10), isEmpty);
    });

    test('hũ nhiều danh mục: chi của mọi danh mục trong hũ đều được tính', () {
      final spec = BudgetSpec.fromJars(
        plans: [nov],
        jars: [jar('j-nov', 'p-nov', 'a', 1000000)],
        links: [link('j-nov', 'p-nov', 'food'), link('j-nov', 'p-nov', 'bus')],
        now: day10,
      ).single;
      expect(spec.categoryIds, {'food', 'bus'});
      final used = BudgetCalc.usedAmount(
        spec,
        [
          tx(100, DateTime(2026, 11, 3), category: 'food', id: 1),
          tx(50, DateTime(2026, 11, 4), category: 'bus', id: 2),
          tx(999, DateTime(2026, 11, 5), category: 'movie', id: 3),
        ],
        {},
        day10,
      );
      expect(used, 150);
    });

    test('kỳ cũ dùng cấu hình của kế hoạch kỳ đó: đổi hạn mức/danh mục tháng này không viết lại tháng trước', () {
      final spec = BudgetSpec.fromJars(
        plans: [oct, nov],
        jars: [jar('j-oct', 'p-oct', 'a', 600000), jar('j-nov', 'p-nov', 'a', 2000000)],
        links: [
          link('j-oct', 'p-oct', 'food'),
          link('j-nov', 'p-nov', 'food'),
          link('j-nov', 'p-nov', 'bus'), // tháng 11 mới thêm bus
        ],
        now: day10,
      ).single;
      expect(spec.amountFor(DateTime(2026, 10, 1)), 600000);
      expect(spec.categoriesFor(DateTime(2026, 10, 1)), {'food'});

      final txs = [
        tx(400000, DateTime(2026, 10, 5), category: 'food', id: 1),
        tx(300000, DateTime(2026, 10, 6), category: 'bus', id: 2), // tháng 10 bus chưa thuộc hũ
      ];
      final past = BudgetCalc.pastResults(spec, txs, {}, day10);
      final octResult = past.firstWhere((r) => r.start == DateTime(2026, 10, 1));
      expect(octResult.limit, 600000);
      expect(octResult.used, 400000);
      // Tháng 9 không có kế hoạch -> dùng cấu hình hiện tại.
      expect(past.firstWhere((r) => r.start == DateTime(2026, 9, 1)).limit, 2000000);
    });

    test('ngày bắt đầu theo dõi là ngày tạo sớm nhất của hũ cùng jarKey (hũ sao chép sang tháng mới không làm mất lịch sử)', () {
      final spec = BudgetSpec.fromJars(
        plans: [oct, nov],
        jars: [
          jar('j-oct', 'p-oct', 'a', 600000, created: DateTime(2026, 8, 15)),
          jar('j-nov', 'p-nov', 'a', 600000, created: DateTime(2026, 11, 1)),
        ],
        links: [],
        now: day10,
      ).single;
      expect(spec.createdAt, DateTime(2026, 8, 15));
      final past = BudgetCalc.pastResults(spec, [], {}, day10);
      expect(past.map((r) => r.start.month), [8, 9, 10]);
    });

    test('rollover dùng hạn mức của từng kỳ', () {
      final spec = BudgetSpec.fromJars(
        plans: [oct, nov],
        jars: [
          jar('j-oct', 'p-oct', 'a', 1000000, created: DateTime(2026, 9, 1))..rollover = true,
          jar('j-nov', 'p-nov', 'a', 2000000, created: DateTime(2026, 9, 1))..rollover = true,
        ],
        links: [link('j-oct', 'p-oct', 'food'), link('j-nov', 'p-nov', 'food')],
        now: day10,
      ).single;
      final p = BudgetCalc.progress(spec, [tx(400000, DateTime(2026, 10, 5), category: 'food')], {}, day10);
      // T9 dùng hạn mức hiện tại 2.000K (không chi) -> dư 2.000K sang T10; T10 hạn mức 1.000K + 2.000K, chi 400K
      // -> dư 2.600K sang T11.
      expect(p.carry, 2600000);
      expect(p.limit, 4600000);
    });

    test('hũ tổng tính mọi khoản chi', () {
      final spec = BudgetSpec.fromJars(
        plans: [nov],
        jars: [jar('j-t', 'p-nov', 't', 9000000, total: true)],
        links: [],
        now: day10,
      ).single;
      expect(spec.isTotal, isTrue);
      expect(BudgetCalc.usedAmount(spec, [tx(70, DateTime(2026, 11, 3), category: 'food')], {}, day10), 70);
    });

    test('hũ cam kết (không danh mục): chưa trả -> chi 0; đã trả -> chi đủ hạn mức; không bao giờ báo vượt', () {
      List<BudgetSpec> build({DateTime? paidAt}) => BudgetSpec.fromJars(
            plans: [nov],
            jars: [jar('j-rent', 'p-nov', 'rent', 5000000, paidAt: paidAt)],
            links: [],
            now: day10,
          );
      final unpaid = build().single;
      expect(unpaid.commitment, isTrue);
      final txs = [tx(70, DateTime(2026, 11, 3), category: 'food')];
      expect(BudgetCalc.usedAmount(unpaid, txs, {}, day10), 0);
      expect(BudgetCalc.progress(unpaid, txs, {}, day10).level, BudgetLevel.ok);

      final paid = build(paidAt: DateTime(2026, 11, 5)).single;
      final p = BudgetCalc.progress(paid, txs, {}, day10);
      expect(p.used, 5000000);
      expect(p.pct, 100);
      expect(p.level, BudgetLevel.ok); // đã trả đủ không phải là vượt ngân sách
    });

    test('hũ cam kết: lịch sử theo trạng thái đã trả của từng kỳ', () {
      final spec = BudgetSpec.fromJars(
        plans: [oct, nov],
        jars: [
          jar('j-oct', 'p-oct', 'rent', 5000000, created: DateTime(2026, 10, 1), paidAt: DateTime(2026, 10, 3)),
          jar('j-nov', 'p-nov', 'rent', 5000000, created: DateTime(2026, 10, 1)),
        ],
        links: [],
        now: day10,
      ).single;
      final past = BudgetCalc.pastResults(spec, [], {}, day10);
      expect(past.single.start, DateTime(2026, 10, 1));
      expect(past.single.used, 5000000);
    });
  });
}

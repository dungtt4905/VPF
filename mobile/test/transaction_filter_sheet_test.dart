import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/transaction/list/transaction_filter.dart';
import 'package:mobile/features/transaction/list/transaction_filter_sheet.dart';
import 'package:mobile/models/category_model.dart';
import 'package:mobile/models/enums.dart';

CategoryModel _cat(String id, String name, {String? parent, TransactionType type = TransactionType.expense}) =>
    CategoryModel()
      ..syncId = id
      ..name = name
      ..parentId = parent
      ..type = type;

void main() {
  testWidgets('bộ lọc xếp danh mục con ngay dưới danh mục cha, thụt vào', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final categories = [
      _cat('food', 'Ăn uống', parent: 'needs'),
      _cat('fun', 'Giải trí', parent: 'wants'),
      _cat('needs', 'Thiết yếu'),
      _cat('wants', 'Mong muốn'),
      _cat('orphan', 'Mồ côi', parent: 'deleted'),
      _cat('income', 'Thu nhập', type: TransactionType.income),
      _cat('salary', 'Lương', parent: 'income', type: TransactionType.income),
    ];
    TransactionFilter? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showTransactionFilterSheet(context,
                initial: TransactionFilter.empty, categories: categories, jars: const []),
            child: const Text('mở'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    Offset at(String name) => tester.getTopLeft(find.widgetWithText(FilterChip, name));
    void expectUnder(String child, String parent, {String? nextParent}) {
      expect(at(child).dy, greaterThan(at(parent).dy), reason: '$child dưới $parent');
      expect(at(child).dx, greaterThan(at(parent).dx), reason: '$child thụt vào');
      if (nextParent != null) expect(at(child).dy, lessThan(at(nextParent).dy));
    }

    expect(find.text('Khoản chi'), findsOneWidget);
    expect(find.text('Khoản thu'), findsOneWidget);
    expectUnder('Giải trí', 'Mong muốn', nextParent: 'Thiết yếu');
    expectUnder('Ăn uống', 'Thiết yếu');
    expectUnder('Lương', 'Thu nhập');
    expect(find.widgetWithText(FilterChip, 'Mồ côi'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Thiết yếu'));
    await tester.tap(find.widgetWithText(FilterChip, 'Giải trí'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(result!.categoryIds, {'needs', 'fun'});
  });
}

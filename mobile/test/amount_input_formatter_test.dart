import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/currency/amount_input_formatter.dart';
import 'package:mobile/features/budget/budget_save_guard.dart';

TextEditingValue _type(String text, [int? cursor]) {
  const f = AmountInputFormatter();
  return f.formatEditUpdate(
    const TextEditingValue(),
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor ?? text.length)),
  );
}

void main() {
  test('chèn dấu chấm phân cách hàng nghìn', () {
    expect(_type('1').text, '1');
    expect(_type('1234').text, '1.234');
    expect(_type('1234567').text, '1.234.567');
    expect(_type('1000000000').text, '1.000.000.000');
  });

  test('bỏ ký tự không phải số và số 0 đứng đầu', () {
    expect(_type('12a3,4').text, '1.234');
    expect(_type('007').text, '7');
    expect(_type('0').text, '0');
    expect(_type('').text, '');
    expect(_type('abc').text, '');
  });

  test('con trỏ giữ đúng vị trí khi gõ ở giữa', () {
    // "1.234" -> gõ thêm số 9 sau chữ số đầu: "19.234" thô là "19.234" (con trỏ sau '9', offset 2)
    final v = _type('19.234', 2);
    expect(v.text, '19.234');
    expect(v.selection.baseOffset, 2);
    // gõ ở cuối luôn đặt con trỏ ở cuối
    expect(_type('12345').selection.baseOffset, '12.345'.length);
    // thêm chữ số làm xuất hiện dấu chấm mới: "1234" con trỏ giữa (sau '12') -> "1.234", con trỏ sau '2' = offset 3
    expect(_type('1234', 2).selection.baseOffset, 3);
  });

  test('format() và parseAmount() khớp nhau', () {
    expect(AmountInputFormatter.format(1234567), '1.234.567');
    expect(AmountInputFormatter.format(0), '0');
    expect(parseAmount('1.234.567'), 1234567);
    expect(parseAmount('1,234,567'), 1234567);
    expect(parseAmount(''), isNull);
    expect(parseAmount(AmountInputFormatter.format(50000)), 50000);
  });
}

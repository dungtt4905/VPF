import 'package:flutter/services.dart';

/// Định dạng số tiền ngay khi gõ: chỉ giữ chữ số và chèn dấu chấm phân cách hàng nghìn
/// (`1234567` -> `1.234.567`), khớp với cách hiển thị tiền trong app. Con trỏ giữ đúng vị trí.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter();

  /// Chuỗi hiển thị cho một số tiền (làm tròn đến đồng), dùng để điền sẵn vào ô nhập.
  static String format(num amount) => _group(amount.round().toString());

  static String _group(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    final cursor = newValue.selection.baseOffset.clamp(0, raw.length);

    // Bỏ số 0 đứng đầu ("007" -> "7") nhưng vẫn cho phép đúng một số "0".
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.isEmpty) return const TextEditingValue();

    // Số chữ số nằm trước con trỏ trong chuỗi gốc -> dùng để đặt lại con trỏ sau khi chèn dấu chấm.
    final digitsBeforeCursor = raw.substring(0, cursor).replaceAll(RegExp(r'[^0-9]'), '').length;
    final removedLeadingZeros = raw.replaceAll(RegExp(r'[^0-9]'), '').length - digits.length;
    final keep = (digitsBeforeCursor - removedLeadingZeros).clamp(0, digits.length);

    final formatted = _group(digits);
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < keep) {
      if (formatted[offset] != '.') seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

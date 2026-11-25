import 'package:intl/intl.dart';

/// Định dạng tiền tệ của app: chỉ dùng VND (`1.234.567đ`).
class CurrencyFormat {
  const CurrencyFormat._();

  static const vnd = CurrencyFormat._();

  String get symbol => 'đ';

  /// Chỉ phần số, không kèm đơn vị: `1.234.567`.
  String number(double amount) => NumberFormat.decimalPattern('vi').format(amount.round());

  /// Số tiền đầy đủ: `1.234.567đ`.
  String format(double amount) {
    final s = NumberFormat.decimalPattern('vi').format(amount.round());
    return '$sđ';
  }

  /// Dạng rút gọn cho thẻ nhỏ: `1.5Mđ`, `20Kđ`.
  String compact(double amount) {
    final abs = amount.abs();
    final sign = amount < 0 ? '-' : '';
    final String body;
    if (abs >= 1000000) {
      body = '${(abs / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 1000) {
      body = '${(abs / 1000).toStringAsFixed(0)}K';
    } else {
      body = abs.toStringAsFixed(0);
    }
    return '$sign$body$symbol';
  }
}

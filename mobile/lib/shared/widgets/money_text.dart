import 'package:flutter/material.dart';
import '../../core/currency/currency_format.dart';

/// Hiển thị số tiền VND với chữ `đ` nhỏ hơn và nhạt hơn phần số, để số tiền nổi bật.
class MoneyText extends StatelessWidget {
  final double amount;
  final TextStyle style;
  final String prefix; // vd. '-' hoặc '+'
  final double unitScale;
  final double unitOpacity;

  const MoneyText(
    this.amount, {
    super.key,
    required this.style,
    this.prefix = '',
    this.unitScale = 0.55,
    this.unitOpacity = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 16;
    final color = style.color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '$prefix${CurrencyFormat.vnd.number(amount)}'),
          TextSpan(
            text: ' ${CurrencyFormat.vnd.symbol}',
            style: TextStyle(
              fontSize: fontSize * unitScale,
              color: color.withValues(alpha: unitOpacity),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

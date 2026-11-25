import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'money_text.dart';

/// Phiên bản thu gọn của [SummaryHeroCard]: hiện khi thẻ lớn đã cuộn khuất khỏi màn hình.
class SummaryCompactBar extends StatelessWidget {
  final double expense;
  final double income;

  const SummaryCompactBar({super.key, required this.expense, required this.income});

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _item('Tổng chi', expense, Colors.white, CrossAxisAlignment.start)),
          Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.28)),
          const SizedBox(width: 14),
          Expanded(child: _item('Thu nhập', income, Colors.white, CrossAxisAlignment.start)),
          Expanded(
            child: _item(
              'Số dư',
              balance.abs(),
              balance < 0 ? const Color(0xFFFFD1D9) : Colors.white,
              CrossAxisAlignment.end,
              prefix: balance < 0 ? '-' : '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(String label, double value, Color color, CrossAxisAlignment align, {String prefix = ''}) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == CrossAxisAlignment.end ? Alignment.centerRight : Alignment.centerLeft,
          child: MoneyText(
            value,
            prefix: prefix,
            style: AppText.moneyMedium.copyWith(color: color, fontSize: 15),
            unitScale: 0.7,
          ),
        ),
      ],
    );
  }
}

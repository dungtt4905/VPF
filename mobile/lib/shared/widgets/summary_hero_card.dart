import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'money_text.dart';

/// Thẻ tổng quan: tổng chi (số lớn) + ô Thu nhập / Số dư + thanh "đã chi so với thu".
class SummaryHeroCard extends StatelessWidget {
  final String title;
  final String? badge;
  final double expense;
  final double income;

  const SummaryHeroCard({
    super.key,
    required this.title,
    required this.expense,
    required this.income,
    this.badge,
  });

  static const _softRed = Color(0xFFFFD1D9);

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;
    final ratio = income > 0 ? expense / income : null;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          // Vòng tròn mờ trang trí
          Positioned(right: -30, top: -40, child: _circle(130, 0.10)),
          Positioned(right: 50, bottom: -50, child: _circle(90, 0.07)),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Text(badge!,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(expense, style: AppText.moneyHero.copyWith(color: Colors.white)),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _statBox(Icons.arrow_downward_rounded, 'Thu nhập', income, Colors.white),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _statBox(
                        Icons.account_balance_wallet_outlined,
                        'Số dư',
                        balance.abs(),
                        balance < 0 ? _softRed : Colors.white,
                        sign: balance < 0 ? '-' : '',
                      ),
                    ),
                  ],
                ),
                if (ratio != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      valueColor: AlwaysStoppedAnimation(ratio > 1 ? _softRed : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ratio > 1 ? 'Chi vượt thu nhập' : 'Đã chi ${(ratio * 100).round()}% thu nhập',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: alpha), shape: BoxShape.circle),
      );

  Widget _statBox(IconData icon, String label, double value, Color valueColor, {String sign = ''}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(value,
                      prefix: sign, style: AppText.moneyMedium.copyWith(color: valueColor), unitScale: 0.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

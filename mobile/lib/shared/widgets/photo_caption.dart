import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Lớp phủ thông tin trên ảnh giao dịch: gradient ở đáy + pill số tiền + tên danh mục.
/// Đặt làm con của một Stack (đã fill theo ảnh). Mỗi ảnh chỉ có đúng một lớp thông tin này.
class PhotoCaption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String amountText;
  final bool isIncome;
  final String? label; // tên danh mục (1 dòng)
  final bool compact;

  const PhotoCaption({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.amountText,
    this.isIncome = false,
    this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pad = compact ? 8.0 : 12.0;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.18), Colors.black.withValues(alpha: 0.72)],
            stops: const [0.45, 0.7, 1.0],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pill(),
                if (label != null && label!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill() {
    final bg = isIncome ? AppColors.income.withValues(alpha: 0.92) : Colors.black.withValues(alpha: 0.42);
    final size = compact ? 18.0 : 22.0;
    return Container(
      padding: EdgeInsets.fromLTRB(3, 3, compact ? 8 : 10, 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: isIncome ? Colors.white : iconColor, shape: BoxShape.circle),
            child: Icon(icon, size: size * 0.6, color: isIncome ? AppColors.income : Colors.white),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isIncome ? '+$amountText' : amountText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.moneySmall.copyWith(color: Colors.white, fontSize: compact ? 12 : 13),
            ),
          ),
        ],
      ),
    );
  }
}

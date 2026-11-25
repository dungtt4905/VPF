import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/analytics/cubit/analytics_cubit.dart' show AnalyticsPeriod;

/// Thanh chọn kỳ (tuần/tháng) dùng chung cho màn Phân tích và màn Danh sách giao dịch:
/// mũi tên trước/sau, bấm giữa để chọn ngày, "Về tuần/tháng này".
class PeriodSelector extends StatelessWidget {
  final AnalyticsPeriod period;
  final DateTime start;
  final DateTime end; // đầu kỳ kế tiếp (loại trừ)
  final bool isCurrent;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCurrent;
  final ValueChanged<DateTime> onPick;

  const PeriodSelector({
    super.key,
    required this.period,
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
    required this.onPick,
  });

  /// Nhãn kỳ: "Tháng 11, 2026" hoặc "17/11 - 23/11/2026".
  String get label {
    if (period == AnalyticsPeriod.month) return 'Tháng ${start.month}, ${start.year}';
    final last = end.subtract(const Duration(days: 1));
    String dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${dm(start)} - ${dm(last)}/${last.year}';
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start.isAfter(now) ? now : start,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: period == AnalyticsPeriod.week ? 'Chọn ngày trong tuần cần xem' : 'Chọn ngày trong tháng cần xem',
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isWeek = period == AnalyticsPeriod.week;

    Widget arrow(IconData icon, VoidCallback? onTap) => IconButton(
          onPressed: onTap,
          icon: Icon(icon),
          color: AppColors.primaryDark,
          disabledColor: AppColors.border,
          visualDensity: VisualDensity.compact,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          arrow(Icons.chevron_left_rounded, onPrevious),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => _pickDate(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primaryDark),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: const TextStyle(
                              color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                    if (isCurrent)
                      Text(isWeek ? 'Tuần này' : 'Tháng này', style: AppText.caption)
                    else
                      GestureDetector(
                        onTap: onCurrent,
                        child: Text(
                          isWeek ? 'Về tuần này' : 'Về tháng này',
                          style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          arrow(Icons.chevron_right_rounded, isCurrent ? null : onNext),
        ],
      ),
    );
  }
}

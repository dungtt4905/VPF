import 'package:flutter/material.dart';
import '../../core/budget/budget_impact_service.dart';
import '../../core/currency/currency_format.dart';
import '../../core/theme/app_colors.dart';

/// Đọc số tiền người dùng nhập: bỏ dấu phân cách hàng nghìn ("." hoặc ",") và khoảng trắng.
/// Trả về null nếu không phải số hợp lệ.
double? parseAmount(String text) => double.tryParse(text.replaceAll(RegExp(r'[.,\s]'), ''));

/// Hỏi xác nhận khi khoản chi làm vượt (hoặc vượt thêm) ngân sách.
/// Trả về true nếu được phép lưu: không có ngân sách nào bị vượt, hoặc người dùng chọn "Vẫn lưu".
Future<bool> confirmBudgetExceed(BuildContext context, List<BudgetImpact> impacts) async {
  final exceeded = impacts.where((i) => i.causesExceed).toList();
  if (exceeded.isEmpty) return true;

  final money = CurrencyFormat.vnd;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: const Text('Khoản chi này vượt ngân sách'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in exceeded)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '• ${i.name}: ${money.compact(i.after.used)} / ${money.compact(i.after.limit)}'
                ' (vượt ${money.compact(i.after.used - i.after.limit)})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          const Text('Bạn vẫn muốn lưu giao dịch này?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Xem lại', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.expense,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
          child: const Text('Vẫn lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return ok == true;
}

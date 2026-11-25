/// Tính toán chia thu nhập theo % cho màn lập kế hoạch tháng. Không phụ thuộc giao dịch.
class BudgetPlanner {
  BudgetPlanner._();

  /// Số tiền ứng với [percent]% của [income], làm tròn đến nghìn đồng.
  static double amountFromPercent(double income, double percent) {
    if (income <= 0 || percent <= 0) return 0;
    return ((income * percent / 100) / 1000).round() * 1000.0;
  }

  /// Tỷ lệ phần trăm của [amount] trên [income] (0 nếu chưa có thu nhập).
  static double percentFromAmount(double income, double amount) {
    if (income <= 0 || amount <= 0) return 0;
    return amount / income * 100;
  }
}

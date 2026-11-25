/// Phương thức thanh toán cho phép chọn khi tạo/sửa giao dịch.
/// Giá trị lưu trong DB (giữ nguyên để tương thích dữ liệu cũ) -> nhãn tiếng Việt hiển thị.
const Map<String, String> kPaymentMethodLabels = {
  'Cash': 'Tiền mặt',
  'Bank Transfer': 'Chuyển khoản',
};

/// Phương thức đã bỏ khỏi lựa chọn nhưng giao dịch cũ có thể còn dùng (chỉ để hiển thị).
const Map<String, String> _legacyPaymentLabels = {
  'E-Wallet': 'Ví điện tử',
};

String paymentLabel(String value) => kPaymentMethodLabels[value] ?? _legacyPaymentLabels[value] ?? value;

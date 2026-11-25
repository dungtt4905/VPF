import 'package:flutter/material.dart';

/// Bảng màu theo vai trò. Dùng các token này thay vì viết mã màu trực tiếp trong từng màn.
class AppColors {
  AppColors._();

  // Thương hiệu / Thu nhập
  static const primary = Color(0xFF13A884);
  static const primaryDark = Color(0xFF0F8C6E);
  static const primarySoft = Color(0xFFE1F7EF);
  static const income = primary;
  static const incomeSoft = primarySoft;

  // Chi tiêu
  static const expense = Color(0xFFFF4D6A);
  static const expenseSoft = Color(0xFFFFE3E8);

  // Số dư / thông tin
  static const balance = Color(0xFF2B6CB0);
  static const balanceSoft = Color(0xFFE3EEFA);

  // Cảnh báo (ngân sách gần hết)
  static const warning = Color(0xFFF5A623);
  static const warningSoft = Color(0xFFFFF1D6);

  // Nền & chữ
  static const background = Color(0xFFF6F7F5); // nền xám ấm của các tab
  static const surface = Colors.white;
  static const border = Color(0xFFE8EAE6);
  static const textPrimary = Color(0xFF1B1F1D);
  static const textSecondary = Color(0xFF6B726E);
  static const textMuted = Color(0xFF9AA19D);
}

/// Khoảng cách theo lưới 4/8.
class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = 20.0; // lề ngang của tab và padding trong thẻ lớn
}

/// Bo góc thống nhất.
class AppRadius {
  AppRadius._();
  static const xs = 8.0; // badge, thanh tiến độ, chip nhỏ
  static const chip = 12.0;
  static const md = 16.0; // ô nhập, nút, thumbnail
  static const pill = 28.0; // nút bo tròn hẳn
  static const card = 20.0;
  static const hero = 24.0;
}

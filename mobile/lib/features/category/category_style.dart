import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../models/enums.dart';

/// Icon (lưu dạng tên chuỗi trong CategoryModel.icon) -> IconData.
const Map<String, IconData> kCategoryIcons = {
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'directions_car': Icons.directions_car,
  'directions_bus': Icons.directions_bus,
  'local_gas_station': Icons.local_gas_station,
  'shopping_bag': Icons.shopping_bag,
  'shopping_cart': Icons.shopping_cart,
  'receipt': Icons.receipt_long,
  'home': Icons.home,
  'bolt': Icons.bolt,
  'phone_android': Icons.phone_android,
  'movie': Icons.movie,
  'sports_esports': Icons.sports_esports,
  'fitness_center': Icons.fitness_center,
  'medical_services': Icons.medical_services,
  'school': Icons.school,
  'flight': Icons.flight,
  'pets': Icons.pets,
  'card_giftcard': Icons.card_giftcard,
  'savings': Icons.savings,
  'security': Icons.security,
  'trending_up': Icons.trending_up,
  'account_balance_wallet': Icons.account_balance_wallet,
  'attach_money': Icons.attach_money,
  'star': Icons.star,
  'category': Icons.category,
};

/// Bảng màu preset (hex).
const List<String> kCategoryColors = [
  '#FF5722', '#FF9800', '#FFC107', '#8BC34A', '#4CAF50', '#009688',
  '#2196F3', '#3F51B5', '#673AB7', '#9C27B0', '#E91E63', '#795548',
];

IconData categoryIcon(String? name) => kCategoryIcons[name] ?? Icons.category;

Color categoryColor(String? hex) {
  if (hex == null) return Colors.grey;
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? Colors.grey : Color(v);
}

/// Danh mục có thể chọn khi tạo giao dịch: bỏ các nhóm cha đã có danh mục con.
List<CategoryModel> selectableCategories(List<CategoryModel> all, TransactionType type) {
  final ofType = all.where((c) => c.type == type).toList();
  final parentIds = ofType.map((c) => c.parentId).whereType<String>().toSet();
  return ofType.where((c) => !parentIds.contains(c.syncId)).toList();
}

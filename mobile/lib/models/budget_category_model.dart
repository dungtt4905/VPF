import 'package:isar/isar.dart';

part 'budget_category_model.g.dart';

/// Bảng liên kết hũ <-> danh mục. Trong một kế hoạch, mỗi danh mục chỉ thuộc tối đa một hũ
/// (ràng buộc do repository đảm bảo). Category không giữ id của hũ.
@collection
class BudgetCategoryModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  /// syncId của hũ và của kế hoạch chứa hũ đó (lưu cả planId để kiểm tra trùng danh mục trong kế hoạch).
  @Index()
  late String jarId;
  @Index()
  late String planId;

  late String categoryId;

  /// Tên danh mục tại thời điểm gắn vào hũ (snapshot) để lịch sử không đổi khi danh mục bị đổi tên/xóa.
  late String categoryName;

  bool isSynced = false;
  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? deletedAt;

  BudgetCategoryModel();

  factory BudgetCategoryModel.fromJson(Map<String, dynamic> json) {
    return BudgetCategoryModel()
      ..syncId = json['id'] as String
      ..jarId = json['jarId'] as String
      ..planId = json['planId'] as String
      ..categoryId = json['categoryId'] as String
      ..categoryName = json['categoryName'] as String
      ..isSynced = true
      ..createdAt = DateTime.parse(json['createdAt'] as String).toLocal()
      ..updatedAt = DateTime.parse(json['updatedAt'] as String).toLocal()
      ..deletedAt = json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String).toLocal() : null;
  }

  Map<String, dynamic> toJson() => {
        'id': syncId,
        'jarId': jarId,
        'planId': planId,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
      };
}

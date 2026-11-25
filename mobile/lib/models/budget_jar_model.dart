import 'package:isar/isar.dart';
import 'json_utils.dart';

part 'budget_jar_model.g.dart';

/// Một hũ ngân sách thuộc một kế hoạch. Danh mục của hũ nằm ở [BudgetCategoryModel], không nằm ở đây,
/// nên hũ có thể có 0, 1 hoặc nhiều danh mục.
@collection
class BudgetJarModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  /// syncId của [BudgetPlanModel] chứa hũ này.
  @Index()
  late String planId;

  /// Định danh ổn định của hũ qua các kỳ: các hũ cùng jarKey ở các kế hoạch khác nhau là "cùng một hũ"
  /// (dùng cho rollover, streak, lịch sử).
  @Index()
  late String jarKey;

  /// Tên hũ tại thời điểm tạo kế hoạch (snapshot, không đổi theo tên danh mục).
  late String name;
  late double amount;
  int alertThreshold = 80;
  bool rollover = false;

  /// true cho hũ chuyển từ "Tổng ngân sách" cũ (không gắn danh mục, tính trên mọi chi tiêu).
  bool isTotal = false;

  /// Thời điểm đánh dấu "đã trả" (chỉ dùng cho hũ không có danh mục, ví dụ tiền nhà, trả nợ). null = chưa trả.
  DateTime? paidAt;

  bool isSynced = false;
  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? deletedAt;

  BudgetJarModel();

  factory BudgetJarModel.fromJson(Map<String, dynamic> json) {
    return BudgetJarModel()
      ..syncId = json['id'] as String
      ..planId = json['planId'] as String
      ..jarKey = json['jarKey'] as String
      ..name = json['name'] as String
      ..amount = parseDouble(json['amount'])
      ..alertThreshold = (json['alertThreshold'] as num?)?.toInt() ?? 80
      ..rollover = json['rollover'] as bool? ?? false
      ..isTotal = json['isTotal'] as bool? ?? false
      ..paidAt = json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String).toLocal() : null
      ..isSynced = true
      ..createdAt = DateTime.parse(json['createdAt'] as String).toLocal()
      ..updatedAt = DateTime.parse(json['updatedAt'] as String).toLocal()
      ..deletedAt = json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String).toLocal() : null;
  }

  Map<String, dynamic> toJson() => {
        'id': syncId,
        'planId': planId,
        'jarKey': jarKey,
        'name': name,
        'amount': amount,
        'alertThreshold': alertThreshold,
        'rollover': rollover,
        'isTotal': isTotal,
        'paidAt': paidAt?.toUtc().toIso8601String(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
      };
}

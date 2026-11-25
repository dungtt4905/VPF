import 'package:isar/isar.dart';
import 'json_utils.dart';

part 'budget_plan_model.g.dart';

/// Kế hoạch ngân sách của một khoảng thời gian (hiện là một tháng). Chứa các hũ ([BudgetJarModel]).
@collection
class BudgetPlanModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  /// Đầu kỳ (ngày 1 của tháng, giờ local) và cuối kỳ (ngày 1 của tháng sau, không bao gồm).
  @Index()
  late DateTime periodStart;
  late DateTime periodEnd;

  /// Thu nhập dự kiến của kỳ (0 = chưa nhập).
  double expectedIncome = 0;

  bool isSynced = false;
  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? deletedAt;

  BudgetPlanModel();

  factory BudgetPlanModel.fromJson(Map<String, dynamic> json) {
    return BudgetPlanModel()
      ..syncId = json['id'] as String
      ..periodStart = DateTime.parse(json['periodStart'] as String).toLocal()
      ..periodEnd = DateTime.parse(json['periodEnd'] as String).toLocal()
      ..expectedIncome = parseDouble(json['expectedIncome'])
      ..isSynced = true
      ..createdAt = DateTime.parse(json['createdAt'] as String).toLocal()
      ..updatedAt = DateTime.parse(json['updatedAt'] as String).toLocal()
      ..deletedAt = json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String).toLocal() : null;
  }

  Map<String, dynamic> toJson() => {
        'id': syncId,
        'periodStart': periodStart.toUtc().toIso8601String(),
        'periodEnd': periodEnd.toUtc().toIso8601String(),
        'expectedIncome': expectedIncome,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
      };
}

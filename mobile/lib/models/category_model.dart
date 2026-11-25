import 'package:isar/isar.dart';
import 'enums.dart';

part 'category_model.g.dart';

@collection
class CategoryModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  String? parentId;
  late String name;
  String? icon;
  String? color;

  @enumerated
  late TransactionType type;

  bool isPredefined = false;

  bool isSynced = false;
  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? deletedAt;

  CategoryModel();

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel()
      ..syncId = json['id'] as String
      ..parentId = json['parentId'] as String?
      ..name = json['name'] as String
      ..icon = json['icon'] as String?
      ..color = json['color'] as String?
      ..type = TransactionType.values.byName((json['type'] as String).toLowerCase())
      ..isPredefined = json['isPredefined'] as bool? ?? false
      ..isSynced = true
      ..createdAt = DateTime.parse(json['createdAt'] as String).toLocal()
      ..updatedAt = DateTime.parse(json['updatedAt'] as String).toLocal()
      ..deletedAt = json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String).toLocal() : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': syncId,
      'parentId': parentId,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type.name.toUpperCase(),
      'isPredefined': isPredefined,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
    };
  }
}

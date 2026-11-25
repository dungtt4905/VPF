import 'package:isar/isar.dart';
import 'enums.dart';
import 'json_utils.dart';

part 'transaction_model.g.dart';

@collection
class TransactionModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  late String categoryId;
  late String title;
  late double amount;

  @enumerated
  late TransactionType type;

  late String paymentMethod;
  String? note;

  String? localImagePath;
  String? localThumbnailPath;
  String? cloudImageUrl;
  String? cloudImageKey;

  late DateTime transactionAt;

  bool isSynced = false;
  late DateTime createdAt;
  late DateTime updatedAt;
  DateTime? deletedAt;

  TransactionModel();

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel()
      ..syncId = json['id'] as String
      ..categoryId = json['categoryId'] as String
      ..title = json['title'] as String
      ..amount = parseDouble(json['amount'])
      ..type = TransactionType.values.byName((json['type'] as String).toLowerCase())
      ..paymentMethod = json['paymentMethod'] as String
      ..note = json['note'] as String?
      ..cloudImageUrl = json['imageUrl'] as String?
      ..cloudImageKey = json['imageKey'] as String?
      ..transactionAt = DateTime.parse(json['transactionAt'] as String).toLocal()
      ..isSynced = true
      ..createdAt = DateTime.parse(json['createdAt'] as String).toLocal()
      ..updatedAt = DateTime.parse(json['updatedAt'] as String).toLocal()
      ..deletedAt = json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String).toLocal() : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': syncId,
      'categoryId': categoryId,
      'title': title,
      'amount': amount,
      'type': type.name.toUpperCase(),
      'paymentMethod': paymentMethod,
      'note': note,
      'imageUrl': cloudImageUrl,
      'imageKey': cloudImageKey,
      'transactionAt': transactionAt.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
    };
  }
}

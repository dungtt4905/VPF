import 'package:get_it/get_it.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../services/avatar_service.dart';
import '../services/cloud_image_service.dart';
import '../services/image_storage_service.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';
import '../network/dio_client.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/budget_plan_repository.dart';
import '../../models/budget_plan_model.dart';
import '../../models/budget_jar_model.dart';
import '../../models/budget_category_model.dart';
import '../repositories/auth_repository.dart';
import '../budget/budget_impact_service.dart';
import '../services/budget_notification_service.dart';
import '../services/transaction_reminder_service.dart';

final getIt = GetIt.instance;

Future<void> setupInjection() async {
  // Lấy đường dẫn thư mục an toàn trên thiết bị để lưu DB
  final dir = await getApplicationDocumentsDirectory();

  // Mở database Isar
  final isar = await Isar.open(
    [
      TransactionModelSchema,
      CategoryModelSchema,
      BudgetPlanModelSchema,
      BudgetJarModelSchema,
      BudgetCategoryModelSchema,
    ],
    directory: dir.path,
  );

  // Đăng ký Isar vào GetIt để dùng ở bất cứ đâu trong app
  getIt.registerSingleton<Isar>(isar);

  // Đăng ký các Services & Network
  getIt.registerLazySingleton(() => SecureStorageService());
  getIt.registerLazySingleton(() => DioClient(getIt()));
  getIt.registerLazySingleton(() => ImageStorageService());
  getIt.registerLazySingleton(() => CloudImageService(getIt()));
  getIt.registerLazySingleton(() => AvatarService(getIt(), getIt(), getIt(), getIt()));

  // Đăng ký các Repositories
  getIt.registerLazySingleton(() => AuthRepository(getIt(), getIt(), getIt(), getIt()));
  getIt.registerLazySingleton(() => CategoryRepository(getIt()));
  getIt.registerLazySingleton(() => TransactionRepository(getIt(), getIt()));
  getIt.registerLazySingleton(() => BudgetPlanRepository(getIt(), getIt()));

  // Đồng bộ dữ liệu với server
  getIt.registerLazySingleton(() => SyncService(getIt(), getIt(), getIt(), getIt(), getIt(), getIt()));

  // Ngân sách: tính ảnh hưởng của giao dịch + thông báo
  getIt.registerLazySingleton(() => BudgetImpactService(getIt(), getIt(), getIt()));
  getIt.registerLazySingleton(() => BudgetNotificationService());
  getIt.registerLazySingleton(() => TransactionReminderService());

}

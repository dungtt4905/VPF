import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'app/router.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'core/repositories/budget_plan_repository.dart';
import 'core/repositories/category_repository.dart';
import 'core/repositories/transaction_repository.dart';
import 'core/services/budget_notification_service.dart';
import 'core/services/avatar_service.dart';
import 'core/services/transaction_reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  Intl.defaultLocale = 'vi';

  // Khởi tạo các dependency (Local DB, Network, Service) trước khi chạy UI
  await setupInjection();

  await getIt<AvatarService>().load();

  // Khởi tạo dữ liệu danh mục mặc định
  await getIt<CategoryRepository>().seedDefaultCategories();

  // Bảo đảm có kế hoạch ngân sách cho tháng hiện tại (sao chép từ tháng trước nếu là tháng mới).
  await getIt<BudgetPlanRepository>().ensureCurrentPlan();

  // Thông báo ngân sách: khởi tạo (không chặn UI nếu lỗi) và hủy lịch nhắc chi tiêu hằng ngày cũ nếu còn.
  final notifications = getIt<BudgetNotificationService>();
  await notifications.init();
  await notifications.cancelLegacyDailyReminder();

  // Nhắc ghi giao dịch hằng ngày (người dùng bật/tắt và chọn giờ ở màn Hồ sơ).
  final reminder = getIt<TransactionReminderService>();
  await reminder.init();
  await reminder.reschedule();

  // Thử upload lại các ảnh chưa lên cloud (vd. lần trước bị mất mạng), không chặn UI.
  unawaited(getIt<TransactionRepository>().uploadPendingImages().catchError((_) {}));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(getIt(), getIt())..checkAuthStatus()),
      ],
      child: MaterialApp.router(
        title: 'VPF',
        theme: AppTheme.light,
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
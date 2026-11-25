import 'package:go_router/go_router.dart';
import 'package:mobile/features/main/main_layout.dart';
import '../features/home/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainLayout(),
    ),
  ],
);
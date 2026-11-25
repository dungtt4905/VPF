import 'package:go_router/go_router.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/main/main_layout.dart';
import '../core/di/injection.dart';
import '../core/repositories/auth_repository.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final authRepo = getIt<AuthRepository>();
    final isLoggedIn = await authRepo.isLoggedIn();
    
    final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

    if (!isLoggedIn && !isLoggingIn) return '/login';
    if (isLoggedIn && isLoggingIn) return '/main';

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) => const MainLayout(),
    ),
  ],
);

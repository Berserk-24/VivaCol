import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/property/property_detail_screen.dart';
import '../screens/publish/publish_property_screen.dart';
import '../screens/report/report_change_screen.dart';

/// Configuracion centralizada de rutas con go_router.
/// Se elige go_router por su enrutamiento declarativo, el manejo
/// sencillo de parametros de ruta y una mejor escalabilidad frente
/// a anidar Navigator.push manualmente en toda la app.
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/property/:id',
        builder: (context, state) => PropertyDetailScreen(
          propertyId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/report/:id',
        builder: (context, state) => ReportChangeScreen(
          propertyId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/publish',
        builder: (context, state) => const PublishPropertyScreen(),
      ),
    ],
  );
}

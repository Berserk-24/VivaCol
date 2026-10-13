import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/intro/intro_screen.dart';
import '../screens/map/map_screen.dart';
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

  /// Construye el router con proteccion de rutas segun la sesion.
  static GoRouter createRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/intro',
      refreshListenable: auth,
      redirect: (context, state) {
        final location = state.matchedLocation;
        // El splash siempre se muestra al abrir la app.
        if (location == '/intro') return null;

        if (auth.loading) return null;

        final loggedIn = auth.isLoggedIn;
        final onPublicRoute = location == '/' || location == '/login';

        if (!loggedIn) {
          return onPublicRoute ? null : '/login';
        }
        // Ya autenticado: no permanecer en onboarding ni login.
        if (onPublicRoute) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/intro',
          builder: (context, state) => const IntroScreen(),
        ),
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
          path: '/map',
          builder: (context, state) => const MapScreen(),
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
}

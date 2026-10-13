import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/property_repository.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const VivaColApp());
}

class VivaColApp extends StatelessWidget {
  const VivaColApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PropertyRepository>(create: (_) => PropertyRepository()),
        Provider<StorageService>(create: (_) => StorageService()),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(AuthService()),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: const _AppRouterHost(),
    );
  }
}

/// Construye el router una sola vez con acceso al AuthProvider para
/// proteger rutas y reaccionar a los cambios de sesion.
class _AppRouterHost extends StatefulWidget {
  const _AppRouterHost();

  @override
  State<_AppRouterHost> createState() => _AppRouterHostState();
}

class _AppRouterHostState extends State<_AppRouterHost> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    return MaterialApp.router(
      title: 'VivaCol',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}

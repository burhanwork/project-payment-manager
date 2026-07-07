import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/app_user.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'utils/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/home_shell.dart';
import 'screens/splash/splash_screen.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Run the app immediately — async init happens inside via FutureBuilder
  runApp(const AppBootstrapper());
}

/// Handles async initialization (Firebase, auth restore) before showing the app.
class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  Future<({AuthService authService, AppUser? initialUser})>? _init;

  @override
  void initState() {
    super.initState();
    // Defer bootstrap to after the first frame so all native plugin handlers
    // are registered (fixes iOS 26 platform-channel timing issue).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _init = _bootstrap();
      });
    });
  }

  Future<({AuthService authService, AppUser? initialUser})> _bootstrap() async {
    // Initialize local SQLite database
    await DatabaseService.initialize();

    final authService = AuthService();
    final initialUser = await authService.initializeUser();

    return (authService: authService, initialUser: initialUser);
  }

  ({AuthService authService, AppUser? initialUser})? _bootstrapResult;

  void _onSplashComplete(dynamic result) {
    if (result != null) {
      setState(() {
        _bootstrapResult = result as ({AuthService authService, AppUser? initialUser});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show main app once splash is done and init is complete
    if (_bootstrapResult != null) {
      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_bootstrapResult!.authService),
          currentUserProvider.overrideWith((ref) => _bootstrapResult!.initialUser),
        ],
        child: const QuickBooksApp(),
      );
    }

    // Show animated splash while bootstrapping
    if (_init == null) {
      // Not yet started — show plain navy screen briefly
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Color(0xFF0A1540)),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnimatedSplashScreen(
        initFuture: _init!,
        onComplete: _onSplashComplete,
      ),
    );
  }
}

class QuickBooksApp extends ConsumerWidget {
  const QuickBooksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return MaterialApp(
      title: 'Project Payment Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: currentUser != null ? const HomeShell() : const LoginScreen(),
    );
  }
}

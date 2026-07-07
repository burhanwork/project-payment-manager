import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'utils/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/home_shell.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await DatabaseService.initialize();
  
  // Auto-login for visual testing
  final authService = AuthService();
  final user = await authService.signIn('john@dev.com', 'password123');
  debugPrint('AUTO-LOGIN: user=${user?.name}, role=${user?.role}');

  runApp(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      currentUserProvider.overrideWith((ref) => user),
    ],
    child: MaterialApp(
      title: 'Project Payment Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: user != null ? const HomeShell() : const LoginScreen(),
    ),
  ));
}

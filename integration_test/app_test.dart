import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:project_payment_manager/main.dart';
import 'package:project_payment_manager/services/database_service.dart';
import 'package:project_payment_manager/services/auth_service.dart';
import 'package:project_payment_manager/services/api_client.dart';
import 'package:project_payment_manager/providers/auth_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Tests', () {
    testWidgets('0. API connectivity and login endpoint', (tester) async {
      await DatabaseService.initialize();
      // Clear any cached token
      await ApiClient.setToken(null);

      debugPrint('BASE URL: ${ApiClient.baseUrl}');

      // Test health endpoint
      final healthResp = await http.get(
        Uri.parse('${ApiClient.baseUrl}/health'),
      ).timeout(const Duration(seconds: 5));
      debugPrint('Health: ${healthResp.statusCode} - ${healthResp.body}');
      expect(healthResp.statusCode, 200);

      // Test login endpoint
      final loginResp = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': 'john@dev.com',
          'password': 'password123',
        }),
      ).timeout(const Duration(seconds: 5));
      debugPrint('Login: ${loginResp.statusCode}');
      expect(loginResp.statusCode, 200);

      final loginData = json.decode(loginResp.body);
      expect(loginData['user']['email'], 'john@dev.com');
      expect(loginData['user']['role'], 'developer');
      expect(loginData['token'], isNotNull);

      debugPrint('TEST 0 PASSED - API connectivity and login work');
    });

    testWidgets('1. Login screen displays correctly', (tester) async {
      await DatabaseService.initialize();
      await ApiClient.setToken(null);
      final authService = AuthService();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentUserProvider.overrideWith((ref) => null),
        ],
        child: const QuickBooksApp(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Project Payment Manager'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));

      debugPrint('TEST 1 PASSED - Login screen displays correctly');
    });

    testWidgets('2. Login with valid credentials + navigate all tabs',
        (tester) async {
      await DatabaseService.initialize();
      await ApiClient.setToken(null);
      final authService = AuthService();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentUserProvider.overrideWith((ref) => null),
        ],
        child: const QuickBooksApp(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Enter credentials
      await tester.enterText(
          find.byType(TextFormField).first, 'john@dev.com');
      await tester.enterText(
          find.byType(TextFormField).last, 'password123');
      await tester.pump();

      // Tap Sign In
      await tester.tap(find.text('Sign In'));

      // Wait for dashboard
      bool loggedIn = false;
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(BottomNavigationBar).evaluate().isNotEmpty) {
          loggedIn = true;
          debugPrint('Dashboard found after ${(i + 1) * 500}ms');
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(loggedIn, isTrue, reason: 'Should navigate to dashboard');

      // Navigate all 5 tabs
      for (final tab in [
        'Projects',
        'Payments',
        'Approvals',
        'Profile',
        'Dashboard'
      ]) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        debugPrint('Navigated to $tab tab');
      }

      debugPrint('TEST 2 PASSED - Login + all tab navigation works');
    });

    testWidgets('3. Invalid login shows error message', (tester) async {
      await DatabaseService.initialize();
      await ApiClient.setToken(null);
      final authService = AuthService();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentUserProvider.overrideWith((ref) => null),
        ],
        child: const QuickBooksApp(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Enter wrong credentials
      await tester.enterText(
          find.byType(TextFormField).first, 'wrong@email.com');
      await tester.enterText(
          find.byType(TextFormField).last, 'wrongpassword');
      await tester.pump();

      await tester.tap(find.text('Sign In'));

      // Wait for error
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.text('Invalid email or password').evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();

      // Should still be on login screen with error
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Invalid email or password'), findsOneWidget);

      debugPrint('TEST 3 PASSED - Invalid login shows error correctly');
    });

    testWidgets('4. Form validation works', (tester) async {
      await DatabaseService.initialize();
      await ApiClient.setToken(null);
      final authService = AuthService();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentUserProvider.overrideWith((ref) => null),
        ],
        child: const QuickBooksApp(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap Sign In without entering anything
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Should see validation errors
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);

      debugPrint('TEST 4 PASSED - Form validation works');
    });
  });
}

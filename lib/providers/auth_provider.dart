import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final currentUserProvider = StateProvider<AppUser?>((ref) {
  final authService = ref.read(authServiceProvider);
  return authService.getCurrentUser();
});

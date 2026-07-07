import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/animated_gradient_button.dart';
import '../dashboard/home_shell.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  UserRole _selectedRole = UserRole.developer;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final user = await authService.register(
      email: _emailController.text,
      password: _passwordController.text,
      name: _nameController.text,
      role: _selectedRole,
    );

    if (user != null) {
      ref.read(currentUserProvider.notifier).state = user;
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => const HomeShell(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (c, animation, a2, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Email already registered';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryDark, AppTheme.primaryColor, AppTheme.primaryLight],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    ),
                    Text('Create Account',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Join Us',
                                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
                              const SizedBox(height: 4),
                              Text('Create your account to get started',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                              const SizedBox(height: 24),

                              if (_errorMessage != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_errorMessage!,
                                        style: const TextStyle(color: AppTheme.errorColor, fontSize: 13))),
                                    ],
                                  ),
                                ).animate().shake(hz: 3, duration: 400.ms),

                              TextFormField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person_outlined, color: Colors.grey.shade400),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade400),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (!v.contains('@')) return 'Invalid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              Text('Select Role',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                              const SizedBox(height: 8),
                              Row(
                                children: UserRole.values.map((role) {
                                  final isSelected = _selectedRole == role;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedRole = role),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        margin: EdgeInsets.only(right: role != UserRole.accountant ? 8 : 0),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          gradient: isSelected ? AppTheme.primaryGradient : null,
                                          color: isSelected ? null : Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? Colors.transparent : Colors.grey.shade200),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(_roleIcon(role),
                                              color: isSelected ? Colors.white : Colors.grey.shade500, size: 22),
                                            const SizedBox(height: 4),
                                            Text(_roleLabel(role),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                                color: isSelected ? Colors.white : Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: Colors.grey.shade400),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  if (v.length < 6) return 'Min 6 characters';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (v) => _handleRegister(),
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: Colors.grey.shade400),
                                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                ),
                                validator: (v) => v != _passwordController.text ? 'Passwords don\'t match' : null,
                              ),
                              const SizedBox(height: 28),

                              AnimatedGradientButton(
                                label: 'Create Account',
                                icon: Icons.person_add_rounded,
                                isLoading: _isLoading,
                                onPressed: _handleRegister,
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.developer: return Icons.code_rounded;
      case UserRole.boss: return Icons.person_rounded;
      case UserRole.accountant: return Icons.calculate_rounded;
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.developer: return 'Developer';
      case UserRole.boss: return 'Boss';
      case UserRole.accountant: return 'Accountant';
    }
  }
}

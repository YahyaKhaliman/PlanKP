// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nikCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nikCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_nikCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: AppColors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PlanKP',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sistem Penjadwalan Kencana Print',
                    style: TextStyle(
                        color: AppColors.white.withOpacity(0.75), fontSize: 13),
                  ),
                ],
              ),
            ),

            // Card form
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: const BoxDecoration(
                  color: AppColors.bgGray,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Masuk',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Gunakan username dan password Anda',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 28),

                      // username
                      TextFormField(
                        controller: _nikCtrl,
                        decoration: const InputDecoration(
                          labelText: 'username',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'username wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Password wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 8),

                      // Error
                      Consumer<AuthProvider>(
                        builder: (_, auth, __) {
                          if (auth.error == null)
                            return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.danger, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(auth.error!,
                                        style: const TextStyle(
                                            color: AppColors.danger,
                                            fontSize: 13))),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // Tombol login
                      Consumer<AuthProvider>(
                        builder: (_, auth, __) => Column(
                          children: [
                            ElevatedButton(
                              onPressed: auth.loading ? null : _submit,
                              child: auth.loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('Masuk'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(
                                  context, AppRoutes.register),
                              child: const Text('Belum punya akun? Daftar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

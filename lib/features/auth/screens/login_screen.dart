// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/app_notifier.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  // Warna Identitas Jago (Fallback jika AppColors tidak sesuai)
  final Color jagoPurple = const Color(0xFF2A0054);
  final Color jagoYellow = const Color(0xFFFFD000);
  final Color jagoLightGrey = const Color(0xFFF2F2F2);

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      await AppNotifier.showWarning(
          context, 'Lengkapi username dan password terlebih dahulu');
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.loading) return;

    final ok = await auth.login(_usernameCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) {
      AppNotifier.showSuccessSnack(context, 'Login berhasil, selamat datang');
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
    } else if (mounted) {
      final error = auth.error ?? 'Tidak dapat login saat ini';
      await AppNotifier.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1100 : double.infinity,
              ),
              child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: _buildHeroText(isDark: true),
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: SizedBox(
              width: 450,
              child: _buildLoginCard(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 80),
          decoration: BoxDecoration(
            color: jagoYellow,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(40),
            ),
          ),
          child: _buildHeroText(isDark: false),
        ),
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildLoginCard(),
          ),
        ),
        _buildFooterLink(),
      ],
    );
  }

  Widget _buildHeroText({required bool isDark}) {
    final color = isDark ? jagoPurple : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? jagoYellow : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.calendar_today_rounded,
              color: isDark ? Colors.white : Colors.white, size: 32),
        ),
        const SizedBox(height: 24),
        Text(
          'PlanKP.',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Solusi cerdas kelola jadwal maintenance dan realisasi operasional harian Anda.',
          style: TextStyle(
            fontSize: 18,
            color: color.withOpacity(0.8),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Masuk',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: jagoPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gunakan akun operasional Anda',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 32),
            _buildInputField(
              controller: _usernameCtrl,
              label: 'Username',
              icon: Icons.alternate_email_rounded,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Username wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _passCtrl,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
            ),
            const SizedBox(height: 32),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => ElevatedButton(
                onPressed: auth.loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: jagoYellow,
                  foregroundColor: jagoPurple,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: auth.loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Color(0xFF2A0054)),
                      )
                    : const Text(
                        'Masuk Sekarang',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: jagoPurple.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: jagoPurple),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: onToggle,
                color: Colors.grey,
              )
            : null,
        filled: true,
        fillColor: jagoLightGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }

  Widget _buildFooterLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Belum punya akun?'),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
            child: Text(
              'Daftar Disini',
              style: TextStyle(fontWeight: FontWeight.bold, color: jagoPurple),
            ),
          ),
        ],
      ),
    );
  }
}

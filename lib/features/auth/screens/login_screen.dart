import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/update/update_checker.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/app_notifier.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _pageBg = Color(0xFFF8FAFC);
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final UpdateChecker _updateChecker = UpdateChecker();
  bool _rememberMe = false;
  bool _obscure = true;
  String _appVersionLabel = 'Versi -';
  String _updateStatusLabel = 'Memeriksa pembaruan aplikasi...';
  Color _updateStatusColor = AppColors.textSecondary;

  @override
  void initState() {
    super.initState();
    _loadVersionAndUpdateStatus();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('saved_username');
      if (savedUser != null && savedUser.isNotEmpty) {
        if (mounted) {
          setState(() {
            _usernameCtrl.text = savedUser;
            _rememberMe = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadVersionAndUpdateStatus() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersionLabel =
              'Versi ${packageInfo.version} (build ${packageInfo.buildNumber})';
        });
      }
    } catch (_) {}

    try {
      final result = await _updateChecker.checkForUpdate();
      if (!mounted) return;

      setState(() {
        switch (result.status) {
          case AppUpdateStatus.updateAvailable:
            final latest = result.manifest;
            _updateStatusLabel = latest == null
                ? 'Update tersedia'
                : 'Update tersedia • Versi ${latest.version} (build ${latest.buildNumber})';
            _updateStatusColor = const Color(0xFFB45309);
            break;
          case AppUpdateStatus.failedCheck:
            _updateStatusLabel = 'Gagal memeriksa pembaruan';
            _updateStatusColor = AppColors.danger;
            break;
          case AppUpdateStatus.upToDate:
            _updateStatusLabel = 'Aplikasi sudah versi terbaru';
            _updateStatusColor = AppColors.textSecondary;
            break;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _updateStatusLabel = 'Gagal memeriksa pembaruan';
        _updateStatusColor = AppColors.danger;
      });
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _showWelcomeDialog(String userName) async {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width < 600
        ? size.width * 0.92
        : (size.width > 900 ? 380.0 : 340.0);

    return await AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: 'Login Berhasil!',
      desc: 'Selamat Datang ${userName.toUpperCase()}',
      width: dialogWidth,
      autoHide: const Duration(seconds: 1),
      onDismissCallback: (dismissType) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.dashboard,
          (route) => false,
        );
      },
    ).show();
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
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('saved_username', _usernameCtrl.text.trim());
        } else {
          await prefs.remove('saved_username');
        }
      } catch (_) {}
      
      final userName = (auth.user?['user_nama'] as String?) ?? 'User';
      _showWelcomeDialog(userName);
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
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: isDesktop
                  ? _buildDesktopLayout(context)
                  : _buildMobileLayout(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildHeroPanel(context, compact: false),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLoginCard(context),
              _buildFooterLink(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildHeroPanel(context, compact: true),
        Transform.translate(
          offset: const Offset(0, -22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildLoginCard(context),
          ),
        ),
        _buildFooterLink(),
      ],
    );
  }

  Widget _buildHeroPanel(BuildContext context, {required bool compact}) {
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.fromLTRB(24, compact ? 30 : 42, 24, compact ? 34 : 42),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: compact ? 56 : 64,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'PlanKP',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Masuk',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
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
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (val) {
                      setState(() {
                        _rememberMe = val ?? false;
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    activeColor: AppColors.primary,
                    side: const BorderSide(
                        color: AppColors.textSecondary, width: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _rememberMe = !_rememberMe;
                    });
                  },
                  child: const Text(
                    'Ingat Saya',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => ElevatedButton(
                onPressed: auth.loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
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
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Masuk',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _appVersionLabel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _updateStatusLabel,
              style: TextStyle(
                color: _updateStatusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
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
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: onToggle,
                color: AppColors.textSecondary,
              )
            : null,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
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
            child: const Text('Register',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_client.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/app_notifier.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _pageBg = Color(0xFFF8FAFC);
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _divisiCtrl = TextEditingController();
  final _divisiOptions = const [
    'GA',
    'IT',
    'Driver',
  ];
  String? _selectedCabang;
  List<Map<String, dynamic>> _pabrikList = [];
  bool _loadingPabrik = true;
  static const _defaultJabatan = 'user';
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadPabrik();
  }

  Future<void> _loadPabrik() async {
    try {
      final res = await ApiClient.get(ApiConfig.pabrik, auth: false);
      if (mounted) {
        setState(() {
          _pabrikList = List<Map<String, dynamic>>.from(
              (res['data'] as List).map((e) => e as Map<String, dynamic>));
          _loadingPabrik = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPabrik = false);
        AppNotifier.showError(context, 'Gagal memuat data cabang');
      }
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _passwordCtrl.dispose();
    _nikCtrl.dispose();
    _divisiCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      await AppNotifier.showWarning(
          context, 'Lengkapi data registrasi terlebih dahulu');
      return;
    }
    if (_selectedCabang == null) {
      await AppNotifier.showWarning(context, 'Pilih cabang terlebih dahulu');
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.loading) return;
    final ok = await auth.register(
      userNama: _namaCtrl.text.trim(),
      userPassword: _passwordCtrl.text,
      userDivisi: _divisiCtrl.text.trim(),
      userCabang: _selectedCabang!,
      userNik: _nikCtrl.text.trim(),
      userJabatan: _defaultJabatan,
    );
    if (ok && mounted) {
      await AppNotifier.showSuccess(context, 'Registrasi berhasil');
      if (!mounted) return;
      Navigator.pop(context);
    } else if (mounted) {
      final error = auth.error ?? 'Tidak dapat mendaftar saat ini';
      await AppNotifier.showError(context, error);
    }
  }

  void _backToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: isDesktop
                  ? Row(
                      children: [
                        Expanded(child: _buildHeroPanel(compact: false)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildFormCard()),
                      ],
                    )
                  : Column(
                      children: [
                        _buildHeroPanel(compact: true),
                        Transform.translate(
                          offset: const Offset(0, -22),
                          child: _buildFormCard(),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPanel({required bool compact}) {
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 18),
          const Text(
            'Buat Akun',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
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
              'Registrasi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _namaCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama User',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nikCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'NIK',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'NIK wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _divisiCtrl.text.isNotEmpty &&
                      _divisiOptions.contains(_divisiCtrl.text)
                  ? _divisiCtrl.text
                  : null,
              decoration: const InputDecoration(
                labelText: 'Divisi',
                prefixIcon: Icon(Icons.account_tree_outlined),
              ),
              items: _divisiOptions
                  .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  _divisiCtrl.text = val;
                }
              },
              validator: (v) =>
                  v == null || v.isEmpty ? 'Divisi wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            _loadingPabrik
                ? const SizedBox(
                    height: 56,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _selectedCabang,
                    decoration: const InputDecoration(
                      labelText: 'Cabang',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    items: _pabrikList
                        .map((pab) => DropdownMenuItem<String>(
                              value: pab['pab_kode'] as String,
                              child: Text(pab['pab_nama'] as String),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCabang = val);
                      }
                    },
                    validator: (v) => v == null ? 'Cabang wajib diisi' : null,
                  ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => v == null || v.length <= 2
                  ? 'Password minimal 3 karakter'
                  : null,
            ),
            const SizedBox(height: 24),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => ElevatedButton(
                onPressed: auth.loading ? null : _submit,
                child: auth.loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text('Daftar'),
              ),
            ),
            const SizedBox(height: 8),
            _buildFooterLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Sudah punya akun?'),
          TextButton(
            onPressed: _backToLogin,
            child: const Text(
              'Login',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/app_notifier.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _divisiCtrl = TextEditingController();
  final _divisiOptions = const [
    'Teknisi Jahit',
    'Teknisi Umum',
    'IT Support',
    'Satpam',
    'Kebersihan',
  ];
  final _cabangCtrl = TextEditingController();
  static const _defaultJabatan = 'user';
  bool _obscure = true;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _passwordCtrl.dispose();
    _nikCtrl.dispose();
    _divisiCtrl.dispose();
    _cabangCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (auth.loading) return;
    final ok = await auth.register(
      userNama: _namaCtrl.text.trim(),
      userPassword: _passwordCtrl.text,
      userDivisi: _divisiCtrl.text.trim(),
      userCabang: _cabangCtrl.text.trim(),
      userNik: _nikCtrl.text.trim(),
      userJabatan: _defaultJabatan,
    );
    if (ok && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      final error = auth.error ?? 'Tidak dapat mendaftar saat ini';
      await AppNotifier.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _namaCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Username wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nikCtrl,
                decoration: const InputDecoration(labelText: 'NIK'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'NIK wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _divisiOptions.contains(_divisiCtrl.text)
                    ? _divisiCtrl.text
                    : null,
                decoration: const InputDecoration(labelText: 'Divisi'),
                items: _divisiOptions
                    .map(
                        (opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) _divisiCtrl.text = val;
                },
                validator: (v) =>
                    v == null || v.isEmpty ? 'Divisi wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cabangCtrl,
                decoration: const InputDecoration(labelText: 'Cabang'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Cabang wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => v == null || v.length <= 2
                    ? 'Password minimal 2 karakter'
                    : null,
              ),
              const SizedBox(height: 24),
              Consumer<AuthProvider>(
                builder: (_, auth, __) => ElevatedButton(
                  onPressed: auth.loading ? null : _submit,
                  child: auth.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Daftar'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

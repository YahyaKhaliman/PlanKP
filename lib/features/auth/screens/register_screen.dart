import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

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
  bool _obscure = true;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _passwordCtrl.dispose();
    _nikCtrl.dispose();
    _divisiCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      userNama: _namaCtrl.text.trim(),
      userPassword: _passwordCtrl.text,
      userDivisi: _divisiCtrl.text.trim(),
      userNik: _nikCtrl.text.trim().isEmpty ? null : _nikCtrl.text.trim(),
    );
    if (ok && mounted) {
      Navigator.pop(context);
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
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _divisiCtrl,
                decoration: const InputDecoration(labelText: 'Divisi'),
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
                validator: (v) => v == null || v.length <= 3
                    ? 'Password minimal 3 karakter'
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

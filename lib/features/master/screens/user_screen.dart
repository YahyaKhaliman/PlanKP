import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../providers/master_provider.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});
  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  String? _filterJabatan;

  static const _jabatanList = [
    {'value': 'admin',      'label': 'Admin'},
    {'value': 'teknisi',    'label': 'Teknisi'},
    {'value': 'it_support', 'label': 'IT Support'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
      context.read<MasterProvider>().fetchUsers());
  }

  void _openForm([UserModel? user]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserForm(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola User')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.person_add_outlined),
      ),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _FilterChip(label: 'Semua', selected: _filterJabatan == null,
                onTap: () { setState(() => _filterJabatan = null);
                  context.read<MasterProvider>().fetchUsers(); }),
              ..._jabatanList.map((j) => _FilterChip(label: j['label']!, selected: _filterJabatan == j['value'],
                onTap: () { setState(() => _filterJabatan = j['value']);
                  context.read<MasterProvider>().fetchUsers(jabatan: j['value']); })),
            ],
          ),
        ),
        Expanded(
          child: Consumer<MasterProvider>(
            builder: (_, p, __) {
              if (p.loading) return const Center(child: CircularProgressIndicator());
              if (p.userList.isEmpty) return const Center(
                child: Text('Belum ada user', style: TextStyle(color: AppColors.textSecondary)));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: p.userList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final user = p.userList[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(user.userNama[0].toUpperCase(),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                      title: Text(user.userNama,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('NIK: ${user.userNik}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Row(children: [
                          _JabatanBadge(user.jabatanLabel),
                          if (user.userCabang != null) ...[
                            const SizedBox(width: 6),
                            Text(user.userCabang!,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ]),
                      ]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(value: user.aktif, onChanged: (_) => p.toggleUserAktif(user.userId),
                          activeColor: AppColors.primary),
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _openForm(user)),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _JabatanBadge extends StatelessWidget {
  final String label;
  const _JabatanBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary)),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          border: Border.all(color: selected ? AppColors.primary : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
          color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    ),
  );
}

class _UserForm extends StatefulWidget {
  final UserModel? user;
  const _UserForm({this.user});
  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _form = GlobalKey<FormState>();
  final _namaCtrl   = TextEditingController();
  final _nikCtrl    = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _cabangCtrl = TextEditingController();
  String _jabatan   = 'teknisi';
  bool _obscure     = true;

  static const _jabatanList = [
    {'value': 'admin',      'label': 'Admin'},
    {'value': 'teknisi',    'label': 'Teknisi'},
    {'value': 'it_support', 'label': 'IT Support'},
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    if (u != null) {
      _namaCtrl.text   = u.userNama;
      _nikCtrl.text    = u.userNik;
      _cabangCtrl.text = u.userCabang ?? '';
      _jabatan         = u.userJabatan;
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose(); _nikCtrl.dispose(); _passCtrl.dispose(); _cabangCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final p = context.read<MasterProvider>();
    final body = <String, dynamic>{
      'user_nama':    _namaCtrl.text.trim(),
      'user_nik':     _nikCtrl.text.trim(),
      'user_jabatan': _jabatan,
      'user_cabang':  _cabangCtrl.text.trim().isEmpty ? null : _cabangCtrl.text.trim(),
    };
    if (_passCtrl.text.isNotEmpty) body['user_password'] = _passCtrl.text;
    final ok = await p.saveUser(body, id: widget.user?.userId);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgGray,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _form,
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(isEdit ? 'Edit User' : 'Tambah User',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(controller: _namaCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person_outline)),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null),
              const SizedBox(height: 14),
              TextFormField(controller: _nikCtrl,
                decoration: const InputDecoration(labelText: 'NIK', prefixIcon: Icon(Icons.badge_outlined)),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'NIK wajib diisi' : null),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _jabatan,
                decoration: const InputDecoration(labelText: 'Jabatan', prefixIcon: Icon(Icons.work_outline)),
                items: _jabatanList.map((j) => DropdownMenuItem(value: j['value'], child: Text(j['label']!))).toList(),
                onChanged: (v) => setState(() => _jabatan = v!)),
              const SizedBox(height: 14),
              TextFormField(controller: _cabangCtrl,
                decoration: const InputDecoration(labelText: 'Cabang (opsional)',
                  prefixIcon: Icon(Icons.business_outlined), hintText: 'KP1, KP2...')),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: isEdit ? 'Password Baru (kosongkan jika tidak diubah)' : 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure))),
                validator: isEdit ? null : (v) {
                  if (v == null || v.isEmpty) return 'Password wajib diisi';
                  if (v.length < 6) return 'Minimal 6 karakter';
                  return null;
                }),
              const SizedBox(height: 24),
              Consumer<MasterProvider>(
                builder: (_, p, __) => ElevatedButton(
                  onPressed: p.loading ? null : _submit,
                  child: p.loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Simpan Perubahan' : 'Tambah User')),
              ),
            ],
          )),
        ),
      ),
    );
  }
}

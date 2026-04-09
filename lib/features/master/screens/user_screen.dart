import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/user_model.dart';
import '../providers/master_provider.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});
  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  static const _kPageBg = Color(0xFFF8FAFC);
  final Set<int> _togglingUserIds = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<MasterProvider>().fetchUsers());
    _searchCtrl
        .addListener(() => setState(() => _searchQuery = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openForm([UserModel? user]) async {
    await context.read<MasterProvider>().fetchPabrik();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _kPageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _UserForm(user: user),
      ),
    );
  }

  Future<void> _toggleUserStatus(MasterProvider p, UserModel user) async {
    final authUserId = _currentAuthUserId();
    if (authUserId != null && authUserId == user.userId) {
      await AppNotifier.showWarning(
        context,
        'Status akun sendiri tidak dapat diubah',
      );
      return;
    }

    if (_togglingUserIds.contains(user.userId)) return;
    setState(() => _togglingUserIds.add(user.userId));
    final ok = await p.toggleUserAktif(user.userId);
    if (!ok && mounted) {
      await AppNotifier.showError(
        context,
        p.error ?? 'Gagal mengubah status user',
      );
    }
    if (!mounted) return;
    setState(() => _togglingUserIds.remove(user.userId));
  }

  int? _currentAuthUserId() {
    final auth = context.read<AuthProvider>();
    final rawId = auth.user?['user_id'];
    if (rawId is int) return rawId;
    return int.tryParse('$rawId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(title: const Text('Kelola User')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Tambah User',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.person_add_outlined),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth =
              constraints.maxWidth > 1220 ? 1080.0 : constraints.maxWidth;
          return Center(
            child: SizedBox(
              width: maxContentWidth,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau NIK...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_outlined),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Consumer<MasterProvider>(
                    builder: (_, p, __) {
                      final authUserId = _currentAuthUserId();
                      if (p.loading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final filteredUsers = p.userList.where((user) {
                        final q = _searchQuery.toLowerCase();
                        return user.userNama.toLowerCase().contains(q) ||
                            user.userNik.toLowerCase().contains(q);
                      }).toList();
                      if (filteredUsers.isEmpty) {
                        return EmptyState(
                          message: _searchQuery.isEmpty
                              ? 'Belum ada user'
                              : 'User tidak ditemukan',
                          actionLabel: 'Tambah',
                          onAction: () => _openForm(),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: filteredUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final user = filteredUsers[i];
                          final isCurrentUser =
                              authUserId != null && authUserId == user.userId;
                          final isToggling =
                              _togglingUserIds.contains(user.userId);
                          return Container(
                            margin: EdgeInsets.zero,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.04)),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2)),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.1),
                                child: Text(user.userNama[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                              ),
                              title: Text(user.userNama,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('NIK: ${user.userNik}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                    Row(children: [
                                      _JabatanBadge(user.jabatanLabel),
                                      if (isCurrentUser) ...[
                                        const SizedBox(width: 6),
                                        const _SelfBadge(),
                                      ],
                                      const SizedBox(width: 6),
                                      _StatusBadge(isActive: user.aktif),
                                      if (user.userCabang != null) ...[
                                        const SizedBox(width: 6),
                                        Text(p.displayPabrik(user.userCabang),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSecondary)),
                                      ],
                                    ]),
                                  ]),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isCurrentUser)
                                      _MinimalSwitch(
                                        value: user.aktif,
                                        loading: isToggling,
                                        onChanged: () =>
                                            _toggleUserStatus(p, user),
                                      ),
                                    IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 18),
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
            ),
          );
        },
      ),
    );
  }
}

class _JabatanBadge extends StatelessWidget {
  final String label;
  const _JabatanBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.primary)),
      );
}

class _SelfBadge extends StatelessWidget {
  const _SelfBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Akun saya',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF92400E),
          ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? AppColors.primary.withValues(alpha: 0.08)
        : const Color(0xFFF1F5F9);
    final fg = isActive ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Nonaktif',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

class _MinimalSwitch extends StatelessWidget {
  final bool value;
  final bool loading;
  final VoidCallback onChanged;

  const _MinimalSwitch({
    required this.value,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        width: 46,
        height: 30,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Transform.scale(
      scale: 0.88,
      child: CupertinoSwitch(
        value: value,
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: const Color(0xFFD9E2EC),
        thumbColor: Colors.white,
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _UserForm extends StatefulWidget {
  final UserModel? user;
  const _UserForm({this.user});
  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _form = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _nikCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _cabang;
  String _jabatan = 'user';
  String? _divisi;
  bool _obscureOld = true;
  bool _obscureNew = true;

  static const _jabatanList = [
    {'value': 'admin', 'label': 'Admin'},
    {'value': 'user', 'label': 'User'},
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    if (u != null) {
      _namaCtrl.text = u.userNama;
      _nikCtrl.text = u.userNik;
      _cabang = u.userCabang;
      _jabatan = u.userJabatan;
      _divisi = u.userDivisi;
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _nikCtrl.dispose();
    _oldPassCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      await AppNotifier.showWarning(
          context, 'Lengkapi data user terlebih dahulu');
      return;
    }
    final p = context.read<MasterProvider>();
    final isEdit = widget.user != null;
    final body = <String, dynamic>{
      'user_nama': _namaCtrl.text.trim(),
      'user_nik': _nikCtrl.text.trim(),
      'user_jabatan': _jabatan,
      'user_divisi': _divisi,
      'user_cabang': _cabang,
    };
    if (_passCtrl.text.isNotEmpty) {
      body['user_password_lama'] = _oldPassCtrl.text;
      body['user_password'] = _passCtrl.text;
    }
    final ok = await p.saveUser(body, id: widget.user?.userId);
    if (ok && mounted) {
      await AppNotifier.showSuccess(context,
          isEdit ? 'User berhasil diperbarui' : 'User berhasil ditambahkan');
      if (!mounted) return;
      Navigator.pop(context);
    } else if (mounted) {
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan data user');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    final master = context.watch<MasterProvider>();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(isEdit ? 'Edit User' : 'Tambah User',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                  controller: _namaCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.person_outline)),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null),
              const SizedBox(height: 14),
              TextFormField(
                  controller: _nikCtrl,
                  decoration: const InputDecoration(
                      labelText: 'NIK', prefixIcon: Icon(Icons.badge_outlined)),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'NIK wajib diisi'
                      : null),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                  initialValue: _jabatan,
                  decoration: const InputDecoration(
                      labelText: 'Jabatan',
                      prefixIcon: Icon(Icons.work_outline)),
                  items: _jabatanList
                      .map((j) => DropdownMenuItem(
                          value: j['value'], child: Text(j['label']!)))
                      .toList(),
                  onChanged: (v) => setState(() => _jabatan = v!)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _divisi,
                decoration: const InputDecoration(
                    labelText: 'Divisi',
                    prefixIcon: Icon(Icons.account_tree_outlined)),
                items: UserModel.divisiList
                    .map(
                        (div) => DropdownMenuItem(value: div, child: Text(div)))
                    .toList(),
                onChanged: (v) => setState(() => _divisi = v),
                validator: (v) => v == null ? 'Divisi wajib dipilih' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _cabang,
                decoration: const InputDecoration(
                  labelText: 'Cabang',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                items: master.pabrikList
                    .map(
                      (pabrik) => DropdownMenuItem(
                        value: pabrik.pabKode,
                        child: Text(pabrik.displayLabel),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _cabang = v),
              ),
              const SizedBox(height: 14),
              if (isEdit) ...[
                TextFormField(
                    controller: _oldPassCtrl,
                    obscureText: _obscureOld,
                    decoration: InputDecoration(
                        labelText: 'Password Lama',
                        prefixIcon: const Icon(Icons.lock_clock_outlined),
                        suffixIcon: IconButton(
                            icon: Icon(_obscureOld
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _obscureOld = !_obscureOld))),
                    validator: (v) {
                      if (_passCtrl.text.isNotEmpty &&
                          (v == null || v.isEmpty)) {
                        return 'Password lama wajib diisi';
                      }
                      return null;
                    }),
                const SizedBox(height: 14),
              ],
              TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                      labelText: isEdit
                          ? 'Password Baru (kosongkan jika tidak diubah)'
                          : 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                          icon: Icon(_obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew))),
                  validator: isEdit
                      ? (v) {
                          if (v != null && v.isNotEmpty && v.length < 3) {
                            return 'Minimal 3 karakter';
                          }
                          if (v != null &&
                              v.isNotEmpty &&
                              _oldPassCtrl.text.isEmpty) {
                            return 'Isi password lama terlebih dahulu';
                          }
                          return null;
                        }
                      : (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password wajib diisi';
                          }
                          if (v.length < 3) return 'Minimal 3 karakter';
                          return null;
                        }),
              const SizedBox(height: 24),
              Consumer<MasterProvider>(
                builder: (_, p, __) => ElevatedButton(
                    onPressed: p.loading ? null : _submit,
                    child: p.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'Simpan Perubahan' : 'Tambah User')),
              ),
            ],
          )),
        ),
      ),
    );
  }
}

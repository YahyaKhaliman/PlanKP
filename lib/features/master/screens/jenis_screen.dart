import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/jenis_model.dart';
import '../providers/master_provider.dart';

class JenisScreen extends StatefulWidget {
  const JenisScreen({super.key});

  @override
  State<JenisScreen> createState() => _JenisScreenState();
}

class _JenisScreenState extends State<JenisScreen> {
  static const _kPageBg = Color(0xFFF8FAFC);
  final _searchCtrl = TextEditingController();

  Future<void> _toggleJenisStatus(JenisModel jenis, bool value) async {
    final provider = context.read<MasterProvider>();
    final ok = await provider.toggleJenisAktif(jenis.jenisId, value);
    if (!ok && mounted) {
      await AppNotifier.showError(
        context,
        provider.error ?? 'Gagal mengubah status jenis',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MasterProvider>().fetchJenis();
    });
  }

  void _openForm([JenisModel? jenis]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _kPageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _JenisForm(jenis: jenis),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(title: const Text('Jenis')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Tambah Jenis',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
      body: Consumer<MasterProvider>(
        builder: (_, p, __) {
          final query = _searchCtrl.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? p.jenisMaster
              : p.jenisMaster.where((j) {
                  final nama = j.jenisNama.toLowerCase();
                  final kategori = j.jenisKategori.toLowerCase();
                  return nama.contains(query) || kategori.contains(query);
                }).toList();

          if (p.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (p.jenisMaster.isEmpty) {
            return EmptyState(
              message: 'Belum ada master jenis',
              actionLabel: 'Tambah',
              onAction: () => _openForm(),
            );
          }
          return Column(
            children: [
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama atau kategori jenis...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(message: 'Data jenis tidak ditemukan')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final jenis = filtered[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                              title: Text(jenis.jenisNama,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(jenis.jenisKategori),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: jenis.jenisIsActive,
                                    onChanged: (value) =>
                                        _toggleJenisStatus(jenis, value),
                                    activeThumbColor: AppColors.primary,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: AppColors.textSecondary),
                                    onPressed: () => _openForm(jenis),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JenisForm extends StatefulWidget {
  final JenisModel? jenis;
  const _JenisForm({this.jenis});

  @override
  State<_JenisForm> createState() => _JenisFormState();
}

class _JenisFormState extends State<_JenisForm> {
  final _form = GlobalKey<FormState>();
  String _kategori = '';

  // Edit mode: single field
  final _namaCtrl = TextEditingController();

  // Create mode: multiple fields
  final List<TextEditingController> _namaCtrls = [];

  bool get _isEdit => widget.jenis != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _namaCtrl.text = widget.jenis!.jenisNama;
      _kategori = widget.jenis!.jenisKategori;
    } else {
      _namaCtrls.add(TextEditingController());
      final auth = context.read<AuthProvider>();
      _kategori = (auth.user?['user_divisi'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    for (final c in _namaCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addField() => setState(() => _namaCtrls.add(TextEditingController()));

  void _removeField(int index) {
    setState(() {
      _namaCtrls[index].dispose();
      _namaCtrls.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final provider = context.read<MasterProvider>();

    if (_isEdit) {
      if (!_form.currentState!.validate()) return;
      final ok = await provider.saveJenis(
        {'jenis_nama': _namaCtrl.text.trim(), 'jenis_kategori': _kategori},
        id: widget.jenis!.jenisId,
      );
      if (ok && mounted) {
        await AppNotifier.showSuccess(context, 'Jenis berhasil diperbarui');
        if (!mounted) return;
        Navigator.pop(context);
      } else if (mounted) {
        await AppNotifier.showError(
            context, provider.error ?? 'Gagal menyimpan jenis');
      }
      return;
    }

    // Create mode: submit all non-empty fields
    final valid = _namaCtrls.where((c) => c.text.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      await AppNotifier.showWarning(context, 'Isi minimal satu nama jenis');
      return;
    }
    int count = 0;
    for (final ctrl in valid) {
      final ok = await provider.saveJenis({
        'jenis_nama': ctrl.text.trim(),
        'jenis_kategori': _kategori,
      });
      if (ok) count++;
    }
    if (!mounted) return;
    if (count > 0) {
      await AppNotifier.showSuccess(
          context, '$count jenis berhasil ditambahkan');
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      await AppNotifier.showError(
          context, provider.error ?? 'Gagal menyimpan jenis');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                )),
                Row(
                  children: [
                    Text(_isEdit ? 'Edit Jenis' : 'Tambah Jenis',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (_kategori.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_kategori,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_isEdit)
                  TextFormField(
                    controller: _namaCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nama Jenis',
                      prefixIcon: Icon(Icons.label_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  )
                else ...[
                  ..._namaCtrls.asMap().entries.map((e) {
                    final i = e.key;
                    final ctrl = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: ctrl,
                              autofocus: i == 0,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: 'Nama jenis ${i + 1}',
                                prefixIcon:
                                    const Icon(Icons.label_outlined, size: 20),
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_namaCtrls.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red, size: 20),
                              onPressed: () => _removeField(i),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: _addField,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tambah baris'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Consumer<MasterProvider>(
                  builder: (_, p, __) => ElevatedButton(
                    onPressed: p.loading ? null : _submit,
                    child: p.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(_isEdit ? 'Simpan' : 'Tambah Semua'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

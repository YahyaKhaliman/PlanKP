import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        child: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
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
                                  color: Colors.black.withOpacity(0.04)),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
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
                                    onChanged: (value) => context
                                        .read<MasterProvider>()
                                        .saveJenis({
                                      'jenis_is_active': value,
                                    }, id: jenis.jenisId),
                                    activeColor: AppColors.primary,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: AppColors.textSecondary),
                                    onPressed: () => _openForm(jenis),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppColors.danger),
                                    onPressed: () async {
                                      await AppNotifier.showConfirm(
                                        context,
                                        title: 'Hapus Jenis',
                                        message:
                                            'Hapus jenis ${jenis.jenisNama}?',
                                        onConfirm: () => context
                                            .read<MasterProvider>()
                                            .deleteJenis(jenis.jenisId),
                                      );
                                    },
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
  final _namaCtrl = TextEditingController();
  String _kategori = 'Mesin Jahit';

  static const _kategoriList = [
    'Mesin Jahit',
    'Mesin Umum',
    'Hardware',
    'APAR'
  ];

  @override
  void initState() {
    super.initState();
    final jenis = widget.jenis;
    if (jenis != null) {
      _namaCtrl.text = jenis.jenisNama;
      _kategori = jenis.jenisKategori;
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      await AppNotifier.showWarning(
          context, 'Lengkapi data jenis terlebih dahulu');
      return;
    }
    final isEdit = widget.jenis != null;
    final body = {
      'jenis_nama': _namaCtrl.text.trim(),
      'jenis_kategori': _kategori,
    };
    final provider = context.read<MasterProvider>();
    final ok = await provider.saveJenis(body, id: widget.jenis?.jenisId);
    if (ok && mounted) {
      await AppNotifier.showSuccess(context,
          isEdit ? 'Jenis berhasil diperbarui' : 'Jenis berhasil ditambahkan');
      if (!mounted) return;
      Navigator.pop(context);
    } else if (mounted) {
      await AppNotifier.showError(
          context, provider.error ?? 'Gagal menyimpan master jenis');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.jenis != null;
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
                Text(isEdit ? 'Edit Jenis' : 'Tambah Jenis',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _namaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Jenis',
                    prefixIcon: Icon(Icons.label_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _kategori,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _kategoriList
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setState(() => _kategori = v!),
                ),
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
                        : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Jenis'),
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

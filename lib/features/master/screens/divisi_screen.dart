import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../providers/master_provider.dart';
import '../models/divisi_model.dart';

class DivisiScreen extends StatefulWidget {
  const DivisiScreen({super.key});
  @override
  State<DivisiScreen> createState() => _DivisiScreenState();
}

class _DivisiScreenState extends State<DivisiScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
      context.read<MasterProvider>().fetchDivisi());
  }

  void _showForm({DivisiModel? item}) {
    final kodeCtrl = TextEditingController(text: item?.divisiKode);
    final namaCtrl = TextEditingController(text: item?.divisiNama);
    final formKey  = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item == null ? 'Tambah Divisi' : 'Edit Divisi',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                controller: kodeCtrl,
                decoration: const InputDecoration(labelText: 'Kode Divisi'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: namaCtrl,
                decoration: const InputDecoration(labelText: 'Nama Divisi'),
                validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 24),
              Consumer<MasterProvider>(
                builder: (_, prov, __) => ElevatedButton(
                  onPressed: prov.loading ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    final ok = await prov.saveDivisi(
                      {'divisi_kode': kodeCtrl.text.toUpperCase(), 'divisi_nama': namaCtrl.text},
                      id: item?.divisiId,
                    );
                    if (ok && ctx.mounted) Navigator.pop(ctx);
                  },
                  child: prov.loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Master Divisi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Consumer<MasterProvider>(
        builder: (_, prov, __) {
          if (prov.loading) return const Center(child: CircularProgressIndicator());
          if (prov.divisiList.isEmpty) return EmptyState(message: 'Belum ada divisi', actionLabel: 'Tambah', onAction: () => _showForm());
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: prov.divisiList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = prov.divisiList[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(d.divisiKode, style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(d.divisiNama, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Kode: ${d.divisiKode}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.accent), onPressed: () => _showForm(item: d)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () async {
                          final ok = await showConfirmDialog(context, title: 'Hapus Divisi', message: 'Hapus divisi ${d.divisiNama}?');
                          if (ok && context.mounted) context.read<MasterProvider>().deleteDivisi(d.divisiId);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
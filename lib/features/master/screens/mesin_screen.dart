import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/master_provider.dart';
import '../models/mesin_model.dart';

class MesinScreen extends StatefulWidget {
  const MesinScreen({super.key});
  @override
  State<MesinScreen> createState() => _MesinScreenState();
}

class _MesinScreenState extends State<MesinScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MasterProvider>().fetchMesin();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showForm({MesinModel? item}) {
    final noInvCtrl = TextEditingController(text: item?.mesinNoInventaris);
    final namaCtrl = TextEditingController(text: item?.mesinNama);
    final jenisCtrl = TextEditingController(
        text: item == null ? '' : item.mesinJenisId.toString());
    final lokasiCtrl = TextEditingController(text: item?.mesinLokasi);
    final notesCtrl = TextEditingController(text: item?.mesinNotes);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item == null ? 'Tambah Mesin' : 'Edit Mesin',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: noInvCtrl,
                  decoration:
                      const InputDecoration(labelText: 'No. Inventaris'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: namaCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Mesin'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: jenisCtrl,
                  decoration: const InputDecoration(
                      labelText: 'ID Jenis Mesin (opsional)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lokasiCtrl,
                  decoration: const InputDecoration(labelText: 'Lokasi'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Catatan (opsional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Consumer<MasterProvider>(
                  builder: (_, p, __) => ElevatedButton(
                    onPressed: p.loading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            final ok = await p.saveMesin({
                              'mesin_no_inventaris': noInvCtrl.text,
                              'mesin_nama': namaCtrl.text,
                              'mesin_jenis_id': int.tryParse(jenisCtrl.text),
                              'mesin_lokasi': lokasiCtrl.text,
                              'mesin_notes': notesCtrl.text.isEmpty
                                  ? null
                                  : notesCtrl.text,
                            }, id: item?.mesinId);
                            if (ok && ctx.mounted) Navigator.pop(ctx);
                          },
                    child: p.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Mesin')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Consumer<MasterProvider>(
        builder: (_, prov, __) {
          if (prov.loading && prov.mesinList.isEmpty)
            return const Center(child: CircularProgressIndicator());
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Cari mesin...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: Builder(builder: (_) {
                  final q = _searchCtrl.text.toLowerCase();
                  final list = q.isEmpty
                      ? prov.mesinList
                      : prov.mesinList
                          .where((m) =>
                              m.mesinNama.toLowerCase().contains(q) ||
                              m.mesinNoInventaris.toLowerCase().contains(q))
                          .toList();
                  if (list.isEmpty)
                    return const EmptyState(
                        message: 'Tidak ada mesin ditemukan');
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m = list[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: m.isActive
                                ? AppColors.success
                                : AppColors.textSecondary,
                            child: Icon(Icons.settings,
                                color: AppColors.white, size: 20),
                          ),
                          title: Text(m.mesinNama,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle:
                              Text('${m.mesinNoInventaris} • ${m.mesinLokasi}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AppColors.accent),
                                  onPressed: () => _showForm(item: m)),
                              IconButton(
                                icon: Icon(
                                    m.isActive
                                        ? Icons.toggle_on
                                        : Icons.toggle_off,
                                    color: m.isActive
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    size: 28),
                                onPressed: () =>
                                    prov.toggleMesinAktif(m.mesinId),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

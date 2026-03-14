import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/inventaris_model.dart';
import '../providers/master_provider.dart';

class InventarisScreen extends StatefulWidget {
  const InventarisScreen({super.key});
  @override
  State<InventarisScreen> createState() => _InventarisScreenState();
}

class _InventarisScreenState extends State<InventarisScreen> {
  final _search = TextEditingController();
  String? _filterKategori;

  static const _kategoriList = ['Mesin', 'Hardware', 'APAR', 'Lainnya'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<MasterProvider>().fetchInventaris());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openForm([InventarisModel? item]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InventarisForm(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventaris')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search + filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Cari nama inventaris...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => context
                      .read<MasterProvider>()
                      .fetchInventaris(q: v.isEmpty ? null : v),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _filterKategori,
                hint: const Text('Semua'),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  ..._kategoriList
                      .map((k) => DropdownMenuItem(value: k, child: Text(k))),
                ],
                onChanged: (v) {
                  setState(() => _filterKategori = v);
                  context.read<MasterProvider>().fetchInventaris(kategori: v);
                },
              ),
            ]),
          ),

          // List
          Expanded(
            child: Consumer<MasterProvider>(
              builder: (_, p, __) {
                if (p.loading)
                  return const Center(child: CircularProgressIndicator());
                if (p.inventarisList.isEmpty)
                  return const Center(
                      child: Text('Belum ada data inventaris',
                          style: TextStyle(color: AppColors.textSecondary)));

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: p.inventarisList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = p.inventarisList[i];
                    return _InventarisCard(
                      item: item,
                      onTap: () => _openForm(item),
                      onToggle: () => p.toggleInventarisAktif(item.invId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InventarisCard extends StatelessWidget {
  final InventarisModel item;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  const _InventarisCard(
      {required this.item, required this.onTap, required this.onToggle});

  static const _kondisiColor = {
    'Baik': AppColors.success,
    'Perlu Perhatian': Colors.orange,
    'Rusak': AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Icon kategori
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_kategoriIcon(item.invKategori),
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(item.invNama,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          (_kondisiColor[item.invKondisi] ?? AppColors.success)
                              .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(item.invKondisi,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _kondisiColor[item.invKondisi] ??
                                AppColors.success)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text('${item.invNo} · ${item.invJenis}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                if (item.invLokasi != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Text(item.invLokasi!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ],
              ],
            )),
            const SizedBox(width: 8),

            // Toggle aktif
            Switch(
              value: item.aktif,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.primary,
            ),
          ]),
        ),
      ),
    );
  }

  IconData _kategoriIcon(String k) {
    switch (k) {
      case 'Mesin':
        return Icons.precision_manufacturing_outlined;
      case 'Hardware':
        return Icons.computer_outlined;
      case 'APAR':
        return Icons.fire_extinguisher_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}

// ── Form tambah / edit ──────────────────────────────────────────
class _InventarisForm extends StatefulWidget {
  final InventarisModel? item;
  const _InventarisForm({this.item});
  @override
  State<_InventarisForm> createState() => _InventarisFormState();
}

class _InventarisFormState extends State<_InventarisForm> {
  final _form = GlobalKey<FormState>();
  final _noCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _jenisCtrl = TextEditingController();
  final _lokasiCtrl = TextEditingController();
  final _merkCtrl = TextEditingController();
  final _snCtrl = TextEditingController();
  final _picCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _kategori = 'Mesin';
  String _kondisi = 'Baik';

  static const _kategoriList = ['Mesin', 'Hardware', 'APAR', 'Lainnya'];
  static const _kondisiList = ['Baik', 'Perlu Perhatian', 'Rusak'];

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    if (d != null) {
      _noCtrl.text = d.invNo;
      _namaCtrl.text = d.invNama;
      _jenisCtrl.text = d.invJenis;
      _lokasiCtrl.text = d.invLokasi ?? '';
      _merkCtrl.text = d.invMerk ?? '';
      _snCtrl.text = d.invSerialNumber ?? '';
      _picCtrl.text = d.invPic ?? '';
      _notesCtrl.text = d.invNotes ?? '';
      _kategori = d.invKategori;
      _kondisi = d.invKondisi;
    }
  }

  @override
  void dispose() {
    _noCtrl.dispose();
    _namaCtrl.dispose();
    _jenisCtrl.dispose();
    _lokasiCtrl.dispose();
    _merkCtrl.dispose();
    _snCtrl.dispose();
    _picCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final p = context.read<MasterProvider>();
    final body = {
      'inv_no': _noCtrl.text.trim(),
      'inv_nama': _namaCtrl.text.trim(),
      'inv_kategori': _kategori,
      'inv_jenis': _jenisCtrl.text.trim(),
      'inv_lokasi':
          _lokasiCtrl.text.trim().isEmpty ? null : _lokasiCtrl.text.trim(),
      'inv_merk': _merkCtrl.text.trim().isEmpty ? null : _merkCtrl.text.trim(),
      'inv_serial_number':
          _snCtrl.text.trim().isEmpty ? null : _snCtrl.text.trim(),
      'inv_pic': _picCtrl.text.trim().isEmpty ? null : _picCtrl.text.trim(),
      'inv_kondisi': _kondisi,
      'inv_notes':
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };
    final ok = await p.saveInventaris(body, id: widget.item?.invId);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgGray,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _form,
          child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isEdit ? 'Edit Inventaris' : 'Tambah Inventaris',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                _field(_noCtrl, 'No. Inventaris', Icons.tag, required: true),
                _field(_namaCtrl, 'Nama', Icons.inventory_2_outlined,
                    required: true),

                // Kategori
                DropdownButtonFormField<String>(
                  value: _kategori,
                  decoration: const InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: Icon(Icons.category_outlined)),
                  items: _kategoriList
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setState(() => _kategori = v!),
                ),
                const SizedBox(height: 14),

                _field(_jenisCtrl, 'Jenis', Icons.label_outline,
                    required: true, hint: 'Sewing, Kompressor, Laptop...'),
                _field(_lokasiCtrl, 'Lokasi', Icons.location_on_outlined),
                _field(_merkCtrl, 'Merk', Icons.branding_watermark_outlined),
                _field(_snCtrl, 'Serial Number', Icons.qr_code_outlined),
                _field(_picCtrl, 'PIC', Icons.person_outline),

                // Kondisi
                DropdownButtonFormField<String>(
                  value: _kondisi,
                  decoration: const InputDecoration(
                      labelText: 'Kondisi',
                      prefixIcon: Icon(Icons.health_and_safety_outlined)),
                  items: _kondisiList
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => setState(() => _kondisi = v!),
                ),
                const SizedBox(height: 14),

                _field(_notesCtrl, 'Catatan', Icons.notes_outlined,
                    maxLines: 3),
                const SizedBox(height: 24),

                Consumer<MasterProvider>(
                  builder: (_, p, __) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (p.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(p.error!,
                                style: const TextStyle(
                                    color: AppColors.danger, fontSize: 13)),
                          ),
                        ElevatedButton(
                          onPressed: p.loading ? null : _submit,
                          child: p.loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text(isEdit ? 'Simpan Perubahan' : 'Tambah'),
                        ),
                      ],
                    );
                  },
                ),
              ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon),
            alignLabelWithHint: maxLines > 1),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null
            : null,
      ),
    );
  }
}

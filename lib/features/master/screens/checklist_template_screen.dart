import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/checklist_template_model.dart';
import '../providers/master_provider.dart';

class ChecklistTemplateScreen extends StatefulWidget {
  const ChecklistTemplateScreen({super.key});
  @override
  State<ChecklistTemplateScreen> createState() => _ChecklistTemplateScreenState();
}

class _ChecklistTemplateScreenState extends State<ChecklistTemplateScreen> {
  String? _filterJenis;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
      context.read<MasterProvider>().fetchChecklist());
  }

  // Ambil daftar jenis unik dari data yang ada
  List<String> _getJenisList(List<ChecklistTemplateModel> list) =>
    list.map((e) => e.ctInvJenis).toSet().toList()..sort();

  void _openForm([ChecklistTemplateModel? item]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChecklistForm(item: item),
    );
  }

  void _confirmDelete(ChecklistTemplateModel item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Item'),
        content: Text('Hapus "${item.ctItem}" dari checklist ${item.ctInvJenis}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              context.read<MasterProvider>().deleteChecklist(item.ctId);
              Navigator.pop(context);
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Template Checklist')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Consumer<MasterProvider>(
        builder: (_, p, __) {
          if (p.loading) return const Center(child: CircularProgressIndicator());

          final jenisList = _getJenisList(p.checklistList);
          final filtered  = _filterJenis == null
            ? p.checklistList
            : p.checklistList.where((e) => e.ctInvJenis == _filterJenis).toList();

          return Column(children: [
            // Filter chip per jenis
            if (jenisList.isNotEmpty) SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _FilterChip(label: 'Semua', selected: _filterJenis == null,
                    onTap: () { setState(() => _filterJenis = null); p.fetchChecklist(); }),
                  ...jenisList.map((j) => _FilterChip(label: j, selected: _filterJenis == j,
                    onTap: () { setState(() => _filterJenis = j); p.fetchChecklist(jenis: j); })),
                ],
              ),
            ),

            if (filtered.isEmpty) const Expanded(
              child: Center(child: Text('Belum ada item checklist', style: TextStyle(color: AppColors.textSecondary)))),

            if (filtered.isNotEmpty) Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text('${item.ctUrutan}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary))),
                      ),
                      title: Text(item.ctItem, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.ctInvJenis, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                          if (item.ctKeterangan != null)
                            Text(item.ctKeterangan!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _openForm(item)),
                        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                          onPressed: () => _confirmDelete(item)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary)),
        ),
      ),
    );
  }
}

// ── Form ───────────────────────────────────────────────────────
class _ChecklistForm extends StatefulWidget {
  final ChecklistTemplateModel? item;
  const _ChecklistForm({this.item});
  @override
  State<_ChecklistForm> createState() => _ChecklistFormState();
}

class _ChecklistFormState extends State<_ChecklistForm> {
  final _form        = GlobalKey<FormState>();
  final _jenisCtrl   = TextEditingController();
  final _itemCtrl    = TextEditingController();
  final _ketCtrl     = TextEditingController();
  final _urutanCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    if (d != null) {
      _jenisCtrl.text  = d.ctInvJenis;
      _itemCtrl.text   = d.ctItem;
      _ketCtrl.text    = d.ctKeterangan ?? '';
      _urutanCtrl.text = d.ctUrutan.toString();
    } else {
      _urutanCtrl.text = '1';
    }
  }

  @override
  void dispose() {
    _jenisCtrl.dispose(); _itemCtrl.dispose(); _ketCtrl.dispose(); _urutanCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final p = context.read<MasterProvider>();
    final body = {
      'ct_inv_jenis':  _jenisCtrl.text.trim(),
      'ct_item':       _itemCtrl.text.trim(),
      'ct_keterangan': _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
      'ct_urutan':     int.tryParse(_urutanCtrl.text) ?? 1,
    };
    final ok = await p.saveChecklist(body, id: widget.item?.ctId);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
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
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(isEdit ? 'Edit Item Checklist' : 'Tambah Item Checklist',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            TextFormField(
              controller: _jenisCtrl,
              decoration: const InputDecoration(labelText: 'Jenis Inventaris', prefixIcon: Icon(Icons.label_outline),
                hintText: 'Sewing, Kompressor, Laptop...'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Jenis wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _itemCtrl,
              decoration: const InputDecoration(labelText: 'Item Checklist', prefixIcon: Icon(Icons.checklist_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Item wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ketCtrl,
              decoration: const InputDecoration(labelText: 'Keterangan (opsional)', prefixIcon: Icon(Icons.notes_outlined)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _urutanCtrl,
              decoration: const InputDecoration(labelText: 'Urutan', prefixIcon: Icon(Icons.sort_outlined)),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || int.tryParse(v) == null) ? 'Urutan harus angka' : null,
            ),
            const SizedBox(height: 24),

            Consumer<MasterProvider>(
              builder: (_, p, __) => ElevatedButton(
                onPressed: p.loading ? null : _submit,
                child: p.loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'Simpan Perubahan' : 'Tambah'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

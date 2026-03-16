import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/checklist_template_model.dart';
import '../providers/master_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  CHECKLIST TEMPLATE SCREEN
// ═══════════════════════════════════════════════════════════════
class ChecklistTemplateScreen extends StatefulWidget {
  const ChecklistTemplateScreen({super.key});
  @override
  State<ChecklistTemplateScreen> createState() =>
      _ChecklistTemplateScreenState();
}

class _ChecklistTemplateScreenState extends State<ChecklistTemplateScreen> {
  String? _filterJenis;
  bool _previewMode = false; // false = list biasa, true = preview per jenis

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<MasterProvider>();
      p.fetchChecklist();
      p.fetchJenis();
    });
  }

  // daftar jenis unik dari data checklist yang sudah ada
  List<String> _jenisDariChecklist(List<ChecklistTemplateModel> list) =>
      list.map((e) => e.ctInvJenis).toSet().toList()..sort();

  // ── buka form single item ──────────────────────────────────
  void _openSingleForm([ChecklistTemplateModel? item]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SingleItemForm(item: item),
    );
  }

  // ── buka form bulk input ───────────────────────────────────
  void _openBulkForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BulkInputForm(),
    );
  }

  // ── konfirmasi hapus ───────────────────────────────────────
  void _confirmDelete(ChecklistTemplateModel item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Item'),
        content: Text('Hapus "${item.ctItem}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          TextButton(
              onPressed: () {
                context.read<MasterProvider>().deleteChecklist(item.ctId);
                Navigator.pop(context);
              },
              child: const Text('Hapus',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
  }

  // ── reorder: geser item ke atas ───────────────────────────
  Future<void> _moveUp(List<ChecklistTemplateModel> items, int index) async {
    if (index == 0) return;
    final orders = items
        .asMap()
        .entries
        .map((e) => {'ct_id': e.value.ctId, 'ct_urutan': e.key + 1})
        .toList();
    final int tmp = orders[index]['ct_urutan'] ?? 0;
    orders[index]['ct_urutan'] = orders[index - 1]['ct_urutan'] ?? 0;
    orders[index - 1]['ct_urutan'] = tmp;
    await context
        .read<MasterProvider>()
        .reorderChecklist(orders.cast<Map<String, dynamic>>());
  }

  // ── reorder: geser item ke bawah ──────────────────────────
  Future<void> _moveDown(List<ChecklistTemplateModel> items, int index) async {
    if (index == items.length - 1) return;
    final orders = items
        .asMap()
        .entries
        .map((e) => {'ct_id': e.value.ctId, 'ct_urutan': e.key + 1})
        .toList();
    final int tmp = orders[index]['ct_urutan'] ?? 0;
    orders[index]['ct_urutan'] = orders[index + 1]['ct_urutan'] ?? 0;
    orders[index + 1]['ct_urutan'] = tmp;
    await context
        .read<MasterProvider>()
        .reorderChecklist(orders.cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Checklist'),
        actions: [
          // Toggle preview/list mode
          IconButton(
            icon: Icon(_previewMode
                ? Icons.view_list_outlined
                : Icons.grid_view_outlined),
            tooltip: _previewMode ? 'Mode List' : 'Mode Preview',
            onPressed: () => setState(() => _previewMode = !_previewMode),
          ),
        ],
      ),

      // ── FAB: bulk input saja ───────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_bulk',
        onPressed: _openBulkForm,
        icon: const Icon(Icons.playlist_add),
        label: const Text('Bulk Input'),
      ),

      body: Consumer<MasterProvider>(
        builder: (_, p, __) {
          if (p.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final jenisDariData = _jenisDariChecklist(p.checklistList);
          final filtered = _filterJenis == null
              ? p.checklistList
              : p.checklistList
                  .where((e) => e.ctInvJenis == _filterJenis)
                  .toList();

          return Column(children: [
            // ── Filter chip ──────────────────────────────────
            Container(
              color: AppColors.white,
              child: Column(children: [
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    children: [
                      _Chip(
                        label: 'Semua',
                        selected: _filterJenis == null,
                        onTap: () {
                          setState(() => _filterJenis = null);
                          p.fetchChecklist();
                        },
                      ),
                      ...jenisDariData.map((j) => _Chip(
                            label: j,
                            selected: _filterJenis == j,
                            onTap: () {
                              setState(() => _filterJenis = j);
                              p.fetchChecklist(jenis: j);
                            },
                          )),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ]),
            ),

            // ── Counter ──────────────────────────────────────
            if (filtered.isNotEmpty)
              Container(
                color: AppColors.bgGray,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(children: [
                  Text('${filtered.length} item',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  if (_filterJenis != null) ...[
                    const Text(' · ',
                        style: TextStyle(color: AppColors.textSecondary)),
                    Text(_filterJenis!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500)),
                  ],
                ]),
              ),

            // ── Empty state ──────────────────────────────────
            if (filtered.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checklist_outlined,
                          size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 12),
                      Text('Belum ada item checklist',
                          style: TextStyle(color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text('Gunakan tombol Bulk Input untuk menambahkan',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),

            // ── PREVIEW MODE: card per jenis ─────────────────
            if (filtered.isNotEmpty && _previewMode)
              Expanded(
                child: _buildPreviewMode(filtered, p),
              ),

            // ── LIST MODE: list dengan reorder ───────────────
            if (filtered.isNotEmpty && !_previewMode)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _ItemCard(
                    item: filtered[i],
                    index: i,
                    total: filtered.length,
                    onEdit: () => _openSingleForm(filtered[i]),
                    onDelete: () => _confirmDelete(filtered[i]),
                    onMoveUp: () => _moveUp(filtered, i),
                    onMoveDown: () => _moveDown(filtered, i),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }

  // ── Preview Mode: dikelompokkan per jenis ─────────────────
  Widget _buildPreviewMode(
      List<ChecklistTemplateModel> items, MasterProvider p) {
    // kelompokkan per jenis
    final Map<String, List<ChecklistTemplateModel>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.ctInvJenis, () => []).add(item);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: grouped.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final jenis = grouped.keys.elementAt(i);
        final list = grouped[jenis]!
          ..sort((a, b) => a.ctUrutan.compareTo(b.ctUrutan));

        return Card(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header jenis
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(children: [
                  const Icon(Icons.label_outline,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(jenis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.primary)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${list.length} item',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary)),
                  ),
                ]),
              ),
              // daftar item
              ...list.asMap().entries.map((e) {
                final idx = e.key;
                final item = e.value;
                return Container(
                  decoration: BoxDecoration(
                    border: idx < list.length - 1
                        ? const Border(
                            bottom:
                                BorderSide(color: AppColors.border, width: 0.5))
                        : null,
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.bgGray,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text('${item.ctUrutan}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                      ),
                    ),
                    title:
                        Text(item.ctItem, style: const TextStyle(fontSize: 13)),
                    subtitle: item.ctKeterangan != null
                        ? Text(item.ctKeterangan!,
                            style: const TextStyle(fontSize: 11))
                        : null,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 16, color: AppColors.textSecondary),
                        onPressed: () => _openSingleForm(item),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: AppColors.danger),
                        onPressed: () => _confirmDelete(item),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ]),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ITEM CARD (list mode dengan reorder)
// ═══════════════════════════════════════════════════════════════
class _ItemCard extends StatelessWidget {
  final ChecklistTemplateModel item;
  final int index;
  final int total;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _ItemCard({
    required this.item,
    required this.index,
    required this.total,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(children: [
          // nomor urut
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('${item.ctUrutan}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 12),

          // info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.ctItem,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(item.ctInvJenis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary)),
                ),
                if (item.ctKeterangan != null) ...[
                  const SizedBox(height: 3),
                  Text(item.ctKeterangan!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),

          // actions: reorder + edit + delete
          Column(mainAxisSize: MainAxisSize.min, children: [
            // ↑ naik
            SizedBox(
              width: 32,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.keyboard_arrow_up_rounded,
                    size: 20,
                    color: index == 0
                        ? AppColors.border
                        : AppColors.textSecondary),
                onPressed: index == 0 ? null : onMoveUp,
              ),
            ),
            // ↓ turun
            SizedBox(
              width: 32,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: index == total - 1
                        ? AppColors.border
                        : AppColors.textSecondary),
                onPressed: index == total - 1 ? null : onMoveDown,
              ),
            ),
          ]),
          const SizedBox(width: 2),
          Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 32,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.textSecondary),
                onPressed: onEdit,
              ),
            ),
            SizedBox(
              width: 32,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.danger),
                onPressed: onDelete,
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SINGLE ITEM FORM
// ═══════════════════════════════════════════════════════════════
class _SingleItemForm extends StatefulWidget {
  final ChecklistTemplateModel? item;
  const _SingleItemForm({this.item});
  @override
  State<_SingleItemForm> createState() => _SingleItemFormState();
}

class _SingleItemFormState extends State<_SingleItemForm> {
  final _form = GlobalKey<FormState>();
  final _itemCtrl = TextEditingController();
  final _ketCtrl = TextEditingController();
  final _urutanCtrl = TextEditingController();
  String? _selectedJenis;

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    if (d != null) {
      _selectedJenis = d.ctInvJenis;
      _itemCtrl.text = d.ctItem;
      _ketCtrl.text = d.ctKeterangan ?? '';
      _urutanCtrl.text = '${d.ctUrutan}';
    } else {
      _urutanCtrl.text = '1';
    }
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _ketCtrl.dispose();
    _urutanCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final p = context.read<MasterProvider>();
    final body = {
      'ct_inv_jenis': _selectedJenis!,
      'ct_item': _itemCtrl.text.trim(),
      'ct_keterangan':
          _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
      'ct_urutan': int.tryParse(_urutanCtrl.text) ?? 1,
    };
    final ok = await p.saveChecklist(body, id: widget.item?.ctId);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final provider = context.watch<MasterProvider>();
    final allJenis = provider.jenisChecklist;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgGray,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                Text(isEdit ? 'Edit Item' : 'Tambah Item',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                // Dropdown jenis
                DropdownButtonFormField<String>(
                  value: _selectedJenis,
                  decoration: const InputDecoration(
                    labelText: 'Jenis Inventaris',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  hint: const Text('Pilih jenis inventaris'),
                  items: allJenis
                      .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedJenis = v),
                  validator: (v) => v == null ? 'Jenis wajib dipilih' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _itemCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item Checklist',
                    prefixIcon: Icon(Icons.checklist_outlined),
                    hintText: 'Cek kondisi oli, Cek V-belt...',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Item wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _ketCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (opsional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _urutanCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Urutan',
                    prefixIcon: Icon(Icons.sort_outlined),
                  ),
                  validator: (v) => (v == null || int.tryParse(v) == null)
                      ? 'Urutan harus angka'
                      : null,
                ),
                const SizedBox(height: 24),

                _ErrorBox(provider.error),
                Consumer<MasterProvider>(
                  builder: (_, p, __) => ElevatedButton(
                    onPressed: p.loading ? null : _submit,
                    child: p.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Item'),
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

// ═══════════════════════════════════════════════════════════════
//  BULK INPUT FORM
// ═══════════════════════════════════════════════════════════════
class _BulkInputForm extends StatefulWidget {
  const _BulkInputForm();
  @override
  State<_BulkInputForm> createState() => _BulkInputFormState();
}

class _BulkInputFormState extends State<_BulkInputForm> {
  String? _selectedJenis;
  // list controller per baris
  final List<TextEditingController> _itemCtrls = [TextEditingController()];
  final List<TextEditingController> _ketCtrls = [TextEditingController()];

  @override
  void dispose() {
    for (final c in _itemCtrls) c.dispose();
    for (final c in _ketCtrls) c.dispose();
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _itemCtrls.add(TextEditingController());
      _ketCtrls.add(TextEditingController());
    });
  }

  void _removeRow(int i) {
    if (_itemCtrls.length == 1) return;
    setState(() {
      _itemCtrls[i].dispose();
      _ketCtrls[i].dispose();
      _itemCtrls.removeAt(i);
      _ketCtrls.removeAt(i);
    });
  }

  Future<void> _submit() async {
    if (_selectedJenis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih jenis inventaris dahulu')));
      return;
    }
    final items = <Map<String, dynamic>>[];
    for (int i = 0; i < _itemCtrls.length; i++) {
      final item = _itemCtrls[i].text.trim();
      if (item.isEmpty) continue;
      items.add({
        'ct_item': item,
        'ct_keterangan':
            _ketCtrls[i].text.trim().isEmpty ? null : _ketCtrls[i].text.trim(),
      });
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Isi minimal 1 item')));
      return;
    }
    final p = context.read<MasterProvider>();
    final ok = await p.bulkCreateChecklist(_selectedJenis!, items);
    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${items.length} item berhasil ditambahkan'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MasterProvider>();
    final allJenis = provider.jenisChecklist;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgGray,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // ── header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                )),
                const Text('Bulk Input Checklist',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Tambahkan banyak item sekaligus untuk 1 jenis',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),

                // dropdown jenis
                DropdownButtonFormField<String>(
                  value: _selectedJenis,
                  decoration: const InputDecoration(
                    labelText: 'Jenis Inventaris',
                    prefixIcon: Icon(Icons.label_outline),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  hint: const Text('Pilih jenis inventaris'),
                  items: allJenis
                      .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedJenis = v),
                ),
                const SizedBox(height: 12),

                // label kolom
                Row(children: const [
                  SizedBox(width: 32),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Text('Item Checklist *',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text('Keterangan',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                  ),
                  SizedBox(width: 36),
                ]),
                const SizedBox(height: 6),
              ],
            ),
          ),

          // ── scrollable rows ─────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              itemCount: _itemCtrls.length + 1, // +1 tombol tambah baris
              itemBuilder: (_, i) {
                // tombol tambah baris di akhir
                if (i == _itemCtrls.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Tambah Baris'),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    // nomor
                    Container(
                      width: 32,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // item
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _itemCtrls[i],
                        decoration: InputDecoration(
                          hintText: 'Item ${i + 1}',
                          filled: true,
                          fillColor: AppColors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // keterangan
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ketCtrls[i],
                        decoration: InputDecoration(
                          hintText: 'Opsional',
                          filled: true,
                          fillColor: AppColors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ),
                    // hapus baris
                    SizedBox(
                      width: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.remove_circle_outline,
                          size: 18,
                          color: _itemCtrls.length == 1
                              ? AppColors.border
                              : AppColors.danger,
                        ),
                        onPressed:
                            _itemCtrls.length == 1 ? null : () => _removeRow(i),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),

          // ── footer tombol simpan ─────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            decoration: const BoxDecoration(
              color: AppColors.bgGray,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(children: [
              _ErrorBox(provider.error),
              Consumer<MasterProvider>(
                builder: (_, p, __) => ElevatedButton.icon(
                  onPressed: p.loading ? null : _submit,
                  icon: p.loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(p.loading
                      ? 'Menyimpan...'
                      : 'Simpan ${_itemCtrls.length} Item'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.white,
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  final String? error;
  const _ErrorBox(this.error);
  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13))),
      ]),
    );
  }
}

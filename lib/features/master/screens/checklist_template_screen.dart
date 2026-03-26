import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/checklist_template_model.dart';
import '../models/jenis_model.dart';
import '../providers/master_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  CHECKLIST TEMPLATE SCREEN
// ═══════════════════════════════════════════════════════════════
class ChecklistTemplateScreen extends StatefulWidget {
  final int initialTabIndex;

  const ChecklistTemplateScreen({
    super.key,
    this.initialTabIndex = 0,
  });
  @override
  State<ChecklistTemplateScreen> createState() =>
      _ChecklistTemplateScreenState();
}

class _ChecklistTemplateScreenState extends State<ChecklistTemplateScreen> {
  String? _filterJenis;
  int _tabIndex = 0; // 0 = Checklist, 1 = Master Jenis

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<MasterProvider>();
      p.fetchChecklist();
      p.fetchJenis();
    });
  }

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
  void _openBulkForm(
      [String? jenisLocked, List<ChecklistTemplateModel>? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulkInputForm(
        initialJenis: jenisLocked,
        jenisLocked: jenisLocked != null,
        existingItems: existing,
      ),
    );
  }

  // ── konfirmasi hapus ───────────────────────────────────────
  Future<void> _confirmDelete(ChecklistTemplateModel item) async {
    await AppNotifier.showConfirm(
      context,
      title: 'Hapus Item',
      message: 'Hapus "${item.ctItem}"?',
      onConfirm: () {
        context.read<MasterProvider>().deleteChecklist(item.ctId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: _tabIndex,
      child: Builder(builder: (context) {
        final tabController = DefaultTabController.of(context);
        tabController.addListener(() {
          if (tabController.indexIsChanging) {
            setState(() => _tabIndex = tabController.index);
          }
        });
        return Scaffold(
          appBar: AppBar(
            title: const Text('Template Checklist'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Checklist'),
                Tab(text: 'Master Jenis'),
              ],
            ),
          ),
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _ChecklistTab(
                filterJenis: _filterJenis,
                onFilterChanged: (val) => setState(() => _filterJenis = val),
                openBulkForm: _openBulkForm,
                openSingleForm: _openSingleForm,
                confirmDelete: _confirmDelete,
              ),
              const _JenisTab(),
            ],
          ),
          floatingActionButton: _tabIndex == 0
              ? FloatingActionButton.extended(
                  heroTag: 'fab_bulk',
                  onPressed: _openBulkForm,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Bulk Input'),
                )
              : FloatingActionButton.extended(
                  heroTag: 'fab_jenis',
                  onPressed: _openJenisForm,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Jenis'),
                ),
        );
      }),
    );
  }

  void _openJenisForm([JenisModel? jenis]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JenisForm(jenis: jenis),
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
      _selectedJenis = d.ctJenisId.toString();
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
    if (!_form.currentState!.validate()) {
      await AppNotifier.showWarning(
          context, 'Lengkapi data item checklist dahulu');
      return;
    }
    final p = context.read<MasterProvider>();
    final isEdit = widget.item != null;
    final body = {
      'ct_inv_jenis': _selectedJenis!,
      'ct_item': _itemCtrl.text.trim(),
      'ct_keterangan':
          _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
      'ct_urutan': int.tryParse(_urutanCtrl.text) ?? 1,
    };
    final ok = await p.saveChecklist(body, id: widget.item?.ctId);
    if (ok && mounted) {
      await AppNotifier.showSuccess(
          context,
          isEdit
              ? 'Item checklist berhasil diperbarui'
              : 'Item checklist berhasil ditambahkan');
      if (!mounted) return;
      Navigator.pop(context);
    } else if (mounted) {
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan item checklist');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final provider = context.watch<MasterProvider>();
    final allJenis = provider.jenisMaster;

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
                      .map((j) => DropdownMenuItem(
                          value: '${j.jenisId}', child: Text(j.jenisNama)))
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
  final String? initialJenis;
  final bool jenisLocked;
  final List<ChecklistTemplateModel>? existingItems;
  const _BulkInputForm({
    this.initialJenis,
    this.jenisLocked = false,
    this.existingItems,
  });
  @override
  State<_BulkInputForm> createState() => _BulkInputFormState();
}

class _BulkInputFormState extends State<_BulkInputForm> {
  String? _selectedJenis;
  // list controller per baris
  final List<TextEditingController> _itemCtrls = [TextEditingController()];
  final List<TextEditingController> _ketCtrls = [TextEditingController()];
  final List<ChecklistTemplateModel> _existing = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialJenis != null) {
      _selectedJenis = widget.initialJenis;
    }
    if (widget.existingItems != null && widget.existingItems!.isNotEmpty) {
      _existing.addAll(widget.existingItems!);
    }
  }

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
      if (widget.jenisLocked && widget.initialJenis != null) {
        _selectedJenis = widget.initialJenis;
      } else {
        await AppNotifier.showWarning(context, 'Pilih jenis inventaris dahulu');
        return;
      }
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
      await AppNotifier.showWarning(context, 'Isi minimal 1 item');
      return;
    }
    final p = context.read<MasterProvider>();
    final ok = await p.bulkCreateChecklist(_selectedJenis!, items);
    if (ok && mounted) {
      Navigator.pop(context);
      await AppNotifier.showSuccess(
        context,
        '${items.length} item berhasil ditambahkan',
      );
    } else if (mounted) {
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menambahkan item checklist');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MasterProvider>();
    final allJenis = provider.jenisMaster;

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
                if (_existing.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Checklist tersimpan (${_existing.length} item)',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 8),
                        ..._existing.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.bgGray,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                      child: Text('${item.ctUrutan}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600))),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(item.ctItem,
                                        style: const TextStyle(fontSize: 12))),
                              ]),
                            )),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // dropdown jenis
                DropdownButtonFormField<String>(
                  value: widget.jenisLocked
                      ? (widget.initialJenis ?? _selectedJenis)
                      : _selectedJenis,
                  decoration: const InputDecoration(
                    labelText: 'Jenis Inventaris',
                    prefixIcon: Icon(Icons.label_outline),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  hint: const Text('Pilih jenis inventaris'),
                  items: allJenis
                      .map((j) => DropdownMenuItem(
                          value: '${j.jenisId}', child: Text(j.jenisNama)))
                      .toList(),
                  onChanged: widget.jenisLocked
                      ? null
                      : (v) => setState(() => _selectedJenis = v),
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
//  CHECKLIST TAB
// ═══════════════════════════════════════════════════════════════
class _ChecklistTab extends StatelessWidget {
  final String? filterJenis;
  final ValueChanged<String?> onFilterChanged;
  final void Function([String?, List<ChecklistTemplateModel>?]) openBulkForm;
  final void Function([ChecklistTemplateModel?]) openSingleForm;
  final void Function(ChecklistTemplateModel) confirmDelete;

  const _ChecklistTab({
    required this.filterJenis,
    required this.onFilterChanged,
    required this.openBulkForm,
    required this.openSingleForm,
    required this.confirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MasterProvider>(
      builder: (_, p, __) {
        final jenisMaster = p.jenisMaster;
        final filtered = filterJenis == null
            ? p.checklistList
            : p.checklistList
                .where((e) => e.ctJenisId.toString() == filterJenis)
                .toList();

        return Column(children: [
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
                      selected: filterJenis == null,
                      onTap: () {
                        onFilterChanged(null);
                        p.fetchChecklist();
                      },
                    ),
                    ...jenisMaster.map((j) => _Chip(
                          label: j.jenisNama,
                          selected: filterJenis == '${j.jenisId}',
                          onTap: () {
                            onFilterChanged('${j.jenisId}');
                            p.fetchChecklist(jenis: '${j.jenisId}');
                          },
                        )),
                  ],
                ),
              ),
              const Divider(height: 1),
            ]),
          ),
          if (filtered.isNotEmpty)
            Container(
              color: AppColors.bgGray,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(children: [
                Text('${filtered.length} item',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                if (filterJenis != null) ...[
                  const Text(' · ',
                      style: TextStyle(color: AppColors.textSecondary)),
                  Text(filterJenis!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500)),
                ],
              ]),
            ),
          if (filtered.isEmpty)
            Expanded(
              child: EmptyState(
                message: 'Belum ada item checklist',
                actionLabel: 'Bulk Input',
                onAction: () => openBulkForm(filterJenis),
              ),
            ),
          if (filtered.isNotEmpty)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: _buildGroupedCards(filtered),
              ),
            ),
        ]);
      },
    );
  }

  List<Widget> _buildGroupedCards(List<ChecklistTemplateModel> filtered) {
    final Map<int, List<ChecklistTemplateModel>> grouped = {};
    for (final item in filtered) {
      grouped.putIfAbsent(item.ctJenisId, () => []).add(item);
    }
    return grouped.entries.map((entry) {
      final jenisId = entry.key;
      final list = entry.value
        ..sort((a, b) => a.ctUrutan.compareTo(b.ctUrutan));
      final jenisLabel = list.first.ctJenisNama ?? 'Jenis ID $jenisId';
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          key: PageStorageKey('jenis_$jenisId'),
          initiallyExpanded: grouped.length == 1,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          maintainState: true,
          title: Row(children: [
            const Icon(Icons.label_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(jenisLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.primary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${list.length} item',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary)),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => openBulkForm('$jenisId', list),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.add, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Tambah',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ]),
              ),
            ),
          ]),
          children: list
              .map((item) => ListTile(
                    key: ValueKey(item.ctId),
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.bgGray,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${item.ctUrutan}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ),
                    ),
                    title: Text(item.ctItem,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: item.ctKeterangan != null
                        ? Text(item.ctKeterangan!,
                            style: const TextStyle(fontSize: 12))
                        : null,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.textSecondary),
                        onPressed: () => openSingleForm(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.danger),
                        onPressed: () => confirmDelete(item),
                      ),
                    ]),
                  ))
              .toList(),
        ),
      );
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════════
//  MASTER JENIS TAB
// ═══════════════════════════════════════════════════════════════
class _JenisTab extends StatelessWidget {
  const _JenisTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<MasterProvider>(
      builder: (_, p, __) {
        if (p.jenisMaster.isEmpty) {
          return const EmptyState(message: 'Belum ada master jenis');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: p.jenisMaster.length,
          itemBuilder: (_, i) {
            final jenis = p.jenisMaster[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(jenis.jenisNama,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(jenis.jenisKategori),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: jenis.jenisIsActive,
                      onChanged: (value) =>
                          context.read<MasterProvider>().saveJenis({
                        'jenis_is_active': value,
                      }, id: jenis.jenisId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AppColors.textSecondary),
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _JenisForm(jenis: jenis),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.danger),
                      onPressed: () => context
                          .read<MasterProvider>()
                          .deleteJenis(jenis.jenisId),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
          color: AppColors.bgGray,
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

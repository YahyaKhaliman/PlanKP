import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/inventaris_model.dart';
import '../models/jenis_model.dart';
import '../providers/master_provider.dart';
import '../widgets/jenis_lookup_sheet.dart';

class InventarisScreen extends StatefulWidget {
  const InventarisScreen({super.key});
  @override
  State<InventarisScreen> createState() => _InventarisScreenState();
}

class _InventarisScreenState extends State<InventarisScreen> {
  static const _kPageBg = Color(0xFFF8FAFC);
  final _search = TextEditingController();
  final Set<int> _expandedJenisIds = <int>{};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<MasterProvider>().fetchInventaris());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      context
          .read<MasterProvider>()
          .fetchInventaris(q: value.trim().isEmpty ? null : value.trim());
    });
  }

  Future<void> _openForm([InventarisModel? item]) async {
    final provider = context.read<MasterProvider>();
    await provider.fetchJenis(showLoading: false);
    await provider.fetchPabrik();
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
        child: _InventarisForm(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(title: const Text('Inventaris')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Tambah Inventaris',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
      body: Consumer<MasterProvider>(
        builder: (_, p, __) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxContentWidth = constraints.maxWidth > 1024
                  ? 980.0
                  : constraints.maxWidth > 760
                      ? 760.0
                      : constraints.maxWidth;

              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: maxContentWidth,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              hintText: 'Cari nama inventaris...',
                              prefixIcon: Icon(Icons.search, size: 20),
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                      ),
                      Expanded(
                        child: () {
                          if (p.loading) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (p.inventarisList.isEmpty) {
                            return EmptyState(
                              message: 'Belum ada data inventaris',
                              actionLabel: 'Tambah',
                              onAction: () => _openForm(),
                            );
                          }
                          final grouped = <int, List<InventarisModel>>{};
                          for (final item in p.inventarisList) {
                            grouped
                                .putIfAbsent(
                                    item.invJenisId, () => <InventarisModel>[])
                                .add(item);
                          }
                          final jenisIds = grouped.keys.toList()..sort();

                          return ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: jenisIds.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final jenisId = jenisIds[i];
                              final items = grouped[jenisId]!;
                              final firstItem = items.first;
                              final jenisNama =
                                  p.jenisById(jenisId)?.jenisNama ??
                                      'Jenis #$jenisId';
                              final kategoriLabel =
                                  p.kategoriByJenisId(jenisId) ??
                                      firstItem.invKategori;
                              final expanded =
                                  _expandedJenisIds.contains(jenisId);

                              return _InventarisGroupCard(
                                jenisId: jenisId,
                                jenisNama: jenisNama,
                                kategoriLabel: kategoriLabel,
                                items: items,
                                expanded: expanded,
                                onToggle: () {
                                  setState(() {
                                    if (expanded) {
                                      _expandedJenisIds.remove(jenisId);
                                    } else {
                                      _expandedJenisIds.add(jenisId);
                                    }
                                  });
                                },
                                pabrikLabelBuilder: p.displayPabrik,
                                onEditItem: _openForm,
                              );
                            },
                          );
                        }(),
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

class _InventarisGroupCard extends StatelessWidget {
  final int jenisId;
  final String jenisNama;
  final String kategoriLabel;
  final List<InventarisModel> items;
  final bool expanded;
  final VoidCallback onToggle;
  final String Function(String?) pabrikLabelBuilder;
  final ValueChanged<InventarisModel> onEditItem;

  const _InventarisGroupCard({
    required this.jenisId,
    required this.jenisNama,
    required this.kategoriLabel,
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.pabrikLabelBuilder,
    required this.onEditItem,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _kategoriIcon(kategoriLabel),
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jenisNama,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                kategoriLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${items.length} inventaris',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: const Icon(
                      Icons.expand_more,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Column(
                      children: [
                        const Divider(height: 1),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(10),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final item = items[i];
                            return _InventarisCard(
                              item: item,
                              kategoriLabel: kategoriLabel,
                              pabrikLabel:
                                  pabrikLabelBuilder(item.invPabrikKode),
                              onEdit: () => onEditItem(item),
                            );
                          },
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _kategoriIcon(String k) {
    switch (k.toUpperCase()) {
      case 'IT':
        return Icons.computer_outlined;
      case 'DRIVER':
        return Icons.local_shipping_outlined;
      case 'GA':
        return Icons.precision_manufacturing_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}

class _InventarisCard extends StatelessWidget {
  final InventarisModel item;
  final String kategoriLabel;
  final String pabrikLabel;
  final VoidCallback onEdit;
  const _InventarisCard({
    required this.item,
    required this.kategoriLabel,
    required this.pabrikLabel,
    required this.onEdit,
  });

  static const _kondisiColor = {
    'Baik': AppColors.success,
    'Perlu Perhatian': Colors.orange,
    'Rusak': AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Icon kategori
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _kategoriIcon(kategoriLabel),
              color: AppColors.primary,
              size: 22,
            ),
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
                            fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (_kondisiColor[item.invKondisi] ?? AppColors.success)
                        .withValues(alpha: 0.12),
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
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      kategoriLabel,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.invNo,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              if (item.invPabrikKode != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text(pabrikLabel,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ]),
              ],
            ],
          )),
          const SizedBox(width: 8),

          IconButton(
            icon:
                const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            onPressed: onEdit,
          ),
        ]),
      ),
    );
  }

  IconData _kategoriIcon(String k) {
    switch (k.toUpperCase()) {
      case 'IT':
        return Icons.computer_outlined;
      case 'DRIVER':
        return Icons.local_shipping_outlined;
      case 'GA':
        return Icons.precision_manufacturing_outlined;
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
  int? _jenisId;
  String? _pabrikKode;
  final _merkCtrl = TextEditingController();
  final _snCtrl = TextEditingController();
  final _picCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _kategori = '';
  String _kondisi = 'Baik';

  static const _kondisiList = ['Baik', 'Perlu Perhatian', 'Rusak'];

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    if (d != null) {
      _noCtrl.text = d.invNo;
      _namaCtrl.text = d.invNama;
      _jenisId = d.invJenisId;
      final jenis = context.read<MasterProvider>().jenisById(d.invJenisId);
      _jenisCtrl.text = jenis?.jenisNama ?? 'ID ${d.invJenisId}';
      _pabrikKode = d.invPabrikKode;
      _merkCtrl.text = d.invMerk ?? '';
      _snCtrl.text = d.invSerialNumber ?? '';
      _picCtrl.text = d.invPic ?? '';
      _notesCtrl.text = d.invNotes ?? '';
      final mappedKategori =
          context.read<MasterProvider>().kategoriByJenisId(d.invJenisId);
      _kategori = (mappedKategori ?? d.invKategori).trim();
      _kondisi = d.invKondisi;
    }
  }

  @override
  void dispose() {
    _noCtrl.dispose();
    _namaCtrl.dispose();
    _jenisCtrl.dispose();
    _merkCtrl.dispose();
    _snCtrl.dispose();
    _picCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      await AppNotifier.showWarning(context, 'Lengkapi data inventaris dahulu');
      return;
    }
    if (_kategori.trim().isEmpty) {
      await AppNotifier.showWarning(
          context, 'Kategori otomatis belum terdeteksi dari jenis inventaris');
      return;
    }
    final p = context.read<MasterProvider>();
    final isEdit = widget.item != null;
    final body = {
      'inv_no': _noCtrl.text.trim(),
      'inv_nama': _namaCtrl.text.trim(),
      'inv_jenis_id': _jenisId,
      'inv_pabrik_kode': _pabrikKode,
      'inv_merk': _merkCtrl.text.trim().isEmpty ? null : _merkCtrl.text.trim(),
      'inv_serial_number':
          _snCtrl.text.trim().isEmpty ? null : _snCtrl.text.trim(),
      'inv_pic': _picCtrl.text.trim().isEmpty ? null : _picCtrl.text.trim(),
      'inv_kondisi': _kondisi,
      'inv_notes':
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };
    final ok = await p.saveInventaris(body, id: widget.item?.invId);
    if (ok && mounted) {
      await AppNotifier.showSuccess(
          context,
          isEdit
              ? 'Inventaris berhasil diperbarui'
              : 'Inventaris berhasil ditambahkan');
      if (!mounted) return;
      Navigator.pop(context);
    } else if (mounted) {
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan data inventaris');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final master = context.watch<MasterProvider>();
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

                _jenisPickerField(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    initialValue: _pabrikKode,
                    decoration: const InputDecoration(
                      labelText: 'Lokasi / Pabrik',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: master.pabrikList
                        .map(
                          (pabrik) => DropdownMenuItem(
                            value: pabrik.pabKode,
                            child: Text(pabrik.displayLabel),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _pabrikKode = value),
                  ),
                ),
                _field(_merkCtrl, 'Merk', Icons.branding_watermark_outlined),
                _field(_snCtrl, 'Serial Number', Icons.qr_code_outlined),
                _field(_picCtrl, 'PIC', Icons.person_outline,
                    hint: 'Masukkan nama PIC'),

                // Kondisi
                DropdownButtonFormField<String>(
                  initialValue: _kondisi,
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

  Widget _jenisPickerField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _jenisCtrl,
            readOnly: true,
            decoration: InputDecoration(
              label: RichText(
                text: const TextSpan(
                  text: 'Jenis',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  children: [
                    TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red, fontSize: 14)),
                  ],
                ),
              ),
              hintText: 'Cari...',
              prefixIcon: const Icon(Icons.label_outline),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _pickJenis,
              ),
            ),
            validator: (_) => _jenisId == null ? 'Jenis wajib dipilih' : null,
            onTap: _pickJenis,
          ),
          if (_kategori.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Row(
                children: [
                  const Icon(Icons.category_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Kategori: $_kategori',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickJenis() async {
    final provider = context.read<MasterProvider>();
    if (provider.jenisMaster.isEmpty) {
      await provider.fetchJenis(showLoading: false);
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<JenisModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JenisLookupSheet(
        items: provider.jenisMaster,
        initialId: _jenisId,
      ),
    );
    if (result != null) {
      setState(() {
        _jenisId = result.jenisId;
        _jenisCtrl.text = result.jenisNama;
        _kategori = result.jenisKategori.trim();
      });
    }
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
            label: required
                ? RichText(
                    text: TextSpan(
                      text: label,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                      children: const [
                        TextSpan(
                            text: ' *',
                            style: TextStyle(color: Colors.red, fontSize: 14)),
                      ],
                    ),
                  )
                : null,
            labelText: required ? null : label,
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

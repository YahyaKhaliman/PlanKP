import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_loading.dart';
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

  Future<void> _openForm([InventarisModel? item, int? initialJenisId]) async {
    final provider = context.read<MasterProvider>();
    await provider.fetchJenis(showLoading: false);
    await provider.fetchJenisWithInventaris(showLoading: false);
    await provider.fetchPabrik();
    if (!mounted) return;

    if (item == null && initialJenisId == null) {
      final availableJenis = provider.jenisAvailableForInventaris();
      if (availableJenis.isEmpty) {
        await AppNotifier.showWarning(
          context,
          'Semua jenis sudah memiliki inventaris.\nKlik tombol Tambah untuk menambah inventaris.',
        );
        return;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _kPageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _InventarisForm(item: item, initialJenisId: initialJenisId),
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _search,
                            decoration: InputDecoration(
                              hintText: 'Cari nama inventaris...',
                              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                      ),
                      if (!p.loading && p.inventarisList.isNotEmpty)
                        Container(
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Row(children: [
                            Text(
                              '${p.inventarisList.map((e) => e.invJenisId).toSet().length} jenis · ${p.inventarisList.length} inventaris',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            if (_search.text.isNotEmpty)
                              const Text(' · hasil pencarian',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                          ]),
                        ),
                      Expanded(
                        child: () {
                          if (p.loading) {
                            return const AppShimmer(
                              child: SingleChildScrollView(
                                physics: NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.only(top: 8),
                                child: Column(
                                  children: [
                                    AppSkeletonFolderCard(),
                                    AppSkeletonFolderCard(),
                                    AppSkeletonFolderCard(),
                                  ],
                                ),
                              ),
                            );
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
                                onAddItem: (jId) => _openForm(null, jId),
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

class _InventarisGroupCard extends StatefulWidget {
  final int jenisId;
  final String jenisNama;
  final String kategoriLabel;
  final List<InventarisModel> items;
  final bool expanded;
  final VoidCallback onToggle;
  final String Function(String?) pabrikLabelBuilder;
  final ValueChanged<InventarisModel> onEditItem;
  final ValueChanged<int> onAddItem;

  const _InventarisGroupCard({
    required this.jenisId,
    required this.jenisNama,
    required this.kategoriLabel,
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.pabrikLabelBuilder,
    required this.onEditItem,
    required this.onAddItem,
  });

  @override
  State<_InventarisGroupCard> createState() => _InventarisGroupCardState();
}

class _InventarisGroupCardState extends State<_InventarisGroupCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconTurns;

  static final Animatable<double> _iconTurnTween =
      Tween<double>(begin: 0.0, end: 0.5)
          .chain(CurveTween(curve: Curves.easeIn));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = _controller.drive(_iconTurnTween);
    if (widget.expanded) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_InventarisGroupCard old) {
    super.didUpdateWidget(old);
    if (old.expanded != widget.expanded) {
      widget.expanded ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder_open_rounded,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.jenisNama,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.kategoriLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.items.length} item',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => widget.onAddItem(widget.jenisId),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Tambah',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: _iconTurns,
                    child: const Icon(
                      Icons.expand_more_rounded,
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
              child: widget.expanded
                  ? Column(
                      children: [
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 4),
                        ...widget.items.map(
                          (item) => _InventarisCard(
                            item: item,
                            pabrikLabel:
                                widget.pabrikLabelBuilder(item.invPabrikKode),
                            onEdit: () => widget.onEditItem(item),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventarisCard extends StatelessWidget {
  final InventarisModel item;
  final String pabrikLabel;
  final VoidCallback onEdit;
  const _InventarisCard({
    required this.item,
    required this.pabrikLabel,
    required this.onEdit,
  });



  Color _kategoriColor(String k) {
    switch (k.toUpperCase()) {
      case 'IT':
        return const Color(0xFF10B981);
      case 'DRIVER':
        return const Color(0xFF3B82F6);
      case 'GA':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final merkRaw = item.invMerk?.trim() ?? '';
    final picRaw = item.invPic?.trim() ?? '';
    final merk = merkRaw.isEmpty ? '-' : merkRaw;
    final pic = picRaw.isEmpty ? '-' : picRaw;

    Color badgeBg;
    Color badgeText;
    if (item.invKondisi.contains('Rusak')) {
      badgeBg = AppColors.danger.withValues(alpha: 0.08);
      badgeText = AppColors.danger;
    } else if (item.invKondisi.contains('Perhatian')) {
      badgeBg = AppColors.warning.withValues(alpha: 0.08);
      badgeText = AppColors.warning;
    } else {
      badgeBg = AppColors.success.withValues(alpha: 0.08);
      badgeText = AppColors.success;
    }

    final categoryIcon = _kategoriIcon(item.invKategori);
    final categoryColor = _kategoriColor(item.invKategori);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcon, size: 20, color: categoryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.invNama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'No: ${item.invNo}${item.invPabrikKode != null ? ' · $pabrikLabel' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Merk: $merk · PIC: $pic',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.invKondisi.contains('Sering') ? 'Baik (Sering)' : (item.invKondisi.contains('Jarang') ? 'Baik (Jarang)' : item.invKondisi),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: badgeText,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                onPressed: onEdit,
              ),
            ],
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

// ── Form tambah / edit ──────────────────────────────────────────
class _InventarisForm extends StatefulWidget {
  final InventarisModel? item;
  final int? initialJenisId;
  const _InventarisForm({this.item, this.initialJenisId});
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
  String _kondisi = 'Baik (Sering digunakan)';

  static const _kondisiList = [
    'Baik (Sering digunakan)',
    'Baik (Jarang digunakan)',
    'Perlu Perhatian',
    'Rusak'
  ];

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
    } else if (widget.initialJenisId != null) {
      final jenis =
          context.read<MasterProvider>().jenisById(widget.initialJenisId!);
      if (jenis != null) {
        _jenisId = jenis.jenisId;
        _jenisCtrl.text = jenis.jenisNama;
        _kategori = jenis.jenisKategori.trim();
      }
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
    if (_jenisId == null) {
      await AppNotifier.showWarning(context, 'Jenis inventaris wajib dipilih');
      return;
    }
    final master = context.read<MasterProvider>();
    if (!master.isJenisActive(_jenisId!)) {
      await AppNotifier.showWarning(
        context,
        'Jenis inventaris nonaktif. Pilih jenis yang aktif.',
      );
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
    final pabrikCodes = master.pabrikList.map((e) => e.pabKode).toSet();
    final safePabrikKode =
        (_pabrikKode != null && pabrikCodes.contains(_pabrikKode))
            ? _pabrikKode
            : null;
    final safeKondisi =
        _kondisiList.contains(_kondisi) ? _kondisi : _kondisiList.first;
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
                    initialValue: safePabrikKode,
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
                  initialValue: safeKondisi,
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
            validator: (_) {
              if (_jenisId == null) return 'Jenis wajib dipilih';
              final master = context.read<MasterProvider>();
              if (!master.isJenisActive(_jenisId!)) {
                return 'Jenis inventaris nonaktif';
              }
              return null;
            },
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
    await provider.fetchJenisWithInventaris(showLoading: false);
    if (!mounted) return;

    final allowedItems = provider.jenisAvailableForInventaris(
      includeJenisId: _jenisId ?? widget.initialJenisId,
    );
    if (allowedItems.isEmpty) {
      await AppNotifier.showWarning(
        context,
        'Tidak ada jenis yang tersedia untuk dipilih.',
      );
      return;
    }

    final result = await showModalBottomSheet<JenisModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JenisLookupSheet(
        items: allowedItems,
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

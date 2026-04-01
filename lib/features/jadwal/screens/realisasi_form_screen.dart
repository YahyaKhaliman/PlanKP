import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_notifier.dart';
import '../models/checklist_hasil_model.dart';
import '../providers/jadwal_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  REALISASI FORM SCREEN
//  args: { jadwalId, invJenis, invId?, invNama? }
// ═══════════════════════════════════════════════════════════════
class RealisasiFormScreen extends StatefulWidget {
  final Map<String, dynamic> args;
  const RealisasiFormScreen({super.key, required this.args});
  @override
  State<RealisasiFormScreen> createState() => _RealisasiFormScreenState();
}

class _RealisasiFormScreenState extends State<RealisasiFormScreen> {
  final _ketCtrl = TextEditingController();
  String _kondisi = 'Baik';
  List<ChecklistInputModel> _checklistItems = [];
  bool _loadingTemplate = true;
  bool _submitting = false;
  String? _invNo;
  String? _invMerk;
  String? _invKondisiAwal;
  String? _invPicNama;

  static const _kondisiList = ['Baik', 'Perlu Perhatian', 'Rusak'];

  int get _jadwalId => widget.args['jadwalId'];
  int get _invJenisId => widget.args['invJenisId'] ?? widget.args['invJenis'];
  int? get _invId => widget.args['invId'];
  String get _invNama => widget.args['invNama'] ?? '';

  @override
  void initState() {
    super.initState();
    _invNo = widget.args['invNo'];
    _invMerk = widget.args['invMerk'];
    _invKondisiAwal = widget.args['invKondisi'];
    _invPicNama = widget.args['invPicNama'];
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTemplate());
  }

  @override
  void dispose() {
    _ketCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    final p = context.read<JadwalProvider>();
    try {
      final items = await p.fetchTemplate(_invJenisId);

      if (!mounted) return;
      setState(() {
        _checklistItems = items;
        _loadingTemplate = false;
      });

      final templateError = p.error;
      if (items.isEmpty && templateError != null && templateError.isNotEmpty) {
        await AppNotifier.showError(
            context, 'Gagal memuat template checklist: $templateError');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingTemplate = false;
        _checklistItems = [];
      });
      await AppNotifier.showError(context, 'Gagal memuat data realisasi');
    }
  }

  Future<void> _retryLoadTemplate() async {
    if (_loadingTemplate) return;
    setState(() => _loadingTemplate = true);
    await _loadTemplate();
  }

  Future<void> _proceedToTtd() async {
    if (_checklistItems.isEmpty) {
      await AppNotifier.showWarning(context, 'Template checklist kosong');
      return;
    }

    final belumDipilih = _checklistItems
        .where((item) => item.hasil != 'OK' && item.hasil != 'NK');
    if (belumDipilih.isNotEmpty) {
      await AppNotifier.showWarning(context,
          'Pilih hasil OK/NK untuk semua item checklist terlebih dahulu');
      return;
    }

    final nkTanpaKondisi = _checklistItems.where((item) =>
        item.hasil == 'NK' && (item.kondisi == null || item.kondisi!.isEmpty));
    if (nkTanpaKondisi.isNotEmpty) {
      await AppNotifier.showWarning(
          context, 'Pilih kondisi untuk setiap item yang tidak sesuai (NK)');
      return;
    }

    final ttdData = await _openTtdPopup();
    if (ttdData == null || !mounted) {
      return;
    }

    final p = context.read<JadwalProvider>();
    final now = DateTime.now();
    final tgl = DateFormatter.toApi(now);
    final jamMulai =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';

    final body = {
      'real_jadwal_id': _jadwalId,
      'real_inv_id': _invId,
      'real_tgl': tgl,
      'real_jam_mulai': jamMulai,
      'real_kondisi_akhir': _kondisi,
      'real_keterangan':
          _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
    };

    setState(() => _submitting = true);
    final real = await p.createRealisasi(body);
    if (!mounted) {
      return;
    }
    if (real == null) {
      setState(() => _submitting = false);
      await AppNotifier.showError(
          context, p.error ?? 'Gagal membuat data realisasi');
      return;
    }

    final okChecklist = await p.saveChecklist(real.realId, _checklistItems);
    if (!mounted) {
      return;
    }
    if (!okChecklist) {
      setState(() => _submitting = false);
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan checklist realisasi');
      return;
    }

    final okTtd = await p.saveTtd(
      real.realId,
      ttdData.picNama,
      'data:image/png;base64,${ttdData.signatureBase64}',
    );
    if (!mounted) {
      return;
    }
    if (!okTtd) {
      setState(() => _submitting = false);
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan tanda tangan');
      return;
    }

    setState(() => _submitting = false);
    await AppNotifier.showSuccess(context, 'Realisasi berhasil diselesaikan');
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  Future<_TtdSubmitData?> _openTtdPopup() async {
    return showDialog<_TtdSubmitData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TtdDialog(
        defaultPicNama: _invPicNama,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_invNama.isNotEmpty ? _invNama : 'Form Realisasi'),
        centerTitle: false,
      ),
      body: _loadingTemplate
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    final templateError = context.watch<JadwalProvider>().error;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth =
            constraints.maxWidth > 1100 ? 920.0 : constraints.maxWidth;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _buildHeroCard(),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Checklist Pemeriksaan',
                  subtitle:
                      'Centang hasil pemeriksaan sebelum realisasi diselesaikan.',
                  child: Column(
                    children: [
                      if (_checklistItems.isEmpty)
                        Card(
                          margin: EdgeInsets.zero,
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(children: [
                              const Icon(Icons.checklist_outlined,
                                  size: 36, color: AppColors.textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                (templateError != null &&
                                        templateError.isNotEmpty)
                                    ? 'Gagal memuat template checklist'
                                    : 'Tidak ada template checklist untuk jenis ini',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                              if (templateError != null &&
                                  templateError.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  templateError,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadingTemplate
                                    ? null
                                    : _retryLoadTemplate,
                                icon: _loadingTemplate
                                    ? const SizedBox(
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh_outlined,
                                        size: 16),
                                label: Text(_loadingTemplate
                                    ? 'Memuat...'
                                    : 'Muat Ulang'),
                              ),
                            ]),
                          ),
                        )
                      else
                        ..._checklistItems.asMap().entries.map(
                              (e) => _ChecklistItemCard(
                                item: e.value,
                                index: e.key,
                                onChanged: () => setState(() {}),
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: 'Hasil Realisasi',
                  subtitle:
                      'Tentukan kondisi akhir unit dan tambahkan catatan bila ada temuan.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kondisi Akhir',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 10),
                      Row(
                        children: _kondisiList.map((k) {
                          final selected = _kondisi == k;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: k == _kondisiList.last ? 0 : 8),
                              child: InkWell(
                                onTap: () => setState(() => _kondisi = k),
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? _kondisiColor(k)
                                        : _kondisiColor(k)
                                            .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selected
                                          ? _kondisiColor(k)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      k,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? Colors.white
                                            : _kondisiColor(k),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      const Text('Catatan',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ketCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Tuliskan catatan atau temuan selama maintenance...',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Consumer<JadwalProvider>(
                  builder: (_, p, __) => Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // const Text(
                          //   'Penyelesaian Realisasi',
                          //   style: TextStyle(
                          //       fontWeight: FontWeight.w700, fontSize: 14),
                          // ),
                          // const SizedBox(height: 4),
                          const Text(
                            'Lanjutkan Tanda Tangan PIC untuk menyimpan realisasi.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed:
                                p.loading || _submitting ? null : _proceedToTtd,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                            ),
                            icon: p.loading || _submitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.draw_outlined),
                            label: const Text('Lanjut Tanda Tangan PIC'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroCard() {
    final metaItems = <Widget>[];
    if ((_invNo ?? '').trim().isNotEmpty) {
      metaItems
          .add(_metaChip(Icons.format_list_numbered_rounded, _invNo!.trim()));
    }
    if ((_invMerk ?? '').trim().isNotEmpty) {
      metaItems.add(
        _metaChip(
            Icons.branding_watermark_outlined, _invMerk!.trim().toUpperCase()),
      );
    }
    if ((_invKondisiAwal ?? '').trim().isNotEmpty) {
      metaItems.add(
          _metaChip(Icons.health_and_safety_outlined, _invKondisiAwal!.trim()));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.fact_check_outlined,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invNama.isNotEmpty ? _invNama : 'Form Realisasi',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (metaItems.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metaItems,
              ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _kondisiColor(String k) {
    switch (k) {
      case 'Baik':
        return AppColors.success;
      case 'Perlu Perhatian':
        return const Color(0xFFF59E0B);
      case 'Rusak':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  CHECKLIST ITEM CARD
// ═══════════════════════════════════════════════════════════════
class _ChecklistItemCard extends StatefulWidget {
  final ChecklistInputModel item;
  final int index;
  final VoidCallback onChanged;
  const _ChecklistItemCard(
      {required this.item, required this.index, required this.onChanged});
  @override
  State<_ChecklistItemCard> createState() => _ChecklistItemCardState();
}

class _ChecklistItemCardState extends State<_ChecklistItemCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                  child: Text('${item.ctUrutan}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.ctItem,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if ((item.ctKeterangan ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.ctKeterangan!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
              children: ['OK', 'NK'].map((h) {
            final sel = item.hasil == h;
            final color = h == 'OK' ? AppColors.success : AppColors.danger;
            return Expanded(
                child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () {
                  setState(() {
                    item.hasil = h;
                    if (h != 'NK') item.kondisi = null;
                  });
                  widget.onChanged();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? color : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? color : Colors.transparent),
                  ),
                  child: Center(
                      child: Text(h,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : color))),
                ),
              ),
            ));
          }).toList()),
          if (item.hasil != 'OK' && item.hasil != 'NK') ...[
            const SizedBox(height: 8),
            const Text(
              'Pilih hasil pemeriksaan (OK/NK).',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          if (item.hasil == 'OK') ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 14, color: AppColors.success),
                  SizedBox(width: 4),
                  Text('Sudah diperiksa dan sesuai standar',
                      style: TextStyle(fontSize: 11, color: AppColors.success)),
                ],
              ),
            ),
          ],
          if (item.hasil == 'NK') ...[
            const SizedBox(height: 10),
            const Text('Kondisi:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
                children: ['Baik', 'Sedang', 'Buruk'].map((k) {
              final sel = item.kondisi == k;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    setState(() => item.kondisi = k);
                    widget.onChanged();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.warning
                          : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: sel ? AppColors.warning : Colors.transparent),
                    ),
                    child: Text(k,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.warning)),
                  ),
                ),
              );
            }).toList()),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TTD DIALOG
// ═══════════════════════════════════════════════════════════════
class _TtdDialog extends StatefulWidget {
  final String? defaultPicNama;
  const _TtdDialog({
    this.defaultPicNama,
  });
  @override
  State<_TtdDialog> createState() => _TtdDialogState();
}

class _TtdDialogState extends State<_TtdDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picCtrl = TextEditingController();
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _currentStroke = [];
  bool _hasSignature = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _picCtrl.text = (widget.defaultPicNama ?? '').trim();
  }

  @override
  void dispose() {
    _picCtrl.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d) {
    _currentStroke = [d.localPosition];
    setState(() {
      _hasSignature = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _currentStroke.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    _currentStroke.add(null); // penanda akhir stroke
    setState(() => _strokes.add(List.from(_currentStroke)));
    _currentStroke = [];
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
      _hasSignature = false;
    });
  }

  void _handleClose() {
    if (_submitting) {
      return;
    }
    Navigator.pop(context);
  }

  Future<String> _captureBase64() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(320, 160);

    // background putih
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // gambar semua strokes
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      final path = Path();
      bool started = false;
      for (final pt in stroke) {
        if (pt == null) {
          started = false;
          continue;
        }
        if (!started) {
          path.moveTo(pt.dx, pt.dy);
          started = true;
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return base64Encode(bytes!.buffer.asUint8List());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_hasSignature) {
      await AppNotifier.showWarning(context, 'Tanda tangan belum dibuat');
      return;
    }

    setState(() => _submitting = true);
    final base64 = await _captureBase64();
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    Navigator.pop(
      context,
      _TtdSubmitData(
        picNama: _picCtrl.text.trim(),
        signatureBase64: base64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _submitting) {
          setState(() => _submitting = false);
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header
                Row(children: [
                  const Expanded(
                      child: Text('Tanda Tangan PIC',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _submitting ? null : _handleClose,
                  ),
                ]),
                const SizedBox(height: 4),
                const Text(
                    'Isi nama PIC dan tanda tangan untuk menyelesaikan realisasi.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _picCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama PIC *',
                    hintText: 'Masukkan nama PIC',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama PIC wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // canvas TTD
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Area Tanda Tangan',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: _clearCanvas,
                      icon: const Icon(Icons.refresh, size: 16),
                      label:
                          const Text('Ulang', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        painter: _SignaturePainter(
                            strokes: _strokes, currentStroke: _currentStroke),
                      ),
                    ),
                  ),
                ),

                if (!_hasSignature) ...[
                  const SizedBox(height: 6),
                  const Center(
                      child: Text('Tanda tangan di area atas',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary))),
                ],
                const SizedBox(height: 20),

                Consumer<JadwalProvider>(
                  builder: (_, p, __) => ElevatedButton.icon(
                    onPressed: p.loading || _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                    icon: p.loading || _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Selesaikan Realisasi'),
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

class _TtdSubmitData {
  final String picNama;
  final String signatureBase64;

  const _TtdSubmitData({
    required this.picNama,
    required this.signatureBase64,
  });
}

// ── Custom painter untuk TTD ───────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  final List<Offset?> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  final _paint = Paint()
    ..color = Colors.black
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _drawStroke(Canvas canvas, List<Offset?> stroke) {
    final path = Path();
    bool started = false;
    for (final pt in stroke) {
      if (pt == null) {
        started = false;
        continue;
      }
      if (!started) {
        path.moveTo(pt.dx, pt.dy);
        started = true;
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path, _paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // garis panduan
    canvas.drawLine(
      Offset(16, size.height * 0.75),
      Offset(size.width - 16, size.height * 0.75),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 0.8,
    );
    for (final s in strokes) {
      _drawStroke(canvas, s);
    }
    _drawStroke(canvas, currentStroke);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}

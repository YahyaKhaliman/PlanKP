import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
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
  int? _realId; // ID realisasi setelah berhasil dibuat
  bool _submitting = false;
  String? _invNo;
  String? _invKondisiAwal;
  String? _invPicNama;

  static const _kondisiList = ['Baik', 'Perlu Perhatian', 'Rusak'];

  int get _jadwalId => widget.args['jadwalId'];
  int get _invJenisId => widget.args['invJenisId'] ?? widget.args['invJenis'];
  String get _invJenisNama => widget.args['invJenisNama'] ?? '';
  int? get _invId => widget.args['invId'];
  String get _invNama => widget.args['invNama'] ?? '';

  @override
  void initState() {
    super.initState();
    _invNo = widget.args['invNo'];
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal memuat template checklist: $templateError')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingTemplate = false;
        _checklistItems = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat data realisasi')),
      );
    }
  }

  Future<void> _retryLoadTemplate() async {
    if (_loadingTemplate) return;
    setState(() => _loadingTemplate = true);
    await _loadTemplate();
  }

  // Simpan realisasi + checklist terlebih dahulu, lalu buka TTD popup
  Future<void> _proceedToTtd() async {
    if (_checklistItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template checklist kosong')));
      return;
    }

    final unfinished = _checklistItems.where((item) => item.hasil == 'N/A');
    if (unfinished.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua item checklist wajib diisi')),
      );
      return;
    }

    final p = context.read<JadwalProvider>();
    final now = DateTime.now();
    final tgl =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final jamMulai =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';

    String kondisiAkhir = _deriveKondisiAkhir();
    final body = {
      'real_jadwal_id': _jadwalId,
      'real_inv_id': _invId,
      'real_tgl': tgl,
      'real_jam_mulai': jamMulai,
      'real_kondisi_akhir': kondisiAkhir,
      'real_keterangan':
          _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
    };

    setState(() => _submitting = true);
    final real = await p.createRealisasi(body);
    if (real == null || !mounted) {
      setState(() => _submitting = false);
      return;
    }
    _realId = real.realId;

    final okChecklist = await p.saveChecklist(real.realId, _checklistItems);
    if (!okChecklist || !mounted) {
      setState(() => _submitting = false);
      return;
    }

    _openTtdPopup(real.realId);
  }

  void _openTtdPopup(int realId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TtdDialog(
        realId: realId,
        defaultPicNama: _invPicNama,
        onSelesai: () {
          Navigator.pop(context); // tutup dialog
          Navigator.pop(context); // kembali ke sebelumnya
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Realisasi selesai dan TTD tersimpan'),
              backgroundColor: AppColors.success,
            ),
          );
        },
        onSubmitStart: () => setState(() => _submitting = true),
        onSubmitEnd: () => setState(() => _submitting = false),
      ),
    );
  }

  String _deriveKondisiAkhir() {
    bool allNa = _checklistItems.every((i) => i.hasil == 'N/A');
    bool hasBuruk = _checklistItems.any(
      (i) => i.hasil == 'NK' && i.kondisi == 'Buruk',
    );
    bool hasSedangOrNoKond = _checklistItems.any(
      (i) => i.hasil == 'NK' && (i.kondisi == 'Sedang' || i.kondisi == null),
    );
    if (hasBuruk) return 'Rusak';
    if (hasSedangOrNoKond) return 'Perlu Perhatian';
    if (allNa) return 'Baik';
    return 'Baik';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_invNama.isNotEmpty ? _invNama : 'Form Realisasi')),
      body: _loadingTemplate
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    final templateError = context.watch<JadwalProvider>().error;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Info jadwal ─────────────────────────────────────
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Info Realisasi',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              _infoRow('Jenis',
                  _invJenisNama.isNotEmpty ? _invJenisNama : '${_invJenisId}'),
              if (_invNama.isNotEmpty) _infoRow('Unit', _invNama),
              if ((_invNo ?? '').isNotEmpty) _infoRow('No Inventaris', _invNo!),
              if (_invPicNama != null) _infoRow('PIC', _invPicNama ?? '-'),
              if (_invKondisiAwal != null)
                _infoRow('Kondisi Awal', _invKondisiAwal ?? '-'),
              _infoRow('Tanggal', _fmtToday()),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── Checklist ────────────────────────────────────────
        const Text('Checklist',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),

        if (_checklistItems.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Icon(Icons.checklist_outlined,
                    size: 36, color: AppColors.textSecondary),
                const SizedBox(height: 8),
                Text(
                  (templateError != null && templateError.isNotEmpty)
                      ? 'Gagal memuat template checklist'
                      : 'Tidak ada template checklist untuk jenis ini',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (templateError != null && templateError.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    templateError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadingTemplate ? null : _retryLoadTemplate,
                  icon: _loadingTemplate
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_outlined, size: 16),
                  label: Text(_loadingTemplate ? 'Memuat...' : 'Muat Ulang'),
                ),
              ]),
            ),
          ),

        ..._checklistItems.asMap().entries.map((e) => _ChecklistItemCard(
              item: e.value,
              index: e.key,
              onChanged: () => setState(() {}),
            )),

        const SizedBox(height: 16),

        // ── Kondisi akhir ─────────────────────────────────────
        const Text('Kondisi Akhir',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
            children: _kondisiList.map((k) {
          final selected = _kondisi == k;
          return Expanded(
              child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() => _kondisi = k),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? _kondisiColor(k)
                      : _kondisiColor(k).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? _kondisiColor(k) : Colors.transparent),
                ),
                child: Center(
                    child: Text(k,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                selected ? Colors.white : _kondisiColor(k)))),
              ),
            ),
          ));
        }).toList()),
        const SizedBox(height: 16),

        // ── Keterangan ────────────────────────────────────────
        const Text('Keterangan Umum',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _ketCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tuliskan catatan atau temuan selama maintenance...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 24),

        // ── Tombol TTD ────────────────────────────────────────
        Consumer<JadwalProvider>(
          builder: (_, p, __) => ElevatedButton.icon(
            onPressed: p.loading || _submitting ? null : _proceedToTtd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            icon: p.loading || _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.draw_outlined),
            label: const Text('Lanjut ke Tanda Tangan'),
          ),
        ),
      ],
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

  Widget _infoRow(String label, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))),
          Expanded(
              child: Text(val,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))),
        ]),
      );

  String _fmtToday() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
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
  late TextEditingController _ketCtrl;

  @override
  void initState() {
    super.initState();
    _ketCtrl = TextEditingController(text: widget.item.keterangan);
  }

  @override
  void dispose() {
    _ketCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // nomor + nama item
          Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
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
                child: Text(item.ctItem,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14))),
          ]),
          if (item.ctKeterangan != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(item.ctKeterangan!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          ],
          const SizedBox(height: 12),

          // Pilihan hasil: OK / NK / N/A
          Row(
              children: ['OK', 'NK', 'N/A'].map((h) {
            final sel = item.hasil == h;
            final color = h == 'OK'
                ? AppColors.success
                : h == 'NK'
                    ? AppColors.danger
                    : AppColors.textSecondary;
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
                    color: sel ? color : color.withOpacity(0.08),
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

          // Jika NK: pilih kondisi
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
                          : AppColors.warning.withOpacity(0.1),
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

          // Keterangan per item
          const SizedBox(height: 10),
          TextField(
            controller: _ketCtrl,
            decoration: const InputDecoration(
              hintText: 'Keterangan (opsional)...',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => item.keterangan = v.isEmpty ? null : v,
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TTD DIALOG
// ═══════════════════════════════════════════════════════════════
class _TtdDialog extends StatefulWidget {
  final int realId;
  final String? defaultPicNama;
  final VoidCallback onSelesai;
  final VoidCallback onSubmitStart;
  final VoidCallback onSubmitEnd;
  const _TtdDialog({
    required this.realId,
    required this.onSelesai,
    required this.onSubmitStart,
    required this.onSubmitEnd,
    this.defaultPicNama,
  });
  @override
  State<_TtdDialog> createState() => _TtdDialogState();
}

class _TtdDialogState extends State<_TtdDialog> {
  final _picCtrl = TextEditingController();
  final _canvasKey = GlobalKey();
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _currentStroke = [];
  bool _hasSignature = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _picCtrl.text = '';
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
        } else
          path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return base64Encode(bytes!.buffer.asUint8List());
  }

  Future<void> _submit() async {
    if (_picCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nama PIC wajib diisi')));
      return;
    }
    if (!_hasSignature) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanda tangan belum dibuat')));
      return;
    }

    widget.onSubmitStart();
    setState(() => _submitting = true);
    final base64 = await _captureBase64();
    final p = context.read<JadwalProvider>();
    final namaPic = _picCtrl.text.trim();
    final ok = await p.saveTtd(
        widget.realId, namaPic, 'data:image/png;base64,$base64');
    if (mounted) {
      widget.onSubmitEnd();
      setState(() => _submitting = false);
      if (ok) widget.onSelesai();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                onPressed: () => Navigator.pop(context),
              ),
            ]),
            const SizedBox(height: 4),
            const Text(
                'Isi nama PIC dan tanda tangan untuk menyelesaikan realisasi.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),

            TextField(
              controller: _picCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama PIC',
                hintText: 'Masukkan nama PIC',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            // canvas TTD
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Area Tanda Tangan',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: _clearCanvas,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Ulang', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Container(
              key: _canvasKey,
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
    );
  }
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
      } else
        path.lineTo(pt.dx, pt.dy);
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
    for (final s in strokes) _drawStroke(canvas, s);
    _drawStroke(canvas, currentStroke);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}

// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/responsive_sheet.dart';
import '../../../core/widgets/app_notifier.dart';

import '../models/checklist_hasil_model.dart';
import '../models/realisasi_model.dart';
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
  List<int>? _imageBytes;
  String? _imageName;
  int? _realId;

  RealisasiModel? _lastTemuan;

  static const _kondisiList = ['Baik', 'Perlu Perhatian', 'Rusak'];
  static const _allowedImageExt = ['jpg', 'jpeg', 'png', 'webp'];

  int get _jadwalId => widget.args['jadwalId'];
  int get _invJenisId => widget.args['invJenisId'] ?? widget.args['invJenis'];
  int? get _invId => widget.args['invId'];
  String get _invNama => widget.args['invNama'] ?? '';

  @override
  void initState() {
    super.initState();
    _realId = widget.args['realId'];
    _invNo = widget.args['invNo'];
    _invMerk = widget.args['invMerk'];
    _invKondisiAwal = widget.args['invKondisi'];
    _invPicNama = widget.args['invPicNama'];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTemplate();
      _fetchLastTemuan();
    });
  }

  Future<void> _fetchLastTemuan() async {
    if (_invId == null) return;
    final p = context.read<JadwalProvider>();
    final temuan = await p.fetchLastTemuanByInventaris(_invId!);
    if (mounted && temuan != null) {
      setState(() {
        _lastTemuan = temuan;
      });
    }
  }

  final _scrollController = ScrollController();
  static const _kScrollbarThickness = 8.0;
  static const _kScrollbarRadius = Radius.circular(100);
  static const _kScrollbarMargin = 3.0;

  @override
  void dispose() {
    _scrollController.dispose();
    _ketCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    final p = context.read<JadwalProvider>();
    try {
      if (_realId != null) {
        // Melanjutkan draft realisasi yang sudah ada
        await p.fetchRealisasiDetail(_realId!);
        final detail = p.realisasiDetail;
        if (detail != null && mounted) {
          final inv = detail.inventaris;
          setState(() {
            _kondisi = detail.realKondisiAkhir ?? 'Baik';
            _ketCtrl.text = detail.realKeterangan ?? '';
            _invNo ??= inv?['inv_no'] ?? inv?['inv_serial_number'];
            _invMerk ??= inv?['inv_merk'];
            _invKondisiAwal ??= inv?['inv_kondisi'];
            _invPicNama ??= inv?['pic_user']?['user_nama'] ??
                inv?['inv_pic'] ??
                detail.realTtdPicNama;
            _checklistItems = detail.hasilChecklist.map((hc) {
              return ChecklistInputModel(
                ctId: hc.hcCtId,
                ctItem: hc.itemNama,
                ctUrutan: hc.urutan,
              )
                ..hasil = hc.hcHasil
                ..kondisi = hc.hcKondisi
                ..keterangan = hc.hcKeterangan;
            }).toList();
            _loadingTemplate = false;
          });
          return;
        }
      }

      // Alur normal: load template checklist baru
      final items = await p.fetchTemplate(_invJenisId);

      if (!mounted) return;
      setState(() {
        _checklistItems = items;
        if ((_invPicNama == null || _invPicNama!.trim().isEmpty) &&
            _invId != null) {
          final found = p.inventarisByJenis.cast<dynamic>().firstWhere(
                (e) => e is Map && e['inv_id'] == _invId,
                orElse: () => null,
              );
          if (found is Map) {
            _invPicNama ??=
                (found['pic_user']?['user_nama'] ?? found['inv_pic'])
                    ?.toString();
            _invNo ??=
                (found['inv_serial_number'] ?? found['inv_no'])?.toString();
            _invMerk ??= found['inv_merk']?.toString();
            _invKondisiAwal ??= found['inv_kondisi']?.toString();
          }
        }
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

    final belumDipilih = _checklistItems.where((item) =>
        item.hasil != 'OK' && item.hasil != 'NK' && item.hasil != 'N/A');
    if (belumDipilih.isNotEmpty) {
      await AppNotifier.showWarning(context,
          'Pilih hasil OK/NK/Tidak Ada untuk semua item checklist terlebih dahulu');
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

    int targetRealId;
    if (_realId != null) {
      targetRealId = _realId!;
      final okUpdate = await p.updateRealisasi(targetRealId, {
        'real_kondisi_akhir': _kondisi,
        'real_keterangan':
            _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
      });
      if (!okUpdate) {
        if (!mounted) return;
        setState(() => _submitting = false);
        await AppNotifier.showError(
            context, p.error ?? 'Gagal memperbarui realisasi');
        return;
      }
    } else {
      final real = await p.createRealisasi(body);
      if (real == null) {
        if (!mounted) return;
        setState(() => _submitting = false);
        await AppNotifier.showError(
            context, p.error ?? 'Gagal membuat data realisasi');
        return;
      }
      targetRealId = real.realId;
    }

    final okChecklist = await p.saveChecklist(targetRealId, _checklistItems);
    if (!mounted) return;
    if (!okChecklist) {
      setState(() => _submitting = false);
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan checklist realisasi');
      return;
    }

    // Jika user mengupload foto bukti (lakukan sebelum TTD agar status masih 'Draft')
    if (_imageBytes != null && _imageName != null) {
      final okFoto = await p.uploadRealisasiFoto(
        targetRealId,
        bytes: _imageBytes,
        filename: _imageName,
      );
      if (!mounted) return;
      if (!okFoto) {
        setState(() => _submitting = false);
        await AppNotifier.showError(
            context, p.error ?? 'Gagal mengunggah foto bukti realisasi');
        return;
      }
    }

    final okTtd = await p.saveTtd(
      targetRealId,
      ttdData.picNama,
      'data:image/png;base64,${ttdData.signatureBase64}',
    );
    if (!mounted) return;
    if (!okTtd) {
      setState(() => _submitting = false);
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan tanda tangan');
      return;
    }

    setState(() => _submitting = false);
    await AppNotifier.showSuccess(context, 'Realisasi berhasil diselesaikan');
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _saveAsDraft() async {
    if (_checklistItems.isEmpty) {
      await AppNotifier.showWarning(context, 'Template checklist kosong');
      return;
    }

    final belumDipilih = _checklistItems.where((item) =>
        item.hasil != 'OK' && item.hasil != 'NK' && item.hasil != 'N/A');
    if (belumDipilih.isNotEmpty) {
      await AppNotifier.showWarning(context,
          'Pilih hasil OK/NK/Tidak Ada untuk semua item checklist terlebih dahulu');
      return;
    }

    final nkTanpaKondisi = _checklistItems.where((item) =>
        item.hasil == 'NK' && (item.kondisi == null || item.kondisi!.isEmpty));
    if (nkTanpaKondisi.isNotEmpty) {
      await AppNotifier.showWarning(
          context, 'Pilih kondisi untuk setiap item yang tidak sesuai (NK)');
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

    int targetRealId;
    if (_realId != null) {
      targetRealId = _realId!;
      final okUpdate = await p.updateRealisasi(targetRealId, {
        'real_kondisi_akhir': _kondisi,
        'real_keterangan':
            _ketCtrl.text.trim().isEmpty ? null : _ketCtrl.text.trim(),
      });
      if (!okUpdate) {
        if (!mounted) return;
        setState(() => _submitting = false);
        await AppNotifier.showError(
            context, p.error ?? 'Gagal memperbarui realisasi');
        return;
      }
    } else {
      final real = await p.createRealisasi(body);
      if (real == null) {
        if (!mounted) return;
        setState(() => _submitting = false);
        await AppNotifier.showError(
            context, p.error ?? 'Gagal membuat data realisasi');
        return;
      }
      targetRealId = real.realId;
    }

    final okChecklist = await p.saveChecklist(targetRealId, _checklistItems);
    if (!mounted) return;
    if (!okChecklist) {
      setState(() => _submitting = false);
      await AppNotifier.showError(
          context, p.error ?? 'Gagal menyimpan checklist realisasi');
      return;
    }

    if (_imageBytes != null && _imageName != null) {
      final okFoto = await p.uploadRealisasiFoto(
        targetRealId,
        bytes: _imageBytes,
        filename: _imageName,
      );
      if (!mounted) return;
      if (!okFoto) {
        setState(() => _submitting = false);
        await AppNotifier.showError(
            context, p.error ?? 'Gagal mengunggah foto bukti realisasi');
        return;
      }
    }

    setState(() => _submitting = false);
    await AppNotifier.showSuccess(
        context, 'Realisasi berhasil disimpan sebagai Draft');
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<_TtdSubmitData?> _openTtdPopup() async {
    String? picNama = _invPicNama;
    if ((picNama == null || picNama.trim().isEmpty) && _invId != null) {
      final p = context.read<JadwalProvider>();
      final found = p.inventarisByJenis.cast<dynamic>().firstWhere(
            (e) => e is Map && e['inv_id'] == _invId,
            orElse: () => null,
          );
      if (found is Map) {
        picNama =
            (found['pic_user']?['user_nama'] ?? found['inv_pic'])?.toString();
      }
    }

    return showDialog<_TtdSubmitData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TtdDialog(
        defaultPicNama: picNama,
        checklistItems: _checklistItems,
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      if (picked != null) {
        final ext = picked.name.split('.').last.toLowerCase();
        if (!_allowedImageExt.contains(ext)) {
          if (mounted) {
            AppNotifier.showWarning(
                context, 'Format gambar harus .jpg, .jpeg, .png, atau .webp');
          }
          return;
        }
        final bytes = await picked.readAsBytes();
        // Pengaman FE: Jika gambar di atas 10 MB (kemungkinan file rusak/non-gambar), berikan peringatan
        if (bytes.length > 10 * 1024 * 1024) {
          if (mounted) {
            AppNotifier.showWarning(
                context, 'Ukuran foto terlalu besar (maksimal 10 MB)');
          }
          return;
        }
        final safeName =
            picked.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        setState(() {
          _imageBytes = bytes.toList();
          _imageName = safeName.contains('.') ? safeName : '$safeName.$ext';
        });
      }
    } catch (e) {
      debugPrint('[PICK IMAGE ERROR] $e');
      if (mounted) {
        AppNotifier.showError(context, 'Gagal mengambil gambar: $e');
      }
    }
  }

  void _showImageSourceDialog() {
    showResponsiveSheet(
      context,
      maxDesktopWidth: 420,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Pilih Sumber Foto Bukti',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.primary),
                title: const Text('Kamera (Ambil Foto Langsung)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: const Text('Galeri (Pilih dari Foto Perangkat)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastTemuanBanner() {
    if (_lastTemuan == null) return const SizedBox.shrink();

    final tglStr = _lastTemuan!.realTgl.isNotEmpty
        ? DateFormatter.formatMessageDates(_lastTemuan!.realTgl)
        : '';
    final ketStr = (_lastTemuan!.realKeterangan ?? '').trim();
    final kondisiStr = _lastTemuan!.realKondisiAkhir ?? 'Perlu Perhatian';

    const warningColor = Color(0xFFB45309);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: warningColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Temuan Terakhir Inventaris ${tglStr.isNotEmpty ? "($tglStr)" : ""}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: warningColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  kondisiStr,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: warningColor,
                  ),
                ),
              ),
            ],
          ),
          if (ketStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"$ketStr"',
              style: const TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                final copyText = ketStr.isNotEmpty
                    ? ketStr
                    : 'Temuan sebelumnya belum teratasi: $kondisiStr';

                if (_ketCtrl.text.trim().isEmpty) {
                  _ketCtrl.text = copyText;
                } else if (!_ketCtrl.text.contains(copyText)) {
                  _ketCtrl.text =
                      '${_ketCtrl.text.trim()}\n\n[Temuan Sebelumnya]: $copyText';
                }

                if (kondisiStr == 'Perlu Perhatian' || kondisiStr == 'Rusak') {
                  setState(() => _kondisi = kondisiStr);
                }

                AppNotifier.showInfo(
                  context,
                  'Catatan temuan sebelumnya berhasil disalin!',
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_copy_rounded,
                        size: 13, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Gunakan Catatan Temuan Ini',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return _buildSectionCard(
      title: 'Bukti Foto Realisasi (opsional)',
      subtitle:
          'Tambahkan foto kondisi unit sebagai bukti pendukung penyelesaian maintenance.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_imageBytes == null)
            InkWell(
              onTap: _showImageSourceDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pilih / Ambil Foto Bukti',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mendukung Kamera langsung atau Unggah dari Galeri',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 240,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(
                      Uint8List.fromList(_imageBytes!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      // Ganti foto button
                      Material(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          onTap: _showImageSourceDialog,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Hapus foto button
                      Material(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _imageBytes = null;
                              _imageName = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _imageName ?? 'Foto Realisasi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Text(
                          '${(_imageBytes!.length / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
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
          : Column(
              children: [
                _buildProgressHeader(),
                Expanded(child: _buildForm()),
              ],
            ),
    );
  }

  Widget _buildProgressHeader() {
    if (_checklistItems.isEmpty) return const SizedBox.shrink();
    int total = _checklistItems.length;
    int filled = _checklistItems
        .where((item) =>
            item.hasil == 'OK' || item.hasil == 'NK' || item.hasil == 'N/A')
        .length;
    double progress = total == 0 ? 0 : filled / total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Checklist',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: progress == 1.0
                      ? AppColors.successSoft
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$filled dari $total terisi (${(progress * 100).round()}%)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color:
                        progress == 1.0 ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? AppColors.success : AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Consumer<JadwalProvider>(
        builder: (_, p, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih simpan sebagai Draft (Tunda TTD) atau lanjutkan Tanda Tangan PIC untuk menyelesaikan maintenance.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: p.loading || _submitting ? null : _saveAsDraft,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 46),
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: p.loading || _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      'Simpan Draft',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: p.loading || _submitting ? null : _proceedToTtd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: p.loading || _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.draw_rounded, size: 18),
                    label: Text(
                      'Tanda Tangan PIC',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final templateError = context.watch<JadwalProvider>().error;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth = AppBreakpoints.responsiveValue(
          context,
          mobile: constraints.maxWidth,
          tablet: constraints.maxWidth > 880 ? 860.0 : constraints.maxWidth,
          desktop: 1080.0,
        );
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: false,
              thickness: _kScrollbarThickness,
              radius: _kScrollbarRadius,
              thumbColor: AppColors.primary.withValues(alpha: 0.55),
              minThumbLength: 48,
              crossAxisMargin: _kScrollbarMargin,
              mainAxisMargin: 10.0,
              interactive: true,
              child: ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                // Padding kanan lebih besar agar konten tidak tertutup thumb scrollbar
                padding: const EdgeInsets.fromLTRB(16, 16, 26, 32),
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
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
                        _buildLastTemuanBanner(),
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
                  const SizedBox(height: 16),
                  _buildPhotoSection(),
                  const SizedBox(height: 20),
                  _buildActionButtonsCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroCard() {
    final metaItems = <Widget>[];
    if ((_invNo ?? '').trim().isNotEmpty) {
      final displayNo = _invNo!.trim();
      metaItems.add(_metaChip(
        Icons.format_list_numbered_rounded,
        displayNo.toLowerCase().startsWith('sn:')
            ? displayNo
            : 'SN: $displayNo',
      ));
    }
    if ((_invMerk ?? '').trim().isNotEmpty) {
      metaItems.add(
        _metaChip(Icons.branding_watermark_outlined, _invMerk!.trim()),
      );
    }
    if ((_invKondisiAwal ?? '').trim().isNotEmpty) {
      metaItems.add(
          _metaChip(Icons.health_and_safety_outlined, _invKondisiAwal!.trim()));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
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
                      style: GoogleFonts.plusJakartaSans(
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
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text('${item.ctUrutan}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.ctItem,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  if ((item.ctKeterangan ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.ctKeterangan!,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
              children: ['OK', 'NK', 'N/A'].map((h) {
            final sel = item.hasil == h;
            Color color;
            String label;
            if (h == 'OK') {
              color = AppColors.success;
              label = 'OK (Sesuai)';
            } else if (h == 'NK') {
              color = AppColors.danger;
              label = 'NK (Temuan)';
            } else {
              color = AppColors.textSecondary;
              label = 'Tidak Ada (N/A)';
            }
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
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? color : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? color : color.withValues(alpha: 0.2),
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                      child: Text(label,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight:
                                  sel ? FontWeight.w800 : FontWeight.w700,
                              color: sel ? Colors.white : color))),
                ),
              ),
            ));
          }).toList()),
          if (item.hasil != 'OK' &&
              item.hasil != 'NK' &&
              item.hasil != 'N/A') ...[
            const SizedBox(height: 8),
            Text(
              'Pilih hasil pemeriksaan (OK/NK/Tidak Ada).',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          if (item.hasil == 'N/A') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.remove_circle_outline,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text('Item tidak ada di lapangan (N/A)',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
          if (item.hasil == 'OK') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 13, color: AppColors.success),
                  const SizedBox(width: 5),
                  Text('Kondisi unit sesuai dan normal',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          if (item.hasil == 'NK') ...[
            const SizedBox(height: 10),
            Text('Tingkat Kondisi Temuan:',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
                children: ['Baik', 'Sedang', 'Buruk'].map((k) {
              final sel = item.kondisi == k;
              final Color kColor = k == 'Baik'
                  ? AppColors.primary
                  : k == 'Sedang'
                      ? AppColors.warning
                      : AppColors.danger;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    setState(() => item.kondisi = k);
                    widget.onChanged();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? kColor : kColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: sel ? kColor : kColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(k,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : kColor)),
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
class _SignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  List<List<Offset>> get strokes => List.unmodifiable(_strokes);
  List<Offset> get currentStroke => List.unmodifiable(_currentStroke);
  bool get isEmpty => _strokes.isEmpty && _currentStroke.isEmpty;
  bool get isNotEmpty => !isEmpty;

  void startStroke(Offset point) {
    _currentStroke = [point];
    notifyListeners();
  }

  void updateStroke(Offset point) {
    if (_currentStroke.isNotEmpty) {
      final last = _currentStroke.last;
      if ((point - last).distanceSquared < 1.0) return;
    }
    _currentStroke.add(point);
    notifyListeners();
  }

  void endStroke() {
    if (_currentStroke.isNotEmpty) {
      _strokes.add(List.from(_currentStroke));
      _currentStroke = [];
      notifyListeners();
    }
  }

  void clear() {
    _strokes.clear();
    _currentStroke.clear();
    notifyListeners();
  }
}

class _TtdDialog extends StatefulWidget {
  final String? defaultPicNama;
  final List<ChecklistInputModel> checklistItems;
  const _TtdDialog({
    this.defaultPicNama,
    required this.checklistItems,
  });
  @override
  State<_TtdDialog> createState() => _TtdDialogState();
}

class _TtdDialogState extends State<_TtdDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picCtrl = TextEditingController();
  final _sigController = _SignatureController();
  Size _canvasSize = const Size(320, 160);
  bool _submitting = false;
  bool _confirmSummary = false;

  @override
  void initState() {
    super.initState();
    _picCtrl.text = (widget.defaultPicNama ?? '').trim();
  }

  @override
  void dispose() {
    _picCtrl.dispose();
    _sigController.dispose();
    super.dispose();
  }

  void _clearCanvas() {
    _sigController.clear();
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

    // Skalakan goresan dari ukuran kanvas aktual ke ukuran gambar output
    final scaleX =
        _canvasSize.width > 0 ? (size.width / _canvasSize.width) : 1.0;
    final scaleY =
        _canvasSize.height > 0 ? (size.height / _canvasSize.height) : 1.0;
    canvas.scale(scaleX, scaleY);

    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (final stroke in _sigController.strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, dotPaint);
        continue;
      }
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      if (stroke.length == 2) {
        path.lineTo(stroke.last.dx, stroke.last.dy);
      } else {
        for (int i = 1; i < stroke.length - 1; i++) {
          final p0 = stroke[i];
          final p1 = stroke[i + 1];
          final midX = (p0.dx + p1.dx) / 2;
          final midY = (p0.dy + p1.dy) / 2;
          path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
        }
        path.lineTo(stroke.last.dx, stroke.last.dy);
      }
      canvas.drawPath(path, linePaint);
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
    if (!_confirmSummary) {
      await AppNotifier.showWarning(
        context,
        'Harap setujui konfirmasi pemeriksaan dan kesiapan PIC sebelum menandatangani',
      );
      return;
    }
    if (_sigController.isEmpty) {
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
        backgroundColor: AppColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.draw_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('Tanda Tangan PIC',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary))),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _submitting ? null : _handleClose,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _picCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nama PIC *',
                      hintText: 'Masukkan nama PIC lokasi',
                      prefixIcon:
                          const Icon(Icons.person_outline_rounded, size: 18),
                      hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5, color: AppColors.textMuted),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama PIC wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Rangkuman hasil checklist pemeriksaan (Hanya di FE)
                  Text(
                    'Rangkuman Hasil Pemeriksaan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 140),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: widget.checklistItems.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 8, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final item = widget.checklistItems[index];
                          Color badgeColor;
                          Color badgeBg;
                          String statusText;
                          if (item.hasil == 'OK') {
                            badgeColor = AppColors.success;
                            badgeBg = AppColors.successSoft;
                            statusText = 'OK';
                          } else if (item.hasil == 'NK') {
                            badgeColor = AppColors.warning;
                            badgeBg = AppColors.warningSoft;
                            statusText = 'NK (${item.kondisi ?? "Sedang"})';
                          } else {
                            badgeColor = AppColors.textSecondary;
                            badgeBg = AppColors.surfaceAlt;
                            statusText = 'N/A';
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.ctItem,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: badgeColor.withValues(alpha: 0.25),
                                      width: 0.8),
                                ),
                                child: Text(
                                  statusText,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Checkbox Persetujuan Tunggal
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _confirmSummary,
                      onChanged: (val) {
                        setState(() => _confirmSummary = val ?? false);
                      },
                      title: Text(
                        'Pernyataan PIC',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Saya menyatakan bahwa seluruh rangkuman pemeriksaan di atas telah sesuai.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      activeColor: AppColors.primary,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Canvas TTD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Area Tanda Tangan Digital',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _clearCanvas,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh_rounded,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text('Ulang',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      _canvasSize = Size(constraints.maxWidth, 160);
                      return Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          border:
                              Border.all(color: AppColors.primary, width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: RawGestureDetector(
                            gestures: {
                              EagerGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                      EagerGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                                (EagerGestureRecognizer instance) {},
                              ),
                            },
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (event) {
                                FocusScope.of(context).unfocus();
                                _sigController.startStroke(event.localPosition);
                              },
                              onPointerMove: (event) {
                                _sigController
                                    .updateStroke(event.localPosition);
                              },
                              onPointerUp: (_) {
                                _sigController.endStroke();
                              },
                              onPointerCancel: (_) {
                                _sigController.endStroke();
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ListenableBuilder(
                                    listenable: _sigController,
                                    builder: (context, _) {
                                      return CustomPaint(
                                        painter: _SignaturePainter(
                                          strokes: _sigController.strokes,
                                          currentStroke:
                                              _sigController.currentStroke,
                                        ),
                                      );
                                    },
                                  ),
                                  ListenableBuilder(
                                    listenable: _sigController,
                                    builder: (context, _) {
                                      if (_sigController.isNotEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return IgnorePointer(
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.gesture_rounded,
                                                size: 24,
                                                color: AppColors.textMuted
                                                    .withValues(alpha: 0.35),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Bubuhkan tanda tangan di sini',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textMuted
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  Consumer<JadwalProvider>(
                    builder: (_, p, __) => ElevatedButton.icon(
                      onPressed: p.loading || _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: p.loading || _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                      label: Text(
                        'Selesaikan Realisasi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
  });

  final _linePaint = Paint()
    ..color = Colors.black
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  final _dotPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill;

  void _drawStrokePoints(Canvas canvas, List<Offset> points) {
    if (points.isEmpty) return;

    if (points.length == 1) {
      canvas.drawCircle(points.first, 1.5, _dotPaint);
      return;
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
    } else {
      for (int i = 1; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }
      path.lineTo(points.last.dx, points.last.dy);
    }

    canvas.drawPath(path, _linePaint);
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
      _drawStrokePoints(canvas, s);
    }
    _drawStrokePoints(canvas, currentStroke);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

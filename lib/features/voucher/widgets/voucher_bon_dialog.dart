// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../models/voucher_model.dart';
import '../providers/voucher_provider.dart';

class VoucherBonDialog extends StatefulWidget {
  final VoucherModel voucher;
  final bool isAdmin;

  const VoucherBonDialog({
    super.key,
    required this.voucher,
    required this.isAdmin,
  });

  static Future<void> show(BuildContext context, {required VoucherModel voucher, required bool isAdmin}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => VoucherBonDialog(voucher: voucher, isAdmin: isAdmin),
    );
  }

  @override
  State<VoucherBonDialog> createState() => _VoucherBonDialogState();
}

class _VoucherBonDialogState extends State<VoucherBonDialog> {
  late TextEditingController _noBonCtrl;
  late TextEditingController _literCtrl;
  int? _selectedSpbuId;
  String? _selectedBbm;
  bool _isEditing = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _noBonCtrl = TextEditingController(text: widget.voucher.voucherNoBon ?? '');
    _literCtrl = TextEditingController(text: widget.voucher.voucherJumlahLiter.toStringAsFixed(1));
    _selectedSpbuId = widget.voucher.voucherSpbuId;
    _selectedBbm = widget.voucher.voucherJenisBbm;
  }

  @override
  void dispose() {
    _noBonCtrl.dispose();
    _literCtrl.dispose();
    super.dispose();
  }

  String _formatTanggal(DateTime dt) {
    const bulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${dt.day} ${bulan[dt.month - 1]} ${dt.year}';
  }

  Future<void> _handleApprove() async {
    final noBon = _noBonCtrl.text.trim();
    if (noBon.isEmpty) {
      AppNotifier.showError(context, 'Harap isi Nomor Bon');
      return;
    }

    final liter = double.tryParse(_literCtrl.text.trim());
    if (liter == null || liter <= 0) {
      AppNotifier.showError(context, 'Jumlah liter tidak valid');
      return;
    }
    if (liter > 100) {
      AppNotifier.showError(context, 'Jumlah liter maksimal 100 liter');
      return;
    }

    setState(() => _isSubmitting = true);
    final p = context.read<VoucherProvider>();
    final success = await p.approveVoucher(
      voucherId: widget.voucher.voucherId,
      noBon: noBon,
      spbuId: _selectedSpbuId,
      jenisBbm: _selectedBbm,
      jumlahLiter: liter,
    );
    setState(() => _isSubmitting = false);

    if (success) {
      AppNotifier.showSuccess(context, 'Voucher berhasil disetujui & nomor bon tercatat');
      Navigator.of(context).pop();
    } else {
      AppNotifier.showError(context, p.errorMessage ?? 'Gagal menyetujui voucher');
    }
  }

  Future<void> _handleReject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Penolakan'),
        content: const Text('Apakah Anda yakin ingin menolak permintaan voucher ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak Permintaan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    final p = context.read<VoucherProvider>();
    final success = await p.rejectVoucher(widget.voucher.voucherId);
    setState(() => _isSubmitting = false);

    if (success) {
      AppNotifier.showSuccess(context, 'Voucher telah ditolak');
      Navigator.of(context).pop();
    } else {
      AppNotifier.showError(context, p.errorMessage ?? 'Gagal menolak voucher');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.voucher.voucherStatus == 'Menunggu';
    final canAdminAction = widget.isAdmin && isPending;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Status Bar Header Dialog
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(widget.voucher.voucherStatus),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStatusIcon(widget.voucher.voucherStatus),
                        size: 18,
                        color: _getStatusTextColor(widget.voucher.voucherStatus),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${widget.voucher.voucherStatus.toUpperCase()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _getStatusTextColor(widget.voucher.voucherStatus),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF475569)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // 2. Kontainer Bon Fisik Kencana Print (Paper Style)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFDFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Kencana Print
                        const Center(
                          child: Text(
                            'KENCANA PRINT',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: 2.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 3,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFF0F172A), width: 1.5),
                              bottom: BorderSide(color: Color(0xFF0F172A), width: 0.8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Center(
                          child: Text(
                            'PERMINTAAN BBM',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Baris No. Pmt / Bon
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 85,
                              child: Text(
                                'No. Pmt',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const Text(':  ', style: TextStyle(fontWeight: FontWeight.w700)),
                            Expanded(
                              child: canAdminAction
                                  ? TextField(
                                      controller: _noBonCtrl,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                        hintText: 'Isi Nomer Bon',
                                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        filled: true,
                                        fillColor: const Color(0xFFFEF3C7),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(4),
                                          borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFB45309),
                                        fontSize: 14,
                                      ),
                                    )
                                  : Text(
                                      widget.voucher.voucherNoBon != null && widget.voucher.voucherNoBon!.isNotEmpty
                                          ? widget.voucher.voucherNoBon!
                                          : '(Belum ada nomor bon)',
                                      style: TextStyle(
                                        fontFamily: 'Courier',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: widget.voucher.voucherNoBon != null
                                            ? const Color(0xFF1E3A8A)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Kepada: SPBU
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 85,
                              child: Text(
                                'Kepada',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const Text(':  ', style: TextStyle(fontWeight: FontWeight.w700)),
                            Expanded(
                              child: _isEditing && canAdminAction
                                  ? Consumer<VoucherProvider>(
                                      builder: (_, p, __) => DropdownButtonFormField<int>(
                                        value: _selectedSpbuId,
                                        isDense: true,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          border: OutlineInputBorder(),
                                        ),
                                        items: p.spbuList.map((s) {
                                          return DropdownMenuItem<int>(
                                            value: s.spbuId,
                                            child: Text(s.spbuNama, style: const TextStyle(fontSize: 13)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedSpbuId = val);
                                        },
                                      ),
                                    )
                                  : Text(
                                      _getSpbuDisplayName(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Keterangan Surat
                        const Text(
                          'Mohon dapat diberikan BBM kepada pembawa surat ini :',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Pembawa Surat / Pemohon
                        _buildPaperRow('Pembawa', widget.voucher.namaPemohon),
                        const SizedBox(height: 8),

                        // No. Pol
                        _buildPaperRow('No. Pol', widget.voucher.noPolisi),
                        const SizedBox(height: 8),

                        // Odometer
                        _buildPaperRow(
                          'Odometer',
                          widget.voucher.voucherOdometer != null
                              ? '${widget.voucher.voucherOdometer} KM'
                              : '-',
                        ),
                        const SizedBox(height: 8),

                        // Berupa (Jenis BBM)
                        Row(
                          children: [
                            const SizedBox(
                              width: 85,
                              child: Text(
                                'Berupa',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const Text(':  ', style: TextStyle(fontWeight: FontWeight.w600)),
                            Expanded(
                              child: _isEditing && canAdminAction
                                  ? Consumer<VoucherProvider>(
                                      builder: (_, p, __) => DropdownButtonFormField<String>(
                                        value: _selectedBbm,
                                        isDense: true,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          border: OutlineInputBorder(),
                                        ),
                                        items: p.bbmTypes.map((t) {
                                          return DropdownMenuItem<String>(
                                            value: t,
                                            child: Text(t, style: const TextStyle(fontSize: 13)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedBbm = val);
                                        },
                                      ),
                                    )
                                  : Text(
                                      _selectedBbm ?? widget.voucher.voucherJenisBbm,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Jumlah Liter
                        Row(
                          children: [
                            const SizedBox(
                              width: 85,
                              child: Text(
                                'Jumlah',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const Text(':  ', style: TextStyle(fontWeight: FontWeight.w600)),
                            Expanded(
                              child: _isEditing && canAdminAction
                                  ? Row(
                                      children: [
                                        SizedBox(
                                          width: 90,
                                          child: TextField(
                                            controller: _literCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                            ],
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              border: OutlineInputBorder(),
                                            ),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Liter', style: TextStyle(fontWeight: FontWeight.w700)),
                                      ],
                                    )
                                  : Text(
                                      _getLiterDisplayName(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // Bagian Tanda Tangan Kanan Bawah
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Surakarta, ${_formatTanggal(widget.voucher.voucherCreatedAt)}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Mengetahui,',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const Text(
                                'KENCANA PRINT',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                widget.voucher.approver != null
                                    ? '( ${widget.voucher.approver!['user_nama']} )'
                                    : '( ................................... )',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tombol toggle edit untuk admin jika perlu menyesuaikan SPBU / Liter
                        if (canAdminAction) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  if (_isEditing) {
                                    final num = double.tryParse(_literCtrl.text.trim());
                                    if (num == null || num <= 0) {
                                      AppNotifier.showError(context, 'Jumlah liter tidak valid');
                                      return;
                                    }
                                    if (num > 100) {
                                      AppNotifier.showError(context, 'Jumlah liter maksimal 100 liter');
                                      return;
                                    }
                                  }
                                  setState(() => _isEditing = !_isEditing);
                                },
                                icon: Icon(_isEditing ? Icons.check_circle_outline : Icons.edit_note_rounded, size: 16),
                                label: Text(
                                  _isEditing ? 'Selesai Sesuaikan' : 'Sesuaikan',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 3. Tombol Aksi Bawah
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: canAdminAction
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSubmitting ? null : _handleReject,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  'Tolak',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _handleApprove,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.check_circle_rounded, size: 18),
                                label: Text(
                                  'Setujui (Simpan No. Bon)',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              'Tutup',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getLiterDisplayName() {
    final val = double.tryParse(_literCtrl.text.trim());
    if (val != null) {
      return '${val.toStringAsFixed(1)} Liter';
    }
    return '${widget.voucher.voucherJumlahLiter.toStringAsFixed(1)} Liter';
  }

  String _getSpbuDisplayName() {
    if (_selectedSpbuId != null) {
      final p = context.read<VoucherProvider>();
      final found = p.spbuList.where((s) => s.spbuId == _selectedSpbuId).toList();
      if (found.isNotEmpty) return found.first.spbuNama;
    }
    return widget.voucher.namaSpbu;
  }

  Widget _buildPaperRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: const Color(0xFF334155),
            ),
          ),
        ),
        const Text(':  ', style: TextStyle(fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Disetujui':
      case 'Selesai':
        return const Color(0xFFDCFCE7);
      case 'Ditolak':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Disetujui':
      case 'Selesai':
        return const Color(0xFF166534);
      case 'Ditolak':
        return const Color(0xFF991B1B);
      default:
        return const Color(0xFF92400E);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Disetujui':
      case 'Selesai':
        return Icons.check_circle_outline_rounded;
      case 'Ditolak':
        return Icons.cancel_outlined;
      default:
        return Icons.access_time_rounded;
    }
  }
}

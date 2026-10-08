// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
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

  static Future<String?> show(
    BuildContext context, {
    required VoucherModel voucher,
    required bool isAdmin,
  }) {
    return showDialog<String>(
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
    _literCtrl = TextEditingController(
        text: widget.voucher.voucherJumlahLiter.toStringAsFixed(1));
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
    return '${dt.day} ${DateFormatter.monthNames[dt.month - 1]} ${dt.year}';
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
      if (mounted) {
        Navigator.of(context).pop('approved');
      }
    } else {
      if (mounted) {
        AppNotifier.showError(
            context, p.errorMessage ?? 'Gagal menyetujui voucher');
      }
    }
  }

  Future<void> _handleReject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Penolakan'),
        content: const Text(
            'Apakah Anda yakin ingin menolak permintaan voucher ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak Permintaan',
                style: TextStyle(color: Colors.white)),
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
      if (mounted) {
        Navigator.of(context).pop('rejected');
      }
    } else {
      if (mounted) {
        AppNotifier.showError(
            context, p.errorMessage ?? 'Gagal menolak voucher');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.voucher.voucherStatus == 'Menunggu';
    final canAdminAction = widget.isAdmin && isPending;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Header Status Bar ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(widget.voucher.voucherStatus),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStatusIcon(widget.voucher.voucherStatus),
                        size: 16,
                        color:
                            _getStatusTextColor(widget.voucher.voucherStatus),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Status: ${widget.voucher.voucherStatus.toUpperCase()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color:
                              _getStatusTextColor(widget.voucher.voucherStatus),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded,
                            size: 19, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // ── 2. Kontainer Bon Fisik Kencana Print (Paper Style) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFDFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Kop Surat Kencana Print
                        const Center(
                          child: Text(
                            'KENCANA PRINT',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Double Border Divider
                        Container(
                          height: 2.5,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: Color(0xFF0F172A), width: 1.2),
                              bottom: BorderSide(
                                  color: Color(0xFF0F172A), width: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            'PERMINTAAN BBM',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Baris No. Pmt / No. Bon
                        _buildRowContainer(
                          label: 'No. Pmt',
                          child: canAdminAction
                              ? TextField(
                                  controller: _noBonCtrl,
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Isi Nomor Bon...',
                                    hintStyle: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8)),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    filled: true,
                                    fillColor: const Color(0xFFFEF3C7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFF59E0B)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFF59E0B)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFD97706), width: 1.5),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'Courier',
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFB45309),
                                    fontSize: 13.5,
                                  ),
                                )
                              : Text(
                                  widget.voucher.voucherNoBon != null &&
                                          widget
                                              .voucher.voucherNoBon!.isNotEmpty
                                      ? widget.voucher.voucherNoBon!
                                      : '(Belum ada nomor bon)',
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: widget.voucher.voucherNoBon != null
                                        ? const Color(0xFF1E3A8A)
                                        : AppColors.textMuted,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 6),

                        // Kepada: SPBU
                        _buildRowContainer(
                          label: 'Kepada',
                          child: _isEditing && canAdminAction
                              ? Consumer<VoucherProvider>(
                                  builder: (_, p, __) =>
                                      DropdownButtonFormField<int>(
                                    value: _selectedSpbuId,
                                    isDense: true,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: p.spbuList.map((s) {
                                      return DropdownMenuItem<int>(
                                        value: s.spbuId,
                                        child: Text(s.spbuNama,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedSpbuId = val);
                                      }
                                    },
                                  ),
                                )
                              : Text(
                                  _getSpbuDisplayName(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),

                        // Keterangan Surat
                        const Text(
                          'Mohon dapat diberikan BBM kepada pembawa surat ini:',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Pembawa (Driver)
                        _buildRowContainer(
                          label: 'Pembawa',
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.voucher.namaPemohon,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.voucher.pemohon?['user_divisi'] !=
                                  null) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.voucher.pemohon!['user_divisi']
                                        .toString(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // No. Pol / Kendaraan
                        _buildRowContainer(
                          label: 'Kendaraan',
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.voucher.namaInventaris,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.voucher.noPolisi,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Odometer
                        _buildRowContainer(
                          label: 'Odometer',
                          child: Text(
                            widget.voucher.voucherOdometer != null
                                ? '${widget.voucher.voucherOdometer} KM'
                                : '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Jenis BBM
                        _buildRowContainer(
                          label: 'Jenis',
                          child: _isEditing && canAdminAction
                              ? Consumer<VoucherProvider>(
                                  builder: (_, p, __) =>
                                      DropdownButtonFormField<String>(
                                    value: _selectedBbm,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: p.bbmTypes.map((t) {
                                      return DropdownMenuItem<String>(
                                        value: t,
                                        child: Text(t,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedBbm = val);
                                      }
                                    },
                                  ),
                                )
                              : Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(4),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        _selectedBbm ??
                                            widget.voucher.voucherJenisBbm,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 6),

                        // Jumlah Liter
                        _buildRowContainer(
                          label: 'Jumlah',
                          child: _isEditing && canAdminAction
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: _literCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*\.?\d*')),
                                        ],
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 5),
                                          border: OutlineInputBorder(),
                                        ),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('Liter',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12)),
                                  ],
                                )
                              : Text(
                                  _getLiterDisplayName(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 14),

                        // Tanda Tangan Kanan Bawah
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Surakarta, ${_formatTanggal(widget.voucher.voucherCreatedAt)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Mengetahui,',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const Text(
                                'KENCANA PRINT',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                widget.voucher.approver != null
                                    ? '( ${widget.voucher.approver!['user_nama']} )'
                                    : '( ................................... )',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tombol Toggle Sesuaikan Data (Khusus Admin Pending)
                        if (canAdminAction) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () {
                                  if (_isEditing) {
                                    final num =
                                        double.tryParse(_literCtrl.text.trim());
                                    if (num == null || num <= 0) {
                                      AppNotifier.showError(
                                          context, 'Jumlah liter tidak valid');
                                      return;
                                    }
                                    if (num > 100) {
                                      AppNotifier.showError(context,
                                          'Jumlah liter maksimal 100 liter');
                                      return;
                                    }
                                  }
                                  setState(() => _isEditing = !_isEditing);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isEditing
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.edit_note_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isEditing
                                            ? 'Selesai Sesuaikan'
                                            : 'Sesuaikan Data',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── 3. Tombol Aksi Bawah ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                  child: canAdminAction
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSubmitting ? null : _handleReject,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side:
                                      const BorderSide(color: AppColors.danger),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  minimumSize: const Size(0, 38),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text(
                                  'Tolak',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isSubmitting ? null : _handleApprove,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  minimumSize: const Size(0, 38),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.check_circle_rounded,
                                        size: 16),
                                label: const Text(
                                  'Setuju',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5),
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
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              minimumSize: const Size(0, 38),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Tutup',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12.5),
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
      final found =
          p.spbuList.where((s) => s.spbuId == _selectedSpbuId).toList();
      if (found.isNotEmpty) return found.first.spbuNama;
    }
    return widget.voucher.namaSpbu;
  }

  Widget _buildRowContainer({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Text(':  ',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.textSecondary)),
        Expanded(child: child),
      ],
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Disetujui':
      case 'Selesai':
        return AppColors.successSoft;
      case 'Ditolak':
        return AppColors.dangerSoft;
      default:
        return AppColors.warningSoft;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Disetujui':
      case 'Selesai':
        return AppColors.success;
      case 'Ditolak':
        return AppColors.danger;
      default:
        return AppColors.warning;
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

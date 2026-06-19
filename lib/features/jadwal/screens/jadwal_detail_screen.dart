import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../features/master/providers/master_provider.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';
import '../widgets/realisasi_detail_sheet.dart';
import '../../../core/widgets/shimmer_loading.dart';

const _kDetailPageBg = Color(0xFFF8FAFC);

class JadwalDetailScreen extends StatefulWidget {
  final int jadwalId;

  const JadwalDetailScreen({super.key, required this.jadwalId});

  @override
  State<JadwalDetailScreen> createState() => _JadwalDetailScreenState();
}

class _JadwalDetailScreenState extends State<JadwalDetailScreen> {
  String _realisasiFilter = 'Semua'; // 'Semua', 'Sudah', 'Belum'
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetailData();
    });
  }

  Future<void> _loadDetailData() async {
    final provider = context.read<JadwalProvider>();
    final master = context.read<MasterProvider>();
    
    await provider.fetchJadwalDetail(widget.jadwalId);
    await provider.fetchRealisasi(jadwalId: widget.jadwalId, status: 'Selesai');
    
    if (master.jenisMaster.isEmpty) {
      await master.fetchJenis();
    }
  }

  Future<void> _openRealisasiDetail(RealisasiModel item) async {
    final provider = context.read<JadwalProvider>();
    await provider.fetchRealisasiDetail(item.realId);
    if (!mounted) return;

    final detail = provider.realisasiDetail;
    if (detail == null) {
      await AppNotifier.showError(context, 'Detail realisasi tidak ditemukan');
      return;
    }

    // Kumpulkan semua realisasi untuk unit inventaris yang sama
    final riwayat = provider.realisasiList
        .where((r) => r.realInvId == item.realInvId && r.realStatus == 'Selesai')
        .toList()
      ..sort((a, b) => b.realTgl.compareTo(a.realTgl)); // terbaru di atas

    await RealisasiDetailSheet.show(
      context,
      detail: detail,
      title: 'Detail Realisasi Unit',
      riwayatRealisasi: riwayat,
      onTapRiwayat: (tappedItem) async {
        Navigator.pop(context); // tutup sheet saat ini
        await _openRealisasiDetail(tappedItem); // buka detail baru
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final master = context.read<MasterProvider>();
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isTablet = AppBreakpoints.isTablet(context);
    final horizontalPadding = isDesktop
        ? 24.0
        : isTablet
            ? 20.0
            : 16.0;
    final maxContentWidth = isDesktop ? 1180.0 : 860.0;

    return Scaffold(
      backgroundColor: _kDetailPageBg,
      appBar: AppBar(title: const Text('Detail Jadwal')),
      body: Consumer<JadwalProvider>(
        builder: (_, provider, __) {
          if (provider.loading) {
            return _buildSkeleton(isDesktop, horizontalPadding);
          }

          final jadwal = provider.jadwalDetail;
          if (jadwal == null) {
            return const EmptyState(message: 'Detail jadwal tidak ditemukan');
          }

          final jenisNama = jadwal.jdwInvJenis ??
              master.jenisById(jadwal.jdwJenisId)?.jenisNama ??
              'ID ${jadwal.jdwJenisId}';
          final targetUnit = jadwal.jdwTarget ?? jadwal.jdwTotalUnit ?? 0;
          final selesaiUnit = jadwal.jdwSelesaiUnit ?? 0;
          final progressPct =
              targetUnit > 0 ? (selesaiUnit / targetUnit * 100).round() : 0;
          final selesaiInvIds = provider.realisasiList
              .where((item) => item.realStatus == 'Selesai')
              .map((item) => item.realInvId)
              .toSet();

          return RefreshIndicator(
            onRefresh: _loadDetailData,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 16, horizontalPadding, 28),
                  children: [
                    _buildHeroCard(
                      context,
                      jadwal: jadwal,
                      jenisNama: jenisNama,
                      progressPct: progressPct,
                      targetUnit: targetUnit,
                      selesaiUnit: selesaiUnit,
                      master: master,
                    ),
                    const SizedBox(height: 16),
                    _buildStatsRow(
                      targetUnit: targetUnit,
                      selesaiUnit: selesaiUnit,
                      totalUnit: jadwal.jdwTotalUnit ?? 0,
                      daysRemaining: jadwal.jdwDaysRemaining,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoSection(
                      context,
                      jadwal: jadwal,
                      jenisNama: jenisNama,
                      master: master,
                      progressPct: progressPct,
                    ),
                    const SizedBox(height: 16),
                    _buildInventarisSection(
                      context,
                      jadwal: jadwal,
                      selesaiInvIds: selesaiInvIds,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required JadwalModel jadwal,
    required String jenisNama,
    required int progressPct,
    required int targetUnit,
    required int selesaiUnit,
    required MasterProvider master,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_note_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jadwal.jdwJudul,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$jenisNama · ${jadwal.jdwFrekuensi} · ${_displayPabrikList(master, jadwal.jdwPabrikList)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _heroMetric(
                          'Target',
                          '$targetUnit unit',
                        ),
                      ),
                      Expanded(
                        child: _heroMetric(
                          'Realisasi',
                          '$selesaiUnit unit',
                        ),
                      ),
                      Expanded(
                        child: _heroMetric(
                          'Capaian',
                          '$progressPct%',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: targetUnit > 0
                          ? (selesaiUnit / targetUnit).clamp(0.0, 1.0)
                          : 0,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow({
    required int targetUnit,
    required int selesaiUnit,
    required int totalUnit,
    required int? daysRemaining,
  }) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.flag_outlined,
            label: 'Target',
            value: '$targetUnit',
            accent: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.done_all_outlined,
            label: 'Realisasi',
            value: '$selesaiUnit',
            accent: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.inventory_2_outlined,
            label: 'Inventaris',
            value: '$totalUnit',
            accent: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.schedule_outlined,
            label: 'Hari Lagi',
            value: daysRemaining?.toString() ?? '-',
            accent: const Color(0xFFF97316),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required JadwalModel jadwal,
    required String jenisNama,
    required MasterProvider master,
    required int progressPct,
  }) {
    final jenisGapHari =
        master.jenisById(jadwal.jdwJenisId)?.jenisGapHari ?? 0;
    final jadwalGapHari = jadwal.jdwGapHari;
    final showJadwalGap =
        jadwal.jdwFrekuensi == 'Mingguan' || jadwal.jdwFrekuensi == 'Bulanan';

    return _sectionCard(
      title: 'Informasi Jadwal',
      subtitle: 'Detail konfigurasi dan periode jadwal',
      child: Column(
        children: [
          _infoRow('Jenis Inventaris', jenisNama),
          _infoRow('Divisi', jadwal.jdwDivisi),
          _infoRow('Pelaksana', jadwal.assignedNama),
          _infoRow('Pabrik', _displayPabrikList(master, jadwal.jdwPabrikList)),
          _infoRow('Awal Periode Jadwal',
              _displayDate(jadwal.jdwCurrentPeriodStart)),
          if (jadwal.jdwTglSelesai != null)
            _infoRow(
              'Akhir Periode Jadwal',
              DateFormatter.toDisplay(jadwal.jdwTglSelesai),
            ),
          _infoRow('Jadwal berikutnya', _displayDate(jadwal.jdwNextDueDate)),
          _infoRow('Capaian Per Jadwal', '$progressPct%'),
          if (jadwal.jdwNotes != null && jadwal.jdwNotes!.trim().isNotEmpty)
            _infoRow('Catatan', jadwal.jdwNotes!),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Divider(height: 1),
          ),
          // ── Kartu Gap Jadwal ──────────────────────────────────
          if (showJadwalGap)
            _gapCard(
              icon: Icons.timelapse_outlined,
              title: 'Gap Jadwal',
              subtitle: jadwalGapHari == 0
                  ? 'Tidak ada jeda — jadwal dapat direalisasikan kapan saja.'
                  : 'Realisasi jeda $jadwalGapHari hari per ${jadwal.jdwFrekuensi}.',
              note: jadwalGapHari > 0
                  ? '⚠ Dengan gap > 0 dan target banyak unit, pastikan jadwal tidak terblokir. '
                      'Pertimbangkan set 0 jika menargetkan banyak unit sekaligus.'
                  : null,
              color: jadwalGapHari > 0
                  ? const Color(0xFFF97316)
                  : const Color(0xFF16A34A),
              bgColor: jadwalGapHari > 0
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFF0FDF4),
              borderColor: jadwalGapHari > 0
                  ? const Color(0xFFFED7AA)
                  : const Color(0xFFBBF7D0),
            ),
          if (showJadwalGap) const SizedBox(height: 10),
          // ── Kartu Gap per Mesin ───────────────────────────────
          _gapCard(
            icon: Icons.schedule_outlined,
            title: 'Gap per Mesin (dari Jenis)',
            subtitle: jenisGapHari == 0
                ? 'Tidak ada jeda — mesin yang sama bisa di-maintenance kapan saja.'
                : 'Mesin yang sama dapat di-maintenance dengan jeda $jenisGapHari hari.',
            note: null,
            color: jenisGapHari > 0
                ? AppColors.primary
                : AppColors.textSecondary,
            bgColor: jenisGapHari > 0
                ? AppColors.primary.withValues(alpha: 0.06)
                : const Color(0xFFF8FAFC),
            borderColor: jenisGapHari > 0
                ? AppColors.primary.withValues(alpha: 0.2)
                : const Color(0xFFE2E8F0),
          ),
        ],
      ),
    );
  }

  Widget _gapCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String? note,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      height: 1.4,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFC2410C),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFilterPills() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(label: 'Semua', value: 'Semua'),
            const SizedBox(width: 8),
            _filterChip(label: 'Sudah Terealisasi', value: 'Sudah'),
            const SizedBox(width: 8),
            _filterChip(label: 'Belum Terealisasi', value: 'Belum'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({required String label, required String value}) {
    final isSelected = _realisasiFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _realisasiFilter = value;
          });
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.12),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: 1,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildInventarisSection(
    BuildContext context, {
    required JadwalModel jadwal,
    required Set<int> selesaiInvIds,
  }) {
    final provider = context.read<JadwalProvider>();
    final master = context.read<MasterProvider>();
    final jenisNama =
        master.jenisById(jadwal.jdwJenisId)?.jenisNama ??
            'ID ${jadwal.jdwJenisId}';

    final filteredList = provider.inventarisByJenis.where((inv) {
      final invIdRaw = inv['inv_id'];
      final invId =
          invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');
      final sudahTerealisasi = invId != null && selesaiInvIds.contains(invId);

      if (_realisasiFilter == 'Sudah') {
        return sudahTerealisasi;
      } else if (_realisasiFilter == 'Belum') {
        return !sudahTerealisasi;
      }
      return true;
    }).toList();

    return _sectionCard(
      title: 'Unit Inventaris $jenisNama',
      subtitle: 'Total unit: ${provider.inventarisByJenis.length}',
      child: provider.inventarisByJenis.isEmpty
          ? const EmptyState(message: 'Belum ada inventaris untuk jadwal ini')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterPills(),
                if (filteredList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text(
                        'Tidak ada unit yang cocok dengan filter "${_realisasiFilter == 'Sudah' ? 'Sudah Terealisasi' : 'Belum Terealisasi'}".',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ...filteredList.map((inv) {
                    final invIdRaw = inv['inv_id'];
                    final invId =
                        invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');
                    final isGapEligible = inv['inv_is_gap_eligible'] != false;
                    final nextEligibleDate = inv['inv_next_eligible_date']?.toString();
                    final sudahTerealisasi =
                        invId != null && selesaiInvIds.contains(invId);
                    final merk = (inv['inv_merk'] ?? '-').toString();
                    final pic = (inv['inv_pic'] ?? '-').toString();
                    RealisasiModel? realisasiItem;

                    if (invId != null) {
                      for (final item in provider.realisasiList) {
                        if (item.realInvId == invId &&
                            item.realStatus == 'Selesai') {
                          realisasiItem = item;
                          break;
                        }
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (inv['inv_nama'] ?? '-').toString(),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${inv['inv_serial_number'] ?? inv['inv_no'] ?? '-'} · ${master.displayPabrik(inv['inv_pabrik_kode']?.toString())}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            _infoChip(
                                              icon:
                                                  Icons.branding_watermark_outlined,
                                              text: 'Merk: $merk',
                                            ),
                                            _infoChip(
                                              icon: Icons.person_outline,
                                              text: 'PIC: $pic',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    sudahTerealisasi
                                        ? Icons.check_circle_outline
                                        : (!isGapEligible
                                            ? Icons.error_outline_rounded
                                            : Icons.schedule_outlined),
                                    size: 14,
                                    color: sudahTerealisasi
                                        ? AppColors.success
                                        : (!isGapEligible
                                            ? Colors.orange.shade700
                                            : AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    sudahTerealisasi
                                        ? 'Sudah terealisasi'
                                        : (!isGapEligible
                                            ? 'Belum layak (Jeda hingga: ${_displayDate(nextEligibleDate)})'
                                            : 'Belum terealisasi'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: sudahTerealisasi
                                          ? AppColors.success
                                          : (!isGapEligible
                                              ? Colors.orange.shade700
                                              : AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                              if (sudahTerealisasi && realisasiItem != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.event_outlined,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Realisasi Terakhir: ${_displayDate(realisasiItem.realTgl)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Direalisasikan oleh: ${(realisasiItem.teknisi?['user_nama'] ?? '-').toString()}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: sudahTerealisasi && realisasiItem != null
                                    ? OutlinedButton.icon(
                                        onPressed: () =>
                                            _openRealisasiDetail(realisasiItem!),
                                        icon: const Icon(Icons.visibility_outlined,
                                            size: 16),
                                        label: const Text('Lihat Detail'),
                                      )
                                    : const Text(
                                        'Menunggu realisasi',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  String _displayPabrikList(MasterProvider master, List<String> codes) {
    if (codes.isEmpty) return '-';
    return codes.map((c) => master.displayPabrik(c)).join(', ');
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgGray,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _displayDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    return DateFormatter.toDisplay(raw);
  }

  Widget _buildSkeleton(bool isDesktop, double horizontalPadding) {
    return AppShimmer(
      child: ListView(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 28),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // 1. Hero Card Placeholder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonSquircle(width: 44, height: 44, borderRadius: 12),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeletonLine(width: 180, height: 18),
                          SizedBox(height: 8),
                          AppSkeletonLine(width: 120, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border.withOpacity(0.2)),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          AppSkeletonLine(width: 50, height: 14),
                          AppSkeletonLine(width: 50, height: 14),
                          AppSkeletonLine(width: 50, height: 14),
                        ],
                      ),
                      SizedBox(height: 12),
                      AppSkeletonSquircle(width: double.infinity, height: 10, borderRadius: 99),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 2. Stats Row Placeholder
          Row(
            children: List.generate(4, (index) => const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: AppSkeletonSquircle(width: double.infinity, height: 60, borderRadius: 12),
              ),
            )),
          ),
          const SizedBox(height: 16),
          // 3. Info Section Card Placeholder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeletonLine(width: 140, height: 16),
                const SizedBox(height: 6),
                const AppSkeletonLine(width: 180, height: 12),
                const SizedBox(height: 20),
                ...List.generate(5, (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppSkeletonLine(width: 100, height: 14),
                      AppSkeletonLine(width: 120, height: 14),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 4. Inventaris Section Placeholder (1-2 item list card placeholders)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeletonLine(width: 160, height: 16),
                const SizedBox(height: 6),
                const AppSkeletonLine(width: 100, height: 12),
                const SizedBox(height: 16),
                ...List.generate(2, (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      AppSkeletonSquircle(width: 40, height: 40, borderRadius: 12),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSkeletonLine(width: 150, height: 14),
                            SizedBox(height: 6),
                            AppSkeletonLine(width: 100, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

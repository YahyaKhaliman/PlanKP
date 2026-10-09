import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/responsive_sheet.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/master/providers/master_provider.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';
import '../widgets/realisasi_detail_sheet.dart';
import '../widgets/renew_jadwal_sheet.dart';


const _kDetailPageBg = AppColors.surface;

class JadwalDetailScreen extends StatefulWidget {
  final int jadwalId;

  const JadwalDetailScreen({super.key, required this.jadwalId});

  @override
  State<JadwalDetailScreen> createState() => _JadwalDetailScreenState();
}

class _JadwalDetailScreenState extends State<JadwalDetailScreen> {
  String _realisasiFilter = 'Semua'; // 'Semua', 'Sudah', 'Belum'
  bool _isInitialLoading = true;

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

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

    try {
      await Future.wait([
        provider.fetchJadwalDetail(widget.jadwalId),
        provider.fetchRealisasi(jadwalId: widget.jadwalId, status: 'Selesai'),
        if (master.inventarisList.isEmpty) master.fetchInventaris(showLoading: false),
        if (master.jenisMaster.isEmpty) master.fetchJenis(showLoading: false),
        if (master.userList.isEmpty) master.fetchUsers(showLoading: false),
      ]);
    } catch (_) {
      // Error tercatat di provider
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
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

    final riwayat = provider.realisasiList
        .where(
            (r) => r.realInvId == item.realInvId && r.realStatus == 'Selesai')
        .toList()
      ..sort((a, b) => b.realTgl.compareTo(a.realTgl));

    await RealisasiDetailSheet.show(
      context,
      detail: detail,
      title: 'Detail Realisasi Unit',
      riwayatRealisasi: riwayat,
      onTapRiwayat: (tappedItem) async {
        Navigator.pop(context);
        await _openRealisasiDetail(tappedItem);
      },
    );
  }

  void _openRenewJadwal(JadwalModel item) {
    final master = context.read<MasterProvider>();
    final auth = context.read<AuthProvider>();
    master.fetchJenis(showLoading: false);
    master.fetchPabrik();
    final role = auth.user?['user_jabatan'];
    final isManager = role == 'manager';
    final userDivisi = isManager ? null : (auth.user?['user_divisi'] ?? '');
    master.fetchUsers(divisi: userDivisi, showLoading: false);

    showResponsiveSheet(
      context,
      maxDesktopWidth: 560,
      builder: (_) => RenewJadwalSheet(
        jadwal: item,
        onRenewSuccess: () => _loadDetailData(),
      ),
    );
  }

  Future<void> _updateStatus(String status, String title, String message) async {
    await AppNotifier.showConfirm(
      context,
      title: title,
      message: message,
      onConfirm: () async {
        final ok = await context
            .read<JadwalProvider>()
            .updateStatusJadwal(widget.jadwalId, status);
        if (ok && mounted) {
          await AppNotifier.showSuccess(context, 'Status jadwal berhasil diubah');
          _loadDetailData();
        }
      },
    );
  }

  Future<void> _confirmAktifkanJadwal(JadwalModel jadwal) => _updateStatus(
        'Aktif',
        'Aktifkan Jadwal',
        'Aktifkan jadwal "${jadwal.jdwJudul}" agar dapat mulai dikerjakan teknisi?',
      );

  Future<void> _confirmSelesaikanJadwal(JadwalModel jadwal) => _updateStatus(
        'Selesai',
        'Selesaikan Jadwal',
        'Tandai jadwal "${jadwal.jdwJudul}" sebagai Selesai?',
      );

  Future<void> _confirmBatalkanJadwal(JadwalModel jadwal) => _updateStatus(
        'Dibatalkan',
        'Batalkan Jadwal',
        'Batalkan jadwal "${jadwal.jdwJudul}"?\nJadwal yang dibatalkan tidak akan muncul di teknisi dan tidak dihitung dalam target.',
      );

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
          if (_isInitialLoading || provider.loading) {
            return _buildSkeleton(isDesktop, horizontalPadding);
          }

          final JadwalModel? jadwal = (provider.jadwalDetail != null &&
                  provider.jadwalDetail!.jdwId == widget.jadwalId)
              ? provider.jadwalDetail
              : provider.jadwalList
                  .where((j) => j.jdwId == widget.jadwalId)
                  .firstOrNull;

          if (jadwal == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.event_busy_rounded,
                        size: 40,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Detail Jadwal Tidak Ditemukan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.error ??
                          (widget.jadwalId <= 0
                              ? 'ID Jadwal tidak valid atau halaman telah di-refresh. Silakan kembali ke menu Jadwal.'
                              : 'Jadwal #${widget.jadwalId} belum tersedia atau terjadi kendala saat memuat data.'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size(100, 38),
                          ),
                          child: Text(
                            'Kembali',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _isInitialLoading = true);
                            _loadDetailData();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(
                            'Coba Lagi',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(110, 38),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          final jenisNama = jadwal.jdwInvJenis ??
              master.jenisById(jadwal.jdwJenisId)?.jenisNama ??
              'ID ${jadwal.jdwJenisId}';
          final now = DateTime.now();
          final startDate = DateTime.tryParse(jadwal.jdwTglMulai) ?? now;
          final effectiveNextDueStr = jadwal.effectiveNextDueDateStr;
          final nextDueParsed = effectiveNextDueStr != null
              ? DateTime.tryParse(effectiveNextDueStr)
              : null;
          final rangeEnd = (nextDueParsed != null && nextDueParsed.isAfter(now))
              ? nextDueParsed
              : now;

          final holidayDays = provider.getHolidayDaysForMonth(now);
          final scheduleDatesInRange = JadwalProvider.effectiveScheduleDatesInMonth(
              jadwal, _dateOnly(startDate), _dateOnly(rangeEnd), holidayDays);

          final perTarget = (jadwal.jdwTarget ?? 0) > 0
              ? jadwal.jdwTarget!
              : ((jadwal.jdwTotalUnit ?? 0) > 0 ? jadwal.jdwTotalUnit! : 1);
          final targetUnitInRange = scheduleDatesInRange.isNotEmpty
              ? scheduleDatesInRange.length * perTarget
              : perTarget;

          final currentPeriodRealisasi = provider.realisasiList.where((item) {
            if (item.realStatus != 'Selesai') return false;
            final rDate = DateTime.tryParse(item.realTgl);
            if (rDate == null) return false;
            final normR = _dateOnly(rDate);
            return !normR.isBefore(_dateOnly(startDate)) &&
                !normR.isAfter(_dateOnly(rangeEnd));
          }).toList();

          final selesaiInvIds = currentPeriodRealisasi
              .map((item) => item.realInvId)
              .toSet();
          final selesaiUnit = currentPeriodRealisasi.length;
          final targetUnit = targetUnitInRange > 0
              ? targetUnitInRange
              : (jadwal.jdwTarget ?? jadwal.jdwTotalUnit ?? 1);
          final progressPct = targetUnit > 0
              ? (selesaiUnit / targetUnit * 100).round().clamp(0, 100)
              : 0;

          return RefreshIndicator(
            onRefresh: _loadDetailData,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 16, horizontalPadding, 28),
                  children: [
                    _buildSummaryCard(
                      context,
                      jadwal: jadwal,
                      jenisNama: jenisNama,
                      progressPct: progressPct,
                      targetUnit: targetUnit,
                      selesaiUnit: selesaiUnit,
                      totalUnit: jadwal.jdwTotalUnit ?? 0,
                      master: master,
                    ),
                    const SizedBox(height: 14),
                    _buildInfoSection(
                      context,
                      jadwal: jadwal,
                      jenisNama: jenisNama,
                      master: master,
                      progressPct: progressPct,
                    ),
                    const SizedBox(height: 14),
                    _buildInventarisSection(
                      context,
                      jadwal: jadwal,
                      selesaiInvIds: selesaiInvIds,
                      currentPeriodRealisasi: currentPeriodRealisasi,
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

  Widget _buildSummaryCard(
    BuildContext context, {
    required JadwalModel jadwal,
    required String jenisNama,
    required int progressPct,
    required int targetUnit,
    required int selesaiUnit,
    required int totalUnit,
    required MasterProvider master,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title & Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (context) {
                final divisiColor = AppDivisiColors.getColor(jadwal.jdwDivisi);
                final divisiIcon = AppDivisiColors.getIcon(jadwal.jdwDivisi);
                return Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: divisiColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    divisiIcon,
                    color: divisiColor,
                    size: 22,
                  ),
                );
              }),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jadwal.jdwJudul,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Builder(builder: (context) {
                          final divisiColor = AppDivisiColors.getColor(jadwal.jdwDivisi);
                          final divisiIcon = AppDivisiColors.getIcon(jadwal.jdwDivisi);
                          return _badgeChip(
                            icon: divisiIcon,
                            label: jadwal.jdwDivisi.toUpperCase(),
                            bgColor: divisiColor.withValues(alpha: 0.12),
                            textColor: divisiColor,
                          );
                        }),
                        _badgeChip(
                          icon: Icons.repeat_rounded,
                          label: jadwal.jdwFrekuensi,
                          bgColor: AppColors.primarySoft,
                          textColor: AppColors.primary,
                        ),
                        _badgeChip(
                          icon: Icons.category_outlined,
                          label: jenisNama,
                          bgColor: AppColors.surfaceAlt,
                          textColor: AppColors.textSecondary,
                        ),
                        _badgeChip(
                          icon: Icons.factory_outlined,
                          label: _displayPabrikList(master, jadwal.jdwPabrikList),
                          bgColor: AppColors.surfaceAlt,
                          textColor: AppColors.textSecondary,
                        ),
                        Builder(builder: (context) {
                          Color bg;
                          Color fg;
                          switch (jadwal.jdwStatus) {
                            case 'Aktif':
                              bg = const Color(0xFFDCFCE7);
                              fg = const Color(0xFF15803D);
                              break;
                            case 'Draft':
                              bg = const Color(0xFFFEF3C7);
                              fg = const Color(0xFFB45309);
                              break;
                            case 'Selesai':
                              bg = const Color(0xFFE2E8F0);
                              fg = const Color(0xFF475569);
                              break;
                            case 'Dibatalkan':
                              bg = const Color(0xFFFEE2E2);
                              fg = const Color(0xFFB91C1C);
                              break;
                            default:
                              bg = AppColors.surfaceAlt;
                              fg = AppColors.textSecondary;
                          }
                          return _badgeChip(
                            icon: Icons.flag_outlined,
                            label: jadwal.jdwStatus,
                            bgColor: bg,
                            textColor: fg,
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress & Compact Bar Stats Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Capaian Target',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$progressPct%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: progressPct >= 100
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                          TextSpan(
                            text: ' ($selesaiUnit dari $targetUnit unit)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: targetUnit > 0
                        ? (selesaiUnit / targetUnit).clamp(0.0, 1.0)
                        : 0,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPct >= 100
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _compactBarStat(
                        icon: Icons.inventory_2_outlined,
                        label: 'Total Unit',
                        value: '$totalUnit Unit',
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                    Container(height: 18, width: 1, color: AppColors.border),
                    Expanded(
                      child: _compactBarStat(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'Mulai',
                        value: _displayDate(jadwal.jdwTglMulai),
                        color: AppColors.primary,
                      ),
                    ),
                    Container(height: 18, width: 1, color: AppColors.border),
                    Expanded(
                      child: _compactBarStat(
                        icon: Icons.event_available_outlined,
                        label: 'Selesai',
                        value: (jadwal.jdwTglSelesai != null && jadwal.jdwTglSelesai!.trim().isNotEmpty)
                            ? _displayDate(jadwal.jdwTglSelesai)
                            : 'Tanpa Batas',
                        color: (jadwal.jdwTglSelesai != null && jadwal.jdwTglSelesai!.trim().isNotEmpty)
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (context.watch<AuthProvider>().user?['user_jabatan'] ==
                    'admin') ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (jadwal.jdwStatus == 'Draft' ||
                          jadwal.jdwStatus == 'Dibatalkan')
                        _adminActionBtn(
                          icon: Icons.play_arrow_rounded,
                          label: 'Aktifkan',
                          color: AppColors.success,
                          onTap: () => _confirmAktifkanJadwal(jadwal),
                        ),
                      if (jadwal.jdwStatus == 'Aktif') ...[
                        _adminActionBtn(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Selesaikan',
                          color: AppColors.primary,
                          onTap: () => _confirmSelesaikanJadwal(jadwal),
                        ),
                        _adminActionBtn(
                          icon: Icons.event_busy_outlined,
                          label: 'Batalkan',
                          color: AppColors.danger,
                          onTap: () => _confirmBatalkanJadwal(jadwal),
                        ),
                      ],
                      if (jadwal.jdwStatus == 'Selesai')
                        _adminActionBtn(
                          icon: Icons.autorenew_rounded,
                          label: 'Renew',
                          color: const Color(0xFF7C3AED),
                          onTap: () => _openRenewJadwal(jadwal),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactBarStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _badgeChip({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
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

    final infoItems = [
      _InfoItem(
          icon: Icons.category_outlined,
          label: 'Jenis Inventaris',
          value: jenisNama),
      _InfoItem(
          icon: Icons.business_outlined,
          label: 'Divisi',
          value: jadwal.jdwDivisi.isEmpty ? '-' : jadwal.jdwDivisi),
      _InfoItem(
          icon: Icons.person_outline,
          label: 'Pelaksana',
          value: jadwal.assignedNama),
      _InfoItem(
          icon: Icons.factory_outlined,
          label: 'Pabrik',
          value: _displayPabrikList(master, jadwal.jdwPabrikList)),
      _InfoItem(
          icon: Icons.calendar_today_outlined,
          label: 'Mulai Jadwal',
          value: DateFormatter.toDisplay(jadwal.jdwTglMulai)),
      if (jadwal.jdwTglSelesai != null)
        _InfoItem(
            icon: Icons.event_available_outlined,
            label: 'Akhir Periode',
            value: DateFormatter.toDisplay(jadwal.jdwTglSelesai)),
      _InfoItem(
          icon: Icons.update_outlined,
          label: 'Jadwal Berikutnya',
          value: _displayDate(jadwal.effectiveNextDueDateStr)),
      _InfoItem(
          icon: Icons.pie_chart_outline,
          label: 'Presentase Realisasi',
          value: '$progressPct%'),
    ];

    return _sectionCard(
      title: 'Informasi Jadwal',
      subtitle: 'Konfigurasi dan periode pelaksanaan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 520;
              if (isWide) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: infoItems.map((item) {
                    return SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _compactInfoCell(item),
                    );
                  }).toList(),
                );
              } else {
                return Column(
                  children: infoItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _compactInfoCell(item),
                    );
                  }).toList(),
                );
              }
            },
          ),
          if (jadwal.jdwNotes != null &&
              jadwal.jdwNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Catatan: ${jadwal.jdwNotes}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          // Gap Cards
          if (showJadwalGap)
            _gapCard(
              icon: Icons.timelapse_outlined,
              title: 'Gap Jadwal',
              subtitle: jadwalGapHari == 0
                  ? 'Tidak ada gap — jadwal dapat direalisasikan kapan saja.'
                  : 'Realisasi gap $jadwalGapHari hari per ${jadwal.jdwFrekuensi}.',
              note: jadwalGapHari > 0
                  ? 'Dengan gap > 0 dan target banyak unit, pastikan jadwal tidak terblokir. '
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
          if (showJadwalGap) const SizedBox(height: 8),
          _gapCard(
            icon: Icons.schedule_outlined,
            title: 'Gap Jenis Inventaris',
            subtitle: jenisGapHari == 0
                ? 'Tidak ada gap — inventaris yang sama bisa di-maintenance kapan saja.'
                : 'Inventaris yang sama dapat di-maintenance dengan gap $jenisGapHari hari.',
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

  Widget _compactInfoCell(_InfoItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
    return Container(
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: color,
                    height: 1.35,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFFC2410C),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPills(int countTotal, int countSudah, int countBelum) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(label: 'Semua ($countTotal)', value: 'Semua'),
            const SizedBox(width: 8),
            _filterChip(
                label: 'Sudah Perawatan ($countSudah)', value: 'Sudah'),
            const SizedBox(width: 8),
            _filterChip(
                label: 'Belum Perawatan ($countBelum)', value: 'Belum'),
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
      selectedColor: AppColors.primarySoft,
      backgroundColor: AppColors.cardSurface,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
    required List<RealisasiModel> currentPeriodRealisasi,
  }) {
    final provider = context.read<JadwalProvider>();
    final master = context.read<MasterProvider>();
    final jenisNama = master.jenisById(jadwal.jdwJenisId)?.jenisNama ??
        'ID ${jadwal.jdwJenisId}';

    final List<Map<String, dynamic>> effectiveInventarisList =
        provider.inventarisByJenis.isNotEmpty
            ? provider.inventarisByJenis
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : master.inventarisList
                .where((inv) =>
                    inv.invJenisId == jadwal.jdwJenisId &&
                    (jadwal.jdwPabrikList.isEmpty ||
                        jadwal.jdwPabrikList.contains(inv.invPabrikKode)))
                .map((inv) => <String, dynamic>{
                      'inv_id': inv.invId,
                      'inv_nama': inv.invNama,
                      'inv_no': inv.invNo,
                      'inv_merk': inv.invMerk,
                      'inv_pic': inv.invPic,
                      'inv_serial_number': inv.invSerialNumber,
                      'inv_pabrik_kode': inv.invPabrikKode,
                      'inv_is_active': inv.invIsActive,
                    })
                .toList();

    final totalCount = effectiveInventarisList.length;
    final bool hasGapRule = jadwal.jdwGapHari > 0;

    bool isUnitDone(Map<String, dynamic> inv) {
      final invIdRaw = inv['inv_id'];
      final invId = invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');
      final sisaHari = (inv['inv_gap_sisa_hari'] as num?)?.toInt() ?? 0;
      final bool unitHasGap = hasGapRule || inv['inv_gap_sisa_hari'] != null;

      if (unitHasGap) {
        if (sisaHari > 0 || inv['inv_is_gap_eligible'] == false) {
          return true; // Masih dalam masa jeda gap siklus ini
        }
        // Siklus gap sudah berakhir: hanya sudah selesai jika ada realisasi baru di siklus ini
        return invId != null && selesaiInvIds.contains(invId);
      } else {
        return (invId != null && selesaiInvIds.contains(invId)) ||
            inv['inv_is_done_current_period'] == true;
      }
    }

    int sudahCount = 0;
    for (final inv in effectiveInventarisList) {
      if (isUnitDone(inv)) {
        sudahCount++;
      }
    }
    final belumCount = totalCount - sudahCount;

    final filteredList = effectiveInventarisList.where((inv) {
      final sudahTerealisasi = isUnitDone(inv);

      if (_realisasiFilter == 'Sudah') {
        return sudahTerealisasi;
      } else if (_realisasiFilter == 'Belum') {
        return !sudahTerealisasi;
      }
      return true;
    }).toList();

    return _sectionCard(
      title: 'Unit Inventaris $jenisNama',
      subtitle: 'Total: $totalCount unit inventaris',
      child: effectiveInventarisList.isEmpty
          ? const EmptyState(message: 'Belum ada inventaris untuk jadwal ini')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterPills(totalCount, sudahCount, belumCount),
                if (filteredList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Tidak ada unit yang cocok dengan filter "${_realisasiFilter == 'Sudah' ? 'Sudah Perawatan' : 'Belum Perawatan'}".',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final inv = filteredList[index];
                      final invIdRaw = inv['inv_id'];
                      final invId = invIdRaw is int
                          ? invIdRaw
                          : int.tryParse('$invIdRaw');
                      final isGapEligible =
                          inv['inv_is_gap_eligible'] != false;
                      final nextEligibleDate =
                          inv['inv_next_eligible_date']?.toString();
                      final sudahTerealisasi = isUnitDone(inv);
                      final merk = (inv['inv_merk'] ?? '-').toString();
                      final pic = (inv['inv_pic'] ?? '-').toString();
                      RealisasiModel? realisasiItem;

                      if (invId != null) {
                        for (final item in currentPeriodRealisasi) {
                          if (item.realInvId == invId) {
                            realisasiItem = item;
                            break;
                          }
                        }
                      }

                      return _buildInventarisItemCard(
                        inv: inv,
                        sudahTerealisasi: sudahTerealisasi,
                        isGapEligible: isGapEligible,
                        nextEligibleDate: nextEligibleDate,
                        merk: merk,
                        pic: pic,
                        realisasiItem: realisasiItem,
                        master: master,
                        onTapDetail: realisasiItem != null
                            ? () => _openRealisasiDetail(realisasiItem!)
                            : null,
                      );
                    },
                  ),
              ],
            ),
    );
  }

  Widget _buildInventarisItemCard({
    required Map<String, dynamic> inv,
    required bool sudahTerealisasi,
    required bool isGapEligible,
    required String? nextEligibleDate,
    required String merk,
    required String pic,
    required RealisasiModel? realisasiItem,
    required MasterProvider master,
    required VoidCallback? onTapDetail,
  }) {
    final statusColor = sudahTerealisasi
        ? const Color(0xFF16A34A)
        : (!isGapEligible
            ? const Color(0xFFD97706)
            : AppColors.textSecondary);

    final statusBg = sudahTerealisasi
        ? const Color(0xFFF0FDF4)
        : (!isGapEligible
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFF8FAFC));

    final statusBorder = sudahTerealisasi
        ? const Color(0xFFBBF7D0)
        : (!isGapEligible
            ? const Color(0xFFFED7AA)
            : const Color(0xFFE2E8F0));

    final statusText = sudahTerealisasi
        ? 'Sudah Perawatan'
        : (!isGapEligible
            ? 'Belum Layak (Jeda s/d ${_displayDate(nextEligibleDate)})'
            : 'Belum Perawatan');

    final statusIcon = sudahTerealisasi
        ? Icons.check_circle_rounded
        : (!isGapEligible
            ? Icons.error_outline_rounded
            : Icons.schedule_rounded);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: sudahTerealisasi
              ? const Color(0xFFBBF7D0)
              : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusBorder),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (inv['inv_nama'] ?? '-').toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inv['inv_serial_number'] ?? inv['inv_no'] ?? '-'} · ${master.displayPabrik(inv['inv_pabrik_kode']?.toString())}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Chips Row
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _infoChip(
                icon: Icons.branding_watermark_outlined,
                text: 'Merk: $merk',
              ),
              _infoChip(
                icon: Icons.person_outline,
                text: 'PIC: $pic',
              ),
            ],
          ),
          if (sudahTerealisasi && realisasiItem != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Maintenance: ${_displayDate(realisasiItem.realTgl)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF15803D),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pelaksana: ${_displayTeknisi(master, realisasiItem)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: onTapDetail,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: Color(0xFF86EFAC)),
                        backgroundColor: Colors.white,
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.visibility_outlined,
                          size: 14, color: Color(0xFF15803D)),
                      label: Text(
                        'Lihat Detail',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF15803D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _displayPabrikList(MasterProvider master, List<String> codes) {
    if (codes.isEmpty) return '-';
    return codes.map((c) => master.displayPabrik(c)).join(', ');
  }

  String _displayTeknisi(MasterProvider master, RealisasiModel item) {
    final nameFromRelation = item.teknisi?['user_nama']?.toString().trim();
    if (nameFromRelation != null && nameFromRelation.isNotEmpty) {
      return nameFromRelation;
    }
    if (item.realTeknisiId > 0) {
      try {
        final user =
            master.userList.firstWhere((u) => u.userId == item.realTeknisiId);
        if (user.userNama.isNotEmpty) return user.userNama;
      } catch (_) {}
      return 'ID ${item.realTeknisiId}';
    }
    return '-';
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
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
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
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
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 28),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonSquircle(width: 42, height: 42, borderRadius: 12),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeletonLine(width: 180, height: 18),
                          SizedBox(height: 8),
                          AppSkeletonLine(width: 140, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                AppSkeletonSquircle(width: double.infinity, height: 40, borderRadius: 12),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: AppSkeletonSquircle(width: double.infinity, height: 48, borderRadius: 10)),
                    SizedBox(width: 8),
                    Expanded(child: AppSkeletonSquircle(width: double.infinity, height: 48, borderRadius: 10)),
                    SizedBox(width: 8),
                    Expanded(child: AppSkeletonSquircle(width: double.infinity, height: 48, borderRadius: 10)),
                    SizedBox(width: 8),
                    Expanded(child: AppSkeletonSquircle(width: double.infinity, height: 48, borderRadius: 10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeletonLine(width: 140, height: 16),
                const SizedBox(height: 6),
                const AppSkeletonLine(width: 180, height: 12),
                const SizedBox(height: 16),
                ...List.generate(
                  4,
                  (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: AppSkeletonSquircle(
                        width: double.infinity, height: 38, borderRadius: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeletonLine(width: 160, height: 16),
                const SizedBox(height: 6),
                const AppSkeletonLine(width: 100, height: 12),
                const SizedBox(height: 16),
                ...List.generate(
                  2,
                  (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: AppSkeletonSquircle(
                        width: double.infinity, height: 72, borderRadius: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  _InfoItem({required this.icon, required this.label, required this.value});
}

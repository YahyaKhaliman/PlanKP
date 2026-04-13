import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/master/providers/master_provider.dart';
import '../../../features/master/widgets/jenis_lookup_sheet.dart';
import '../../../features/master/models/jenis_model.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';

const _kPageBg = Color(0xFFF8FAFC);

// ═══════════════════════════════════════════════════════════════
//  JADWAL SCREEN
// ═══════════════════════════════════════════════════════════════
class JadwalScreen extends StatefulWidget {
  final int initialIndex;

  const JadwalScreen({super.key, this.initialIndex = 0});
  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  String? _selectedFrekuensi;

  int _isoWeekNumber(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final day = d.weekday == 7 ? 7 : d.weekday;
    final thursday = d.add(Duration(days: 4 - day));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    return ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSameCurrentPeriod(RealisasiModel r, JadwalModel jadwal) {
    final now = DateTime.now();
    final frequency = jadwal.jdwFrekuensi;

    if (frequency == 'Harian') {
      final realDate = DateTime.tryParse(r.realTgl);
      if (realDate == null) return false;
      return _dateOnly(realDate) == _dateOnly(now);
    }

    if (frequency == 'Mingguan') {
      return r.realTahun == now.year && r.realWeekNumber == _isoWeekNumber(now);
    }

    if (frequency == 'Bulanan') {
      return r.realTahun == now.year && r.realBulan == now.month;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final jadwalProvider = context.read<JadwalProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';
    if (isAdmin) {
      await jadwalProvider.fetchJadwal();
    } else {
      await jadwalProvider.fetchJadwalByUser();
    }
    if (!mounted) return;
    await context.read<MasterProvider>().fetchJenis();
  }

  Future<void> _openForm([JadwalModel? item]) async {
    final master = context.read<MasterProvider>();
    final auth = context.read<AuthProvider>();
    await master.fetchJenis(showLoading: false);
    await master.fetchPabrik();
    // Fetch users dengan divisi yang sama dengan user login
    final userDivisi = auth.user?['user_divisi'] ?? '';
    await master.fetchUsers(divisi: userDivisi, showLoading: false);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JadwalForm(item: item),
    );
  }

  Future<void> _handleJadwalTap(
    JadwalModel jadwal, {
    required bool isAdmin,
    required bool isUser,
  }) async {
    if (isAdmin || !isUser) {
      Navigator.pushNamed(context, AppRoutes.jadwalDetail,
          arguments: jadwal.jdwId);
      return;
    }

    if (jadwal.jdwStatus != 'Draft') {
      await AppNotifier.showError(
          context, 'Jadwal harus dalam status Draft untuk direalisasi');
      return;
    }

    final p = context.read<JadwalProvider>();
    await p.fetchJadwalDetail(jadwal.jdwId);
    if (!mounted) return;

    final inventarisList = p.inventarisByJenis
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    await p.fetchRealisasi(jadwalId: jadwal.jdwId);
    if (!mounted) return;
    final terpakaiInvIds = p.realisasiList
        .where((r) => _isSameCurrentPeriod(r, jadwal))
        .map((r) => r.realInvId)
        .toSet();
    final belumSelesaiList = inventarisList.where((inv) {
      final invIdRaw = inv['inv_id'];
      final invId = invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');
      return invId == null || !terpakaiInvIds.contains(invId);
    }).toList();

    if (inventarisList.isEmpty) {
      await AppNotifier.showError(
          context, 'Inventaris untuk jadwal ini belum ada');
      return;
    }

    if (inventarisList.length == 1 && belumSelesaiList.isNotEmpty) {
      _openRealisasiFromInventaris(jadwal, belumSelesaiList.first);
      return;
    }

    if (belumSelesaiList.isEmpty) {
      await AppNotifier.showWarning(
        context,
        'Semua unit pada jadwal ini sudah direalisasi dalam rentang saat ini',
      );
      return;
    }

    _showInventarisPicker(jadwal, belumSelesaiList);
  }

  void _showInventarisPicker(
    JadwalModel jadwal,
    List<Map<String, dynamic>> inventarisList,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _kPageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pilih Unit untuk Realisasi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: inventarisList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final inv = inventarisList[i];
                      final merk =
                          (inv['inv_merk'] ?? '-').toString().toUpperCase();
                      final pabrik = inv['inv_pabrik_kode'] ?? '-';
                      final nomor = inv['inv_no'] ?? '-';
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.12),
                            child: const Icon(Icons.inventory_2_outlined,
                                color: AppColors.primary, size: 20),
                          ),
                          title: Text(
                            inv['inv_nama'] ?? '-',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$merk · Kode: $nomor',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.factory_outlined,
                                        size: 14,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(pabrik,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Belum dipilih',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context);
                            _openRealisasiFromInventaris(jadwal, inv);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRealisasiFromInventaris(
    JadwalModel jadwal,
    Map<String, dynamic> inv,
  ) async {
    final invJenisRaw =
        inv['inv_jenis_id'] ?? inv['inv_jenis'] ?? jadwal.jdwJenisId;
    final invJenisId = invJenisRaw is int
        ? invJenisRaw
        : int.tryParse('$invJenisRaw') ?? jadwal.jdwJenisId;
    final invIdRaw = inv['inv_id'];
    final invId = invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');

    final jenis = context.read<MasterProvider>().jenisById(invJenisId);
    await Navigator.pushNamed(
      context,
      AppRoutes.realisasiForm,
      arguments: {
        'jadwalId': jadwal.jdwId,
        'invJenisId': invJenisId,
        'invJenisNama': jenis?.jenisNama ?? 'ID $invJenisId',
        'invId': invId,
        'invNama': inv['inv_nama'],
        'invNo': inv['inv_no'],
        'invKondisi': inv['inv_kondisi'],
        'invPicNama': inv['pic_user']?['user_nama'] ?? inv['inv_pic'],
        'invPicId': inv['pic_user']?['user_id'],
      },
    );
    if (!mounted) return;
    await _loadData();
  }

  bool _hasRemainingUnitToRealisasi(JadwalModel j) {
    final total = j.jdwTotalUnit;
    final selesai = j.jdwSelesaiUnit ?? 0;
    if (total == null || total <= 0) return true;
    return selesai < total;
  }

  Widget _buildSummaryTable(List<JadwalModel> aktifList) {
    const freqs = ['Harian', 'Mingguan', 'Bulanan'];

    final summary = freqs.map((f) {
      final items = aktifList.where((j) => j.jdwFrekuensi == f).toList();
      final targetCount = items.fold<int>(
        0,
        (sum, j) => sum + (j.jdwTarget ?? j.jdwTotalUnit ?? 0),
      );
      final realisasiCount =
          items.fold<int>(0, (sum, j) => sum + (j.jdwSelesaiUnit ?? 0));
      final pct =
          targetCount > 0 ? (realisasiCount / targetCount * 100).round() : 0;

      return {
        'freq': f,
        'target': targetCount,
        'realisasi': realisasiCount,
        'pct': pct,
      };
    }).toList();

    Widget metricMini(String label, String value, {Color? valueColor}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        return Container(
          margin: EdgeInsets.fromLTRB(
              isCompact ? 12 : 16, 16, isCompact ? 12 : 16, 4),
          padding: EdgeInsets.all(isCompact ? 12 : 16),
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ringkasan Realisasi per Frekuensi',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_selectedFrekuensi != null)
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _selectedFrekuensi = null),
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                      label: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: isCompact ? 280 : 240,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          if (!isCompact) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Frekuensi',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Target',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Realisasi',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '%',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...List.generate(summary.length, (i) {
                              final row = summary[i];
                              final f = row['freq'] as String;
                              final target = row['target'] as int;
                              final realisasi = row['realisasi'] as int;
                              final pct = row['pct'] as int;
                              final isSelected = _selectedFrekuensi == f;
                              final isLast = i == summary.length - 1;

                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () => setState(() =>
                                        _selectedFrekuensi =
                                            isSelected ? null : f),
                                    borderRadius: isLast
                                        ? const BorderRadius.vertical(
                                            bottom: Radius.circular(12))
                                        : BorderRadius.zero,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                                .withValues(alpha: 0.07)
                                            : Colors.transparent,
                                        borderRadius: isLast
                                            ? const BorderRadius.vertical(
                                                bottom: Radius.circular(12),
                                              )
                                            : BorderRadius.zero,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  margin: const EdgeInsets.only(
                                                      right: 8),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : AppColors
                                                            .textSecondary
                                                            .withValues(
                                                                alpha: 0.35),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                Text(
                                                  f,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : AppColors.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '$target',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '$realisasi',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '$pct%',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: pct >= 100
                                                    ? AppColors.success
                                                    : (isSelected
                                                        ? AppColors.primary
                                                        : AppColors
                                                            .textPrimary),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!isLast) const Divider(height: 1),
                                ],
                              );
                            }),
                          ] else ...[
                            ...summary.map((row) {
                              final f = row['freq'] as String;
                              final target = row['target'] as int;
                              final realisasi = row['realisasi'] as int;
                              final pct = row['pct'] as int;
                              final isSelected = _selectedFrekuensi == f;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () => setState(() =>
                                      _selectedFrekuensi =
                                          isSelected ? null : f),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                              .withValues(alpha: 0.08)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                                .withValues(alpha: 0.25)
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(
                                                  right: 8),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary
                                                        .withValues(
                                                            alpha: 0.35),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                f,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (pct >= 100
                                                        ? AppColors.success
                                                        : AppColors.primary)
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '$pct%',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: pct >= 100
                                                      ? AppColors.success
                                                      : AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            metricMini('Target', '$target'),
                                            const SizedBox(width: 8),
                                            metricMini(
                                                'Realisasi', '$realisasi'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';
    final isUser = auth.user?['user_jabatan'] == 'user';
    final isDesktop = AppBreakpoints.isDesktop(context);
    final maxContentWidth = isDesktop ? 1180.0 : 860.0;
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        title: const Text('Penjadwalan'),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              tooltip: 'Buat Jadwal',
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              child: const Icon(Icons.add),
            )
          : null,
      body: Consumer<JadwalProvider>(
        builder: (_, p, __) {
          if (p.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final jadwalAktif = p.jadwalList
              .where((j) =>
                  j.jdwStatus == 'Draft' &&
                  (isAdmin || _hasRemainingUnitToRealisasi(j)))
              .toList();

          final filtered = _selectedFrekuensi != null
              ? jadwalAktif
                  .where((j) => j.jdwFrekuensi == _selectedFrekuensi)
                  .toList()
              : jadwalAktif;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                children: [
                  _buildSummaryTable(jadwalAktif),
                  Expanded(
                    child: _buildJadwalTab(
                      filtered,
                      isAdmin: isAdmin,
                      isUser: isUser,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJadwalTab(
    List<JadwalModel> list, {
    required bool isAdmin,
    required bool isUser,
  }) {
    if (list.isEmpty) {
      return EmptyState(
        message: _selectedFrekuensi != null
            ? 'Tidak ada jadwal $_selectedFrekuensi yang aktif'
            : 'Belum ada jadwal yang perlu direalisasi',
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final item = list[i];
            final jenisNama = context
                    .read<MasterProvider>()
                    .jenisById(item.jdwJenisId)
                    ?.jenisNama ??
                'ID ${item.jdwJenisId}';
            return _JadwalCard(
              jadwal: item,
              jenisNama: jenisNama,
              isAdmin: isAdmin,
              isUser: isUser,
              onTap: () => _handleJadwalTap(
                item,
                isAdmin: isAdmin,
                isUser: isUser,
              ),
              onEdit: () => _openForm(item),
              onStatusChange: (st) => context
                  .read<JadwalProvider>()
                  .updateStatusJadwal(item.jdwId, st),
            );
          },
        ),
        Positioned(
          right: 8,
          bottom: 12,
          child: IgnorePointer(
            child: Container(
              width: 18,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Center(
                child: Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Card ────────────────────────────────────────────────────
class _JadwalCard extends StatelessWidget {
  final JadwalModel jadwal;
  final String jenisNama;
  final bool isAdmin;
  final bool isUser;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final void Function(String) onStatusChange;
  const _JadwalCard({
    required this.jadwal,
    required this.jenisNama,
    required this.isAdmin,
    required this.isUser,
    required this.onTap,
    required this.onEdit,
    required this.onStatusChange,
  });

  static const _statusColor = {
    'Draft': Color(0xFF2563EB),
    'Selesai': Color(0xFF16A34A),
  };
  static const _statusBg = {
    'Draft': Color(0xFFDEBFFC),
    'Selesai': Color(0xFFDCFCE7),
  };
  static IconData _iconForDivisi(String? divisiRaw) {
    final divisi = (divisiRaw ?? '').toLowerCase();
    if (divisi == 'it') return Icons.support_agent_rounded;
    if (divisi == 'ga') return Icons.precision_manufacturing_outlined;
    if (divisi == 'driver') return Icons.local_shipping_outlined;
    return Icons.event_note;
  }

  static Color _colorForDivisi(String? divisiRaw) {
    final divisi = (divisiRaw ?? '').toLowerCase();
    if (divisi == 'it') return Colors.indigo;
    if (divisi == 'ga') return Colors.orange.shade700;
    if (divisi == 'driver') return Colors.teal.shade700;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor[jadwal.jdwStatus] ?? AppColors.textSecondary;
    final sb = _statusBg[jadwal.jdwStatus] ?? AppColors.bgGray;
    final targetUnit = jadwal.jdwTarget ?? jadwal.jdwTotalUnit ?? 0;
    final selesaiUnit = jadwal.jdwSelesaiUnit ?? 0;
    final progressPct = targetUnit > 0 ? (selesaiUnit / targetUnit * 100) : 0;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                      color: _colorForDivisi(jadwal.jdwDivisi)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForDivisi(jadwal.jdwDivisi),
                      size: 20,
                      color: _colorForDivisi(jadwal.jdwDivisi),
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
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$jenisNama · ${jadwal.jdwFrekuensi} · ${jadwal.jdwDivisi}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sb,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: sc.withValues(alpha: 0.18)),
                    ),
                    child: Text(
                      jadwal.jdwStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sc,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(_formatTgl(jadwal.jdwTglMulai, jadwal.jdwTglSelesai),
                      Icons.calendar_today_outlined),
                  _chip(jadwal.assignedNama, Icons.person_outline),
                  _chip(
                    jadwal.jdwPabrikList.isEmpty
                        ? '-'
                        : jadwal.jdwPabrikList.join(', '),
                    Icons.factory_outlined,
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
                          child: _metricItem('Target', '$targetUnit unit'),
                        ),
                        Expanded(
                          child: _metricItem('Realisasi', '$selesaiUnit unit'),
                        ),
                        Expanded(
                          child: _metricItem(
                            'Hari Lagi',
                            jadwal.jdwDaysRemaining != null
                                ? '${jadwal.jdwDaysRemaining} hari'
                                : '-',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 9,
                        value: targetUnit > 0
                            ? (selesaiUnit / targetUnit).clamp(0.0, 1.0)
                            : 0,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${progressPct.round()}% capaian periode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: progressPct >= 100
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (isAdmin)
                    _actionBtn(Icons.edit_outlined, 'Edit Jadwal',
                        AppColors.textSecondary, onEdit),
                  if (isAdmin && isUser) const SizedBox(width: 8),
                  if (isUser)
                    _actionBtn(
                      Icons.playlist_add_check_circle_outlined,
                      'Lakukan Realisasi',
                      AppColors.primary,
                      onTap,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.1))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary)),
        ]),
      );

  Widget _metricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          ]),
        ),
      );

  String _formatTgl(String mulai, String? selesai) {
    final m = DateFormatter.toDisplay(mulai);
    if (selesai == null || selesai.trim().isEmpty) return m;
    final s = DateFormatter.toDisplay(selesai);
    return '$m s/d $s';
  }
}

// ═══════════════════════════════════════════════════════════════
//  JADWAL FORM
// ═══════════════════════════════════════════════════════════════
class _JadwalForm extends StatefulWidget {
  final JadwalModel? item;
  const _JadwalForm({this.item});
  @override
  State<_JadwalForm> createState() => _JadwalFormState();
}

class _JadwalFormState extends State<_JadwalForm> {
  final _form = GlobalKey<FormState>();
  final _judulCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final TextEditingController _jenisCtrl = TextEditingController();
  int? _jenisId;
  String? _divisi;
  final List<String> _pabrikCodes = [];
  String? _selectedPabrikValue;
  int? _assignedToUserId;
  String _frekuensi = 'Harian';
  DateTime? _tglMulai;
  DateTime? _tglSelesai;
  int? _maxTargetUnit;
  bool _loadingTargetLimit = false;
  String? _targetLimitError;

  static const _frekuensiList = ['Harian', 'Mingguan', 'Bulanan'];

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    if (d != null) {
      _judulCtrl.text = d.jdwJudul;
      _targetCtrl.text = '${d.jdwTarget ?? 1}';
      _notesCtrl.text = d.jdwNotes ?? '';
      _jenisId = d.jdwJenisId;
      _divisi = d.jdwDivisi;
      _pabrikCodes
        ..clear()
        ..addAll(d.jdwPabrikList);
      _assignedToUserId = d.jdwAssignedTo;
      _frekuensi = d.jdwFrekuensi;
      _tglMulai = DateTime.tryParse(d.jdwTglMulai);
      _tglSelesai =
          d.jdwTglSelesai != null ? DateTime.tryParse(d.jdwTglSelesai!) : null;
      final jenis = context.read<MasterProvider>().jenisById(d.jdwJenisId);
      _jenisCtrl.text = jenis?.jenisNama ?? 'ID ${d.jdwJenisId}';
    } else {
      _targetCtrl.text = '1';
      // Untuk create, set divisi dari auth user
      final auth = context.read<AuthProvider>();
      _divisi = auth.user?['user_divisi'] ?? '';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _jenisId == null) return;
      _syncTargetLimitForJenis(_jenisId!);
    });
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _targetCtrl.dispose();
    _notesCtrl.dispose();
    _jenisCtrl.dispose();
    super.dispose();
  }

  String _fmtDateApi(DateTime? d) => DateFormatter.toApi(d);

  String _fmtDateDisplay(DateTime? d) =>
      DateFormatter.toDisplayFromDate(d, fallback: '');

  int get _currentTargetValue => int.tryParse(_targetCtrl.text.trim()) ?? 1;

  void _setTargetValue(int value) {
    _targetCtrl.text = '$value';
    _targetCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _targetCtrl.text.length),
    );
  }

  Future<void> _syncTargetLimitForJenis(int jenisId) async {
    setState(() => _loadingTargetLimit = true);
    final master = context.read<MasterProvider>();
    await master.fetchInventaris(
      jenis: '$jenisId',
      showLoading: false,
      updateKategoriMap: false,
    );
    if (!mounted) return;

    final maxTarget = master.inventarisList.length;
    setState(() {
      _maxTargetUnit = maxTarget;
      _loadingTargetLimit = false;
      _targetLimitError = null;
    });

    if (maxTarget < 1) {
      _setTargetValue(1);
      return;
    }

    final current = _currentTargetValue;
    if (current > maxTarget) {
      _setTargetValue(maxTarget);
    } else if (current < 1) {
      _setTargetValue(1);
    }
  }

  void _adjustTarget(int delta) {
    final max = _maxTargetUnit;
    if (max == null || max < 1) return;
    final current = _currentTargetValue;
    if (delta > 0 && current >= max) {
      setState(() {
        _targetLimitError = 'Inventaris ${_jenisCtrl.text} hanya $max unit';
      });
      return;
    }

    final next = (current + delta).clamp(1, max);
    _setTargetValue(next);
    if (_targetLimitError != null) {
      setState(() {
        _targetLimitError = null;
      });
    }
  }

  Future<void> _pickDate(bool isMulai) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isMulai
          ? (_tglMulai ?? DateTime.now())
          : (_tglSelesai ?? DateTime.now()),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isMulai) {
          _tglMulai = picked;
        } else {
          _tglSelesai = picked;
        }
      });
    }
  }

  Future<void> _pickJenis() async {
    final master = context.read<MasterProvider>();
    if (master.jenisMaster.isEmpty) {
      await master.fetchJenis(showLoading: false);
    }
    await master.fetchJenisWithInventaris(showLoading: false);
    if (!mounted) return;

    final availableJenis =
        master.jenisAvailableForJadwal(includeJenisId: _jenisId);
    if (availableJenis.isEmpty) {
      await AppNotifier.showWarning(
        context,
        'Belum ada inventaris aktif. Tambahkan data inventaris dulu sebelum membuat jadwal.',
      );
      return;
    }

    final result = await showModalBottomSheet<JenisModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JenisLookupSheet(
        items: availableJenis,
        initialId: _jenisId,
      ),
    );
    if (result != null) {
      setState(() {
        _jenisId = result.jenisId;
        _jenisCtrl.text = result.jenisNama;
        // Divisi sudah otomatis dari auth user, tidak perlu diubah
      });
      await _syncTargetLimitForJenis(result.jenisId);
    }
  }

  Widget _requiredLabel(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _pabrikSelector(MasterProvider master) {
    String labelForCode(String code) {
      final match = master.pabrikList.where((p) => p.pabKode == code);
      if (match.isNotEmpty) return match.first.displayLabel;
      return code;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _selectedPabrikValue,
            decoration: InputDecoration(
              label: _requiredLabel('Pabrik / Lokasi'),
              prefixIcon: const Icon(Icons.factory_outlined),
            ),
            hint: const Text('Pilih pabrik/lokasi'),
            items: master.pabrikList
                .map((p) => DropdownMenuItem(
                      value: p.pabKode,
                      child: Text(p.displayLabel),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                if (!_pabrikCodes.contains(value)) {
                  _pabrikCodes.add(value);
                }
                _selectedPabrikValue = null;
              });
            },
            validator: (_) {
              if (_pabrikCodes.isEmpty) {
                return 'Pilih minimal satu pabrik';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          if (_pabrikCodes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Belum ada pabrik yang dipilih',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pabrikCodes.map((code) {
                final label = labelForCode(code);
                return InputChip(
                  label: Text(label),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _pabrikCodes.remove(code);
                    });
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _jenisPickerField() {
    final divisiLabel =
        (_divisi != null && _divisi!.isNotEmpty) ? _divisi! : '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _jenisCtrl,
            readOnly: true,
            decoration: InputDecoration(
              label: _requiredLabel('Jenis Inventaris'),
              hintText: 'Cari jenis yang sudah punya inventaris...',
              prefixIcon: const Icon(Icons.label_outline),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _pickJenis,
              ),
            ),
            validator: (_) {
              if (_jenisId == null) return 'Jenis wajib dipilih';
              final master = context.read<MasterProvider>();
              if (!master.hasInventarisForJenis(_jenisId!)) {
                return 'Jenis belum punya inventaris aktif';
              }
              return null;
            },
            onTap: _pickJenis,
          ),
          if (_divisi != null && _divisi!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Divisi Pelaksana: $divisiLabel',
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

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      await AppNotifier.showWarning(
          context, 'Lengkapi data jadwal terlebih dahulu');
      return;
    }
    if (_jenisId == null) {
      await AppNotifier.showWarning(context, 'Jenis inventaris wajib dipilih');
      return;
    }
    final master = context.read<MasterProvider>();
    if (!master.hasInventarisForJenis(_jenisId!)) {
      await AppNotifier.showWarning(
        context,
        'Jenis yang dipilih belum punya inventaris aktif. Tambahkan inventaris dulu.',
      );
      return;
    }
    if (_tglMulai == null) {
      await AppNotifier.showWarning(context, 'Tanggal mulai wajib dipilih');
      return;
    }
    if (_assignedToUserId == null) {
      await AppNotifier.showWarning(context, 'Pelaksana wajib dipilih');
      return;
    }
    if (_pabrikCodes.isEmpty) {
      await AppNotifier.showWarning(
          context, 'Pilih minimal satu pabrik/lokasi jadwal');
      return;
    }
    final parsedTarget = int.tryParse(_targetCtrl.text.trim());
    if (parsedTarget == null || parsedTarget < 1) {
      await AppNotifier.showWarning(context, 'Target wajib angka minimal 1');
      return;
    }
    if (_maxTargetUnit != null && parsedTarget > _maxTargetUnit!) {
      await AppNotifier.showWarning(
        context,
        'Target tidak boleh melebihi total inventaris jenis ($_maxTargetUnit unit)',
      );
      return;
    }
    final p = context.read<JadwalProvider>();
    final body = {
      'jdw_judul': _judulCtrl.text.trim(),
      'jdw_jenis_id': _jenisId!,
      'jdw_target': parsedTarget,
      'jdw_divisi': _divisi,
      'jdw_pabrik_kode': _pabrikCodes.join(','),
      'jdw_assigned_to': _assignedToUserId,
      'jdw_frekuensi': _frekuensi,
      'jdw_tgl_mulai': _fmtDateApi(_tglMulai),
      'jdw_tgl_selesai': _tglSelesai != null ? _fmtDateApi(_tglSelesai) : null,
      'jdw_notes':
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };
    final isEdit = widget.item != null;
    final ok = await p.saveJadwal(body, id: widget.item?.jdwId);
    if (ok && mounted) {
      await AppNotifier.showSuccess(context,
          isEdit ? 'Jadwal berhasil diperbarui' : 'Jadwal berhasil dibuat');
      if (!mounted) return;
      Navigator.pop(context);
    } else if (mounted) {
      await AppNotifier.showError(context, p.error ?? 'Gagal menyimpan jadwal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final master = context.watch<MasterProvider>();
    final jadwalP = context.watch<JadwalProvider>();
    if (_jenisId != null && _jenisCtrl.text.isEmpty) {
      final jenis = master.jenisById(_jenisId!);
      if (jenis != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _jenisCtrl.text = jenis.jenisNama);
        });
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _kPageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _form,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
              Text(isEdit ? 'Edit Jadwal' : 'Buat Jadwal Baru',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _judulCtrl,
                decoration: InputDecoration(
                  label: _requiredLabel('Judul Jadwal'),
                  prefixIcon: const Icon(Icons.title_outlined),
                  hintText: 'Maintenance Mesin Sewing Mingguan...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Judul wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),
              _jenisPickerField(),
              const SizedBox(height: 14),
              _pabrikSelector(master),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _assignedToUserId,
                decoration: InputDecoration(
                  label: _requiredLabel('Pelaksana / User'),
                  prefixIcon: const Icon(Icons.person_outlined),
                ),
                hint: const Text('Pilih pelaksana'),
                items: master.userList
                    .where((u) =>
                        u.userDivisi == _divisi && u.userJabatan == 'user')
                    .map((u) => DropdownMenuItem(
                          value: u.userId,
                          child: Text(u.userNama),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _assignedToUserId = v),
                validator: (v) => v == null ? 'Pelaksana wajib dipilih' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _frekuensi,
                decoration: InputDecoration(
                  label: _requiredLabel('Frekuensi'),
                  prefixIcon: const Icon(Icons.repeat_outlined),
                ),
                items: _frekuensiList
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _frekuensi = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _targetCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_targetLimitError != null) {
                    setState(() {
                      _targetLimitError = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  label: _requiredLabel('Target Unit per Jadwal'),
                  prefixIcon: const Icon(Icons.flag_outlined),
                  hintText: 'Contoh: 6',
                  errorText: _targetLimitError,
                  suffixIcon: SizedBox(
                    width: 40,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: (_loadingTargetLimit || _maxTargetUnit == null)
                              ? null
                              : () => setState(() => _adjustTarget(1)),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.keyboard_arrow_up, size: 20),
                          ),
                        ),
                        InkWell(
                          onTap: (_loadingTargetLimit || _maxTargetUnit == null)
                              ? null
                              : () => setState(() => _adjustTarget(-1)),
                          child: const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Icon(Icons.keyboard_arrow_down, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n < 1) return 'Target wajib angka minimal 1';
                  if (_maxTargetUnit != null && n > _maxTargetUnit!) {
                    return 'Target maksimal $_maxTargetUnit unit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => _pickDate(true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    label: _requiredLabel('Tanggal Mulai'),
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _tglMulai != null
                        ? _fmtDateDisplay(_tglMulai)
                        : 'Pilih tanggal',
                    style: TextStyle(
                      color: _tglMulai != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => _pickDate(false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal Selesai (opsional)',
                    prefixIcon: const Icon(Icons.event_outlined),
                    suffixIcon: _tglSelesai != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _tglSelesai = null))
                        : null,
                  ),
                  child: Text(
                    _tglSelesai != null
                        ? _fmtDateDisplay(_tglSelesai)
                        : 'Tidak ada batas',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              if (jadwalP.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(jadwalP.error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 13))),
                  ]),
                ),
              Consumer<JadwalProvider>(
                builder: (_, p, __) => ElevatedButton(
                  onPressed: p.loading ? null : _submit,
                  child: p.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Simpan Perubahan' : 'Buat Jadwal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

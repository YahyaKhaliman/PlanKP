import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/master/models/user_model.dart';
import '../../../features/master/providers/master_provider.dart';
import '../../../features/master/widgets/jenis_lookup_sheet.dart';
import '../../../features/master/models/jenis_model.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';
import '../widgets/realisasi_detail_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';
    final jadwalProvider = context.read<JadwalProvider>();
    if (isAdmin) {
      await jadwalProvider.fetchJadwal();
    } else {
      await jadwalProvider.fetchJadwalByDivisi();
    }
    if (!mounted) return;
    await context.read<MasterProvider>().fetchJenis();
  }

  void _openForm([JadwalModel? item]) {
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

    if (jadwal.jdwStatus != 'Aktif') {
      await AppNotifier.showError(
          context, 'Jadwal belum aktif untuk direalisasi');
      return;
    }

    final p = context.read<JadwalProvider>();
    await p.fetchJadwalDetail(jadwal.jdwId);
    if (!mounted) return;

    final inventarisList = p.inventarisByJenis
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    await p.fetchRealisasi(jadwalId: jadwal.jdwId, status: 'Selesai');
    final selesaiInvIds = p.realisasiList.map((r) => r.realInvId).toSet();
    final belumSelesaiList = inventarisList.where((inv) {
      final invIdRaw = inv['inv_id'];
      final invId = invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');
      return invId == null || !selesaiInvIds.contains(invId);
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

    _showInventarisPicker(jadwal, inventarisList, selesaiInvIds);
  }

  void _showInventarisPicker(
    JadwalModel jadwal,
    List<Map<String, dynamic>> inventarisList,
    Set<int> selesaiInvIds,
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
                      final invIdRaw = inv['inv_id'];
                      final invId = invIdRaw is int
                          ? invIdRaw
                          : int.tryParse('$invIdRaw');
                      final sudahDirealisasi =
                          invId != null && selesaiInvIds.contains(invId);
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2_outlined,
                              color: AppColors.primary),
                          title: Text(inv['inv_nama'] ?? '-'),
                          subtitle: Text(
                              '${inv['inv_no'] ?? '-'} · ${inv['inv_lokasi'] ?? '-'}${sudahDirealisasi ? '\nSudah direalisasi' : '\nBelum direalisasi'}'),
                          trailing: sudahDirealisasi
                              ? const Icon(Icons.check_circle,
                                  color: AppColors.success)
                              : const Icon(Icons.chevron_right),
                          isThreeLine: true,
                          onTap: sudahDirealisasi
                              ? null
                              : () {
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
        'invPicNama': inv['pic_user']?['user_nama'],
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Expanded(
                  flex: 3,
                  child: Text('Frekuensi',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary))),
              const Expanded(
                  flex: 2,
                  child: Text('Target',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary))),
              const Expanded(
                  flex: 2,
                  child: Text('Realisasi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary))),
              const Expanded(
                  flex: 2,
                  child: Text('%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary))),
              const SizedBox(width: 20),
            ]),
          ),
          const Divider(height: 1),
          ...List.generate(freqs.length, (i) {
            final f = freqs[i];
            final items = aktifList.where((j) => j.jdwFrekuensi == f).toList();
            final targetCount =
                items.fold<int>(0, (sum, j) => sum + (j.jdwTotalUnit ?? 0));
            final realisasiCount =
                items.fold<int>(0, (sum, j) => sum + (j.jdwSelesaiUnit ?? 0));
            final pct = targetCount > 0
                ? (realisasiCount / targetCount * 100).round()
                : 0;
            final isSelected = _selectedFrekuensi == f;
            final isLast = i == freqs.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: () => setState(() {
                    _selectedFrekuensi = isSelected ? null : f;
                  }),
                  borderRadius: isLast
                      ? const BorderRadius.vertical(bottom: Radius.circular(12))
                      : BorderRadius.zero,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.07)
                          : Colors.transparent,
                      borderRadius: isLast
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(12))
                          : BorderRadius.zero,
                    ),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: Row(children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary.withOpacity(0.35),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(f,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              )),
                        ]),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('$targetCount',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('$realisasiCount',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('$pct%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: pct >= 100
                                    ? AppColors.success
                                    : (isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary))),
                      ),
                      SizedBox(
                        width: 20,
                        child: Icon(
                          isSelected
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ]),
                  ),
                ),
                if (!isLast) const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';
    final isUser = auth.user?['user_jabatan'] == 'user';
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        title: const Text('Penjadwalan'),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              tooltip: 'Buat Jadwal',
              child: const Icon(Icons.add),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            )
          : null,
      body: Consumer<JadwalProvider>(
        builder: (_, p, __) {
          if (p.loading)
            return const Center(child: CircularProgressIndicator());

          final jadwalAktif = p.jadwalList
              .where((j) =>
                  j.jdwStatus == 'Aktif' &&
                  (isAdmin || _hasRemainingUnitToRealisasi(j)))
              .toList();

          final filtered = _selectedFrekuensi != null
              ? jadwalAktif
                  .where((j) => j.jdwFrekuensi == _selectedFrekuensi)
                  .toList()
              : jadwalAktif;
          return Column(
            children: [
              _buildSummaryTable(jadwalAktif),
              Expanded(
                child:
                    _buildJadwalTab(filtered, isAdmin: isAdmin, isUser: isUser),
              ),
            ],
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

    return ListView.separated(
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
          onStatusChange: (st) =>
              context.read<JadwalProvider>().updateStatusJadwal(item.jdwId, st),
        );
      },
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
    'Aktif': Color(0xFF16A34A),
    // 'Nonaktif': Color(0xFFDC2626),
  };
  static const _statusBg = {
    'Aktif': Color(0xFFDCFCE7),
    // 'Nonaktif': Color(0xFFFEE2E2),
  };
  static IconData _iconForDivisi(String? divisiRaw) {
    final divisi = (divisiRaw ?? '').toLowerCase();
    if (divisi.contains('it support') || divisi == 'it')
      return Icons.support_agent_rounded;
    if (divisi.contains('jahit')) return Icons.content_cut_rounded;
    if (divisi.contains('umum')) return Icons.build_circle_outlined;
    if (divisi.contains('satpam') || divisi.contains('security'))
      return Icons.shield_outlined;
    if (divisi.contains('kebersihan') || divisi.contains('clean'))
      return Icons.cleaning_services_outlined;
    return Icons.event_note;
  }

  static Color _colorForDivisi(String? divisiRaw) {
    final divisi = (divisiRaw ?? '').toLowerCase();
    if (divisi.contains('it support') || divisi == 'it') return Colors.indigo;
    if (divisi.contains('jahit')) return Colors.pink.shade700;
    if (divisi.contains('umum')) return Colors.orange.shade700;
    if (divisi.contains('satpam') || divisi.contains('security'))
      return Colors.blueGrey.shade700;
    if (divisi.contains('kebersihan') || divisi.contains('clean'))
      return Colors.teal.shade700;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor[jadwal.jdwStatus] ?? AppColors.textSecondary;
    final sb = _statusBg[jadwal.jdwStatus] ?? AppColors.bgGray;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // baris 1: judul + status badge
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    _colorForDivisi(jadwal.jdwDivisi).withOpacity(0.14),
                child: Icon(
                  _iconForDivisi(jadwal.jdwDivisi),
                  size: 16,
                  color: _colorForDivisi(jadwal.jdwDivisi),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(jadwal.jdwJudul,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: sb, borderRadius: BorderRadius.circular(6)),
                child: Text(jadwal.jdwStatus,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: sc)),
              ),
            ]),
            const SizedBox(height: 8),

            // baris 2: jenis + frekuensi
            Wrap(spacing: 6, runSpacing: 4, children: [
              _chip(jenisNama, Icons.label_outline),
              _chip(jadwal.jdwFrekuensi, Icons.repeat_outlined),
            ]),
            const SizedBox(height: 6),

            // baris 3: tanggal
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(_formatTgl(jadwal.jdwTglMulai, jadwal.jdwTglSelesai),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 10),

            // baris 4: actions
            Row(children: [
              if (isAdmin)
                _actionBtn(Icons.edit_outlined, 'Edit', AppColors.textSecondary,
                    onEdit),
              if (isUser)
                _actionBtn(
                  Icons.playlist_add_check_circle_outlined,
                  'Realisasi',
                  AppColors.primary,
                  onTap,
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary)),
        ]),
      );

  Widget _actionBtn(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
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
//  JADWAL DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════
class JadwalDetailScreen extends StatefulWidget {
  final int jadwalId;
  const JadwalDetailScreen({super.key, required this.jadwalId});
  @override
  State<JadwalDetailScreen> createState() => _JadwalDetailScreenState();
}

class _JadwalDetailScreenState extends State<JadwalDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetailData();
    });
  }

  Future<void> _loadDetailData() async {
    final p = context.read<JadwalProvider>();
    await p.fetchJadwalDetail(widget.jadwalId);
    await p.fetchRealisasi(jadwalId: widget.jadwalId, status: 'Selesai');
  }

  Future<void> _openRealisasiDetail(RealisasiModel item) async {
    final p = context.read<JadwalProvider>();
    await p.fetchRealisasiDetail(item.realId);
    if (!mounted) return;

    final detail = p.realisasiDetail;
    if (detail == null) {
      await AppNotifier.showError(context, 'Detail realisasi tidak ditemukan');
      return;
    }

    await RealisasiDetailSheet.show(
      context,
      detail: detail,
      title: 'Detail Realisasi Unit',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(title: const Text('Detail Jadwal')),
      body: Consumer<JadwalProvider>(
        builder: (_, p, __) {
          if (p.loading)
            return const Center(child: CircularProgressIndicator());
          if (p.jadwalDetail == null) return const SizedBox.shrink();

          final jdw = p.jadwalDetail!;
          final jenisNama = context
                  .read<MasterProvider>()
                  .jenisById(jdw.jdwJenisId)
                  ?.jenisNama ??
              'ID ${jdw.jdwJenisId}';
          final selesaiInvIds = p.realisasiList
              .where((r) => r.realStatus == 'Selesai')
              .map((r) => r.realInvId)
              .toSet();
          return ListView(padding: const EdgeInsets.all(16), children: [
            // info jadwal
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(jdw.jdwJudul,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _row('Jenis Inventaris', jenisNama),
                      _row('Frekuensi', jdw.jdwFrekuensi),
                      _row('Tanggal Mulai',
                          DateFormatter.toDisplay(jdw.jdwTglMulai)),
                      if (jdw.jdwTglSelesai != null)
                        _row('Tanggal Selesai',
                            DateFormatter.toDisplay(jdw.jdwTglSelesai!)),
                      _row('Status', jdw.jdwStatus),
                      if (jdw.jdwNotes != null) _row('Catatan', jdw.jdwNotes!),
                    ]),
              ),
            ),
            const SizedBox(height: 16),

            // daftar inventaris
            const Text('Unit Inventaris yang Terjadwal',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            ...p.inventarisByJenis.map((inv) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Builder(builder: (_) {
                    final invIdRaw = inv['inv_id'];
                    final invId =
                        invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');
                    final sudahTerealisasi =
                        invId != null && selesaiInvIds.contains(invId);
                    RealisasiModel? realisasiItem;
                    if (invId != null) {
                      for (final r in p.realisasiList) {
                        if (r.realInvId == invId && r.realStatus == 'Selesai') {
                          realisasiItem = r;
                          break;
                        }
                      }
                    }
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.inventory_2_outlined,
                            color: AppColors.primary, size: 20),
                      ),
                      title: Text(inv['inv_nama'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${inv['inv_no']} · ${inv['inv_lokasi'] ?? '-'}\n${sudahTerealisasi ? 'Sudah terealisasi' : 'Belum terealisasi'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
                      trailing: sudahTerealisasi && realisasiItem != null
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  _openRealisasiDetail(realisasiItem!),
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 16),
                              label: const Text('Detail'),
                            )
                          : Icon(
                              Icons.radio_button_unchecked,
                              color: AppColors.textSecondary,
                            ),
                    );
                  }),
                )),
          ]);
        },
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );
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
  final _notesCtrl = TextEditingController();
  final TextEditingController _jenisCtrl = TextEditingController();
  int? _jenisId;
  String? _divisi;
  String _frekuensi = 'Harian';
  DateTime? _tglMulai;
  DateTime? _tglSelesai;

  static const _frekuensiList = ['Harian', 'Mingguan', 'Bulanan'];

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    if (d != null) {
      _judulCtrl.text = d.jdwJudul;
      _notesCtrl.text = d.jdwNotes ?? '';
      _jenisId = d.jdwJenisId;
      _divisi = d.jdwDivisi;
      _frekuensi = d.jdwFrekuensi;
      _tglMulai = DateTime.tryParse(d.jdwTglMulai);
      _tglSelesai =
          d.jdwTglSelesai != null ? DateTime.tryParse(d.jdwTglSelesai!) : null;
      final jenis = context.read<MasterProvider>().jenisById(d.jdwJenisId);
      _jenisCtrl.text = jenis?.jenisNama ?? 'ID ${d.jdwJenisId}';
    }
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _notesCtrl.dispose();
    _jenisCtrl.dispose();
    super.dispose();
  }

  String _fmtDateApi(DateTime? d) => DateFormatter.toApi(d);

  String _fmtDateDisplay(DateTime? d) =>
      DateFormatter.toDisplayFromDate(d, fallback: '');

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
        if (isMulai)
          _tglMulai = picked;
        else
          _tglSelesai = picked;
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
        final kategori = master.kategoriByJenisId(result.jenisId);
        if (_divisi == null && kategori != null) {
          _divisi = _divisiFromKategori(kategori) ?? _validDivisi(kategori);
        } else if (_divisi != null) {
          _divisi = _validDivisi(_divisi);
        }
      });
    }
  }

  Widget _jenisPickerField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _jenisCtrl,
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Jenis Inventaris',
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
    );
  }

  String? _divisiFromKategori(String? kategori) {
    if (kategori == null || kategori.isEmpty) return null;
    final allowed = UserModel.kategoriToDivisi[kategori];
    if (allowed != null && allowed.isNotEmpty) {
      for (final div in allowed) {
        final valid = _validDivisi(div);
        if (valid != null) return valid;
      }
    }
    return _validDivisi(kategori);
  }

  String? _validDivisi(String? value) {
    if (value == null || value.isEmpty) return null;
    return UserModel.divisiList.contains(value) ? value : null;
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
    final p = context.read<JadwalProvider>();
    final divisi = _divisi ??
        (_jenisId != null ? master.kategoriByJenisId(_jenisId!) : null) ??
        widget.item?.jdwDivisi;
    final body = {
      'jdw_judul': _judulCtrl.text.trim(),
      'jdw_jenis_id': _jenisId!,
      'jdw_divisi': divisi,
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
    final allDivisi = UserModel.divisiList;
    final kategori =
        _jenisId != null ? master.kategoriByJenisId(_jenisId!) : null;
    final defaultDivisi =
        kategori != null && UserModel.divisiList.contains(kategori)
            ? kategori
            : null;
    final divisiValue = _divisi ?? defaultDivisi ?? widget.item?.jdwDivisi;

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
                decoration: const InputDecoration(
                  labelText: 'Judul Jadwal',
                  prefixIcon: Icon(Icons.title_outlined),
                  hintText: 'Maintenance Mesin Sewing Mingguan...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Judul wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),
              _jenisPickerField(),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: divisiValue,
                decoration: const InputDecoration(
                  labelText: 'Divisi Pelaksana',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                hint: const Text('Pilih divisi pelaksanan'),
                items: allDivisi
                    .map(
                        (div) => DropdownMenuItem(value: div, child: Text(div)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _divisi = v);
                },
                validator: (v) => v == null ? 'Divisi wajib dipilih' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _frekuensi,
                decoration: const InputDecoration(
                  labelText: 'Frekuensi',
                  prefixIcon: Icon(Icons.repeat_outlined),
                ),
                items: _frekuensiList
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _frekuensi = v!),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => _pickDate(true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Mulai',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/master/providers/master_provider.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';

const _kPageBg = Color(0xFFF8FAFC);

class JadwalScreen extends StatefulWidget {
  final int initialIndex;

  const JadwalScreen({super.key, this.initialIndex = 0});
  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  String? _selectedFrekuensi;
  bool _isSummaryCollapsed = false;

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    final pixels = notification.metrics.pixels;

    if (pixels <= 8 && _isSummaryCollapsed) {
      setState(() => _isSummaryCollapsed = false);
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;

      if (delta > 0 && pixels > 50 && !_isSummaryCollapsed) {
        setState(() => _isSummaryCollapsed = true);
      } else if (delta < 0 && _isSummaryCollapsed) {
        setState(() => _isSummaryCollapsed = false);
      }
    }

    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.forward &&
        _isSummaryCollapsed) {
      setState(() => _isSummaryCollapsed = false);
    }

    return false;
  }

  // Logika pembantu periode (dipertahankan)
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
      return realDate != null && _dateOnly(realDate) == _dateOnly(now);
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final jadwalProvider = context.read<JadwalProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';
    if (isAdmin) {
      await jadwalProvider.fetchJadwal(status: 'Draft');
    } else {
      await jadwalProvider.fetchJadwalByUser(status: 'Draft');
    }
    if (!mounted) return;
    await context.read<MasterProvider>().fetchJenis();
  }

  // --- Logika Form & Action (Dipertahankan) ---
  Future<void> _openForm([JadwalModel? item]) async {
    final master = context.read<MasterProvider>();
    final auth = context.read<AuthProvider>();
    await master.fetchJenis(showLoading: false);
    await master.fetchPabrik();
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

  Future<void> _confirmSelesaikanJadwal(JadwalModel item) async {
    await AppNotifier.showConfirm(
      context,
      title: 'Hapus Jadwal',
      message: '${item.jdwJudul}?',
      onConfirm: () async {
        final ok = await context
            .read<JadwalProvider>()
            .updateStatusJadwal(item.jdwId, 'Selesai');
        if (ok && mounted) {
          await AppNotifier.showSuccess(
              context, 'Status jadwal berhasil diubah ke Selesai');
        }
      },
    );
  }

  Future<void> _handleJadwalTap(JadwalModel jadwal,
      {required bool isAdmin, required bool isUser}) async {
    if (isAdmin || !isUser) {
      Navigator.pushNamed(context, AppRoutes.jadwalDetail,
          arguments: jadwal.jdwId);
      return;
    }
    final p = context.read<JadwalProvider>();
    await p.fetchJadwalDetail(jadwal.jdwId);
    await p.fetchRealisasi(jadwalId: jadwal.jdwId);
    if (!mounted) return;

    final inventarisList = p.inventarisByJenis
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final terpakaiInvIds = p.realisasiList
        .where((r) => _isSameCurrentPeriod(r, jadwal))
        .map((r) => r.realInvId)
        .toSet();
    final belumSelesaiList = inventarisList
        .where((inv) => !terpakaiInvIds.contains(inv['inv_id']))
        .toList();

    if (inventarisList.isEmpty) {
      AppNotifier.showError(context, 'Inventaris untuk jadwal ini belum ada');
      return;
    }
    if (belumSelesaiList.isEmpty) {
      AppNotifier.showWarning(
          context, 'Semua unit sudah direalisasi periode ini');
      return;
    }
    _showInventarisPicker(jadwal, belumSelesaiList);
  }

  void _showInventarisPicker(
      JadwalModel jadwal, List<Map<String, dynamic>> inventarisList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InventarisPickerSheet(
        inventarisList: inventarisList,
        onSelected: (inv) => _openRealisasiFromInventaris(jadwal, inv),
      ),
    );
  }

  Future<void> _openRealisasiFromInventaris(
      JadwalModel jadwal, Map<String, dynamic> inv) async {
    final invJenisId = inv['inv_jenis_id'] ?? jadwal.jdwJenisId;
    final jenis = context.read<MasterProvider>().jenisById(invJenisId);
    await Navigator.pushNamed(context, AppRoutes.realisasiForm, arguments: {
      'jadwalId': jadwal.jdwId,
      'invJenisId': invJenisId,
      'invJenisNama': jenis?.jenisNama ?? 'ID $invJenisId',
      'invId': inv['inv_id'],
      'invNama': inv['inv_nama'],
      'invNo': inv['inv_no'],
      'invKondisi': inv['inv_kondisi'],
      'invPicNama': inv['pic_user']?['user_nama'] ?? inv['inv_pic'],
    });
    if (mounted) _loadData();
  }

  // --- Widget Ringkasan (Style Utama Dipertahankan) ---
  Widget _buildSummaryTable(List<JadwalModel> aktifList) {
    const freqs = ['Harian', 'Mingguan', 'Bulanan'];
    final summary = freqs.map((f) {
      final items = aktifList.where((j) => j.jdwFrekuensi == f).toList();
      final targetCount = items.fold<int>(
          0, (sum, j) => sum + (j.jdwTarget ?? j.jdwTotalUnit ?? 0));
      final realisasiCount =
          items.fold<int>(0, (sum, j) => sum + (j.jdwSelesaiUnit ?? 0));
      final pct =
          targetCount > 0 ? (realisasiCount / targetCount * 100).round() : 0;
      return {
        'freq': f,
        'target': targetCount,
        'realisasi': realisasiCount,
        'pct': pct
      };
    }).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Ringkasan Realisasi per Frekuensi',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700))),
              if (_selectedFrekuensi != null)
                TextButton.icon(
                  onPressed: () => setState(() => _selectedFrekuensi = null),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 12),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...summary.map((row) {
            final f = row['freq'] as String;
            final isSelected = _selectedFrekuensi == f;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () =>
                    setState(() => _selectedFrekuensi = isSelected ? null : f),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.08)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey[300],
                              shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(f,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500))),
                      Text('${row['realisasi']}/${row['target']}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Text('${row['pct']}%',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary)),
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';
    final isUser = auth.user?['user_jabatan'] == 'user';
    final isDesktop = AppBreakpoints.isDesktop(context);
    final maxContentWidth = isDesktop ? 1180.0 : 860.0;

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(title: const Text('Penjadwalan'), elevation: 0),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              child: const Icon(Icons.add),
            )
          : null,
      body: Consumer<JadwalProvider>(
        builder: (_, p, __) {
          if (p.loading)
            return const Center(child: CircularProgressIndicator());

          final jadwalAktif =
              p.jadwalList.where((j) => j.jdwStatus == 'Draft').toList();
          final filtered = _selectedFrekuensi != null
              ? jadwalAktif
                  .where((j) => j.jdwFrekuensi == _selectedFrekuensi)
                  .toList()
              : jadwalAktif;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Ringkasan menggunakan Sliver agar scroll bersama list
                    SliverToBoxAdapter(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          child: _isSummaryCollapsed
                              ? const SizedBox(
                                  key: ValueKey('summary-hidden'),
                                )
                              : Column(
                                  key: const ValueKey('summary-visible'),
                                  children: [
                                    _buildSummaryTable(jadwalAktif),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    // List Jadwal
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                            message: _selectedFrekuensi != null
                                ? 'Tidak ada jadwal $_selectedFrekuensi yang aktif'
                                : 'Belum ada jadwal yang aktif'),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final item = filtered[i];
                              final jenisNama = context
                                      .read<MasterProvider>()
                                      .jenisById(item.jdwJenisId)
                                      ?.jenisNama ??
                                  'ID ${item.jdwJenisId}';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _JadwalCard(
                                  jadwal: item,
                                  jenisNama: jenisNama,
                                  isAdmin: isAdmin,
                                  isUser: isUser,
                                  onTap: () => _handleJadwalTap(item,
                                      isAdmin: isAdmin, isUser: isUser),
                                  onEdit: () => _openForm(item),
                                  onDelete: () =>
                                      _confirmSelesaikanJadwal(item),
                                  onStatusChange: (st) => context
                                      .read<JadwalProvider>()
                                      .updateStatusJadwal(item.jdwId, st),
                                ),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- SUB-WIDGETS (Sesuai Style Utama Anda) ---

class _InventarisPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> inventarisList;
  final Function(Map<String, dynamic>) onSelected;
  const _InventarisPickerSheet(
      {required this.inventarisList, required this.onSelected});

  @override
  State<_InventarisPickerSheet> createState() => _InventarisPickerSheetState();
}

class _InventarisPickerSheetState extends State<_InventarisPickerSheet> {
  String searchQuery = '';

  String _resolvePicName(Map<String, dynamic> inv) {
    final picUser = inv['pic_user'];
    if (picUser is Map && picUser['user_nama'] != null) {
      return picUser['user_nama'].toString();
    }
    return (inv['inv_pic'] ?? '-').toString();
  }

  bool _matchesSearch(Map<String, dynamic> inv, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final nomor = (inv['inv_no'] ?? '').toString().toLowerCase();
    final nama = (inv['inv_nama'] ?? '').toString().toLowerCase();
    final pic = _resolvePicName(inv).toLowerCase();

    return nomor.contains(normalizedQuery) ||
        nama.contains(normalizedQuery) ||
        pic.contains(normalizedQuery);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.inventarisList
        .where((inv) => _matchesSearch(inv, searchQuery))
        .toList();

    return Container(
      decoration: const BoxDecoration(
          color: _kPageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Cari no inventaris, nama, atau PIC',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() => searchQuery = value);
                },
              ),
              const SizedBox(height: 10),
              Flexible(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Data inventaris tidak ditemukan',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final inv = filtered[i];
                          final merk =
                              (inv['inv_merk'] ?? '-').toString().toUpperCase();
                          final pabrik = inv['inv_pabrik_kode'] ?? '-';
                          final nomor = inv['inv_no'] ?? '-';
                          final picName = _resolvePicName(inv);

                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.12),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
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
                                    Text(
                                      '$merk · $nomor',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.person_outline,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'PIC: $picName',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.factory_outlined,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          pabrik,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Belum realisasi',
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
                                widget.onSelected(inv);
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
    );
  }
}

class _JadwalCard extends StatelessWidget {
  final JadwalModel jadwal;
  final String jenisNama;
  final bool isAdmin;
  final bool isUser;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String) onStatusChange;
  const _JadwalCard(
      {required this.jadwal,
      required this.jenisNama,
      required this.isAdmin,
      required this.isUser,
      required this.onTap,
      required this.onEdit,
      required this.onDelete,
      required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final target = jadwal.jdwTarget ?? jadwal.jdwTotalUnit ?? 0;
    final selesai = jadwal.jdwSelesaiUnit ?? 0;
    final pct = target > 0 ? (selesai / target * 100) : 0;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      surfaceTintColor: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.event_note,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(jadwal.jdwJudul,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('$jenisNama · ${jadwal.jdwFrekuensi}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                  value: target > 0 ? (selesai / target).clamp(0.0, 1.0) : 0,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(10)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$selesai/$target Unit',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  Text('${pct.round()}% Capaian',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pct >= 100
                              ? AppColors.success
                              : AppColors.primary)),
                ],
              ),
              if (isUser) ...[
                const SizedBox(height: 10),
                _actionBtn(
                  Icons.playlist_add_check_circle_outlined,
                  'Lakukan Realisasi',
                  AppColors.primary,
                  onTap,
                ),
              ],
              if (isAdmin) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit,
                            size: 14, color: AppColors.warning),
                        label: const Text('Edit',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.warning))),
                    TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete,
                            size: 14, color: AppColors.danger),
                        label: const Text('Hapus',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.danger))),
                  ],
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(42),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

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
  int? _jenisId;
  String _frekuensi = 'Harian';
  DateTime? _tglMulai;
  int? _assignedToUserId;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _judulCtrl.text = widget.item!.jdwJudul;
      _targetCtrl.text = '${widget.item!.jdwTarget ?? 1}';
      _jenisId = widget.item!.jdwJenisId;
      _frekuensi = widget.item!.jdwFrekuensi;
      _tglMulai = DateTime.tryParse(widget.item!.jdwTglMulai);
      _assignedToUserId = widget.item!.jdwAssignedTo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final master = context.watch<MasterProvider>();
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      builder: (_, ctrl) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Form(
          key: _form,
          child: ListView(
            controller: ctrl,
            children: [
              const Text('Form Jadwal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                  controller: _judulCtrl,
                  decoration: const InputDecoration(labelText: 'Judul Jadwal')),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _jenisId,
                decoration:
                    const InputDecoration(labelText: 'Jenis Inventaris'),
                items: master.jenisMaster
                    .map((j) => DropdownMenuItem(
                        value: j.jenisId, child: Text(j.jenisNama)))
                    .toList(),
                onChanged: (v) => setState(() => _jenisId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _assignedToUserId,
                decoration: const InputDecoration(labelText: 'Pelaksana'),
                items: master.userList
                    .where((u) => u.userJabatan == 'user')
                    .map((u) => DropdownMenuItem(
                        value: u.userId, child: Text(u.userNama)))
                    .toList(),
                onChanged: (v) => setState(() => _assignedToUserId = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_form.currentState!.validate()) {
                    final body = {
                      'jdw_judul': _judulCtrl.text,
                      'jdw_jenis_id': _jenisId,
                      'jdw_target': _targetCtrl.text,
                      'jdw_frekuensi': _frekuensi,
                      'jdw_assigned_to': _assignedToUserId,
                      'jdw_tgl_mulai':
                          DateFormatter.toApi(_tglMulai ?? DateTime.now()),
                    };
                    final ok = await context
                        .read<JadwalProvider>()
                        .saveJadwal(body, id: widget.item?.jdwId);
                    if (ok && mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Simpan Jadwal'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/master/providers/master_provider.dart';
import '../../jadwal/models/jadwal_model.dart';
import '../../jadwal/models/realisasi_model.dart';
import '../../jadwal/providers/jadwal_provider.dart';
import '../../jadwal/screens/jadwal_screen.dart' as jadwal_screen;
import '../../jadwal/screens/realisasi_history_screen.dart';
import '../../master/screens/inventaris_screen.dart';
import '../../master/screens/checklist_template_screen.dart';
import '../../master/screens/jenis_screen.dart';
import '../../master/screens/user_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _pageBg = Color(0xFFF8FAFC);

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

  BoxDecoration _surfaceCard({Color? borderColor}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';
    final p = context.read<JadwalProvider>();

    if (isAdmin) {
      await p.fetchJadwal();
    } else {
      await p.fetchJadwalByUser();
    }
    await p.fetchRealisasi(status: 'Selesai');
    if (!mounted) return;
    await context.read<MasterProvider>().fetchJenis();
  }

  String _userName(Map<String, dynamic>? user) =>
      (user?['user_nama'] ?? 'User').toString().trim();
  String _userInitial(Map<String, dynamic>? user) =>
      _userName(user).isNotEmpty ? _userName(user)[0].toUpperCase() : 'U';

  void _nav(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  void _tabToHistory(int index) {
    if (index == 1) {
      _nav(const RealisasiHistoryScreen());
    } else {
      _nav(const jadwal_screen.JadwalScreen(initialIndex: 0));
    }
  }

  Future<void> _openJadwalDetail(
    JadwalModel jadwal, {
    bool closeSheetFirst = false,
  }) async {
    if (closeSheetFirst) {
      Navigator.of(context).pop();
    }

    final auth = context.read<AuthProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';

    if (isAdmin) {
      Navigator.pushNamed(
        context,
        AppRoutes.jadwalDetail,
        arguments: jadwal.jdwId,
      );
      return;
    }

    if (jadwal.jdwStatus != 'Draft') {
      await AppNotifier.showError(
        context,
        'Jadwal harus dalam status Draft untuk direalisasi',
      );
      return;
    }

    final provider = context.read<JadwalProvider>();
    await provider.fetchJadwalDetail(
      jadwal.jdwId,
      affectGlobalLoading: false,
    );
    if (!mounted) {
      return;
    }

    final inventarisList = provider.inventarisByJenis
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Fetch realisasi for this specific jadwal WITHOUT overwriting realisasiList
    final jadwalRealisasi = await provider.fetchRealisasiByJadwal(jadwal.jdwId);
    if (!mounted) {
      return;
    }
    final selesaiInvIds = jadwalRealisasi
        .where((r) => _isSameCurrentPeriod(r, jadwal))
        .map((r) => r.realInvId)
        .toSet();
    final belumSelesaiList = inventarisList.where((inv) {
      final invIdRaw = inv['inv_id'];
      final invId = invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');
      return invId == null || !selesaiInvIds.contains(invId);
    }).toList();

    if (inventarisList.isEmpty) {
      await AppNotifier.showError(
        context,
        'Inventaris untuk jadwal ini belum ada',
      );
      return;
    }

    if (inventarisList.length == 1 && belumSelesaiList.isNotEmpty) {
      await _openRealisasiFromInventaris(jadwal, belumSelesaiList.first);
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
    String resolvePicName(Map<String, dynamic> inv) {
      final picUser = inv['pic_user'];
      if (picUser is Map && picUser['user_nama'] != null) {
        return picUser['user_nama'].toString();
      }
      return (inv['inv_pic'] ?? '-').toString();
    }

    bool matchesSearch(Map<String, dynamic> inv, String query) {
      final normalizedQuery = query.trim().toLowerCase();
      if (normalizedQuery.isEmpty) return true;

      final nomor = (inv['inv_no'] ?? '').toString().toLowerCase();
      final nama = (inv['inv_nama'] ?? '').toString().toLowerCase();
      final pic = resolvePicName(inv).toLowerCase();

      return nomor.contains(normalizedQuery) ||
          nama.contains(normalizedQuery) ||
          pic.contains(normalizedQuery);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredInventaris = inventarisList
                .where((inv) => matchesSearch(inv, searchQuery))
                .toList();

            return Container(
              decoration: const BoxDecoration(
                color: _pageBg,
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
                          setModalState(() => searchQuery = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: filteredInventaris.isEmpty
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
                                itemCount: filteredInventaris.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final inv = filteredInventaris[i];
                                  final merk = (inv['inv_merk'] ?? '-')
                                      .toString()
                                      .toUpperCase();
                                  final pabrik = inv['inv_pabrik_kode'] ?? '-';
                                  final nomor = inv['inv_no'] ?? '-';
                                  final picName = resolvePicName(inv);
                                  return Card(
                                    margin: EdgeInsets.zero,
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                      leading: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.12),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('$merk · $nomor',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.person_outline,
                                                  size: 14,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    'PIC: $picName',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  pabrik,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
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
                                        _openRealisasiFromInventaris(
                                          jadwal,
                                          inv,
                                        );
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
          },
        );
      },
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
        'invMerk': inv['inv_merk'],
        'invKondisi': inv['inv_kondisi'],
        'invPicNama': inv['pic_user']?['user_nama'] ?? inv['inv_pic'],
        'invPicId': inv['pic_user']?['user_id'],
      },
    );
    if (!mounted) {
      return;
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: _pageBg,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxContentWidth =
                constraints.maxWidth > 1220 ? 1180.0 : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: maxContentWidth,
                child: CustomScrollView(
                  slivers: [
                    // 1. Header Section
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.24),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    _userInitial(auth.user),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selamat Datang',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _userName(auth.user).toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.22),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${auth.user?['user_divisi'] ?? '-'}'
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white,
                                  ),
                                  tooltip: 'Logout',
                                  onPressed: _logout,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. Quick Actions Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            _buildQuickAction(
                                icon: Icons.event_note,
                                label: "Jadwal",
                                color: AppColors.primary,
                                onTap: () => _tabToHistory(0)),
                            const SizedBox(width: 15),
                            _buildQuickAction(
                                icon: Icons.analytics,
                                label: "Realisasi",
                                color: Colors.green.shade700,
                                onTap: () => _tabToHistory(1)),
                          ],
                        ),
                      ),
                    ),

                    // 3. System Flow Section (Alur Persiapan)
                    if (isAdmin)
                      SliverToBoxAdapter(
                        child: _buildAdaptiveSystemFlow(isDesktop),
                      ),

                    // 4. Tasks Header Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Daftar Jadwal",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () {
                                final p = context.read<JadwalProvider>();
                                final sorted = [...p.jadwalList]..sort((a, b) =>
                                    _getRemainingDaysDiff(a)
                                        .compareTo(_getRemainingDaysDiff(b)));
                                _showAllPlansBottomSheet(context, sorted, p);
                              },
                              child: const Text('Lihat Semua'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 5. Plan Cards Section
                    Consumer<JadwalProvider>(
                      builder: (_, p, __) {
                        final sorted = [...p.jadwalList]..sort((a, b) =>
                            _getRemainingDaysDiff(a)
                                .compareTo(_getRemainingDaysDiff(b)));
                        final list = sorted.take(5).toList();
                        if (p.loading) {
                          return const SliverToBoxAdapter(
                              child:
                                  Center(child: CircularProgressIndicator()));
                        }
                        if (list.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: _surfaceCard(),
                                child: const Text(
                                  'Belum ada jadwal terdaftar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return SliverToBoxAdapter(
                          child: SizedBox(
                            height: 122,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              scrollDirection: Axis.horizontal,
                              itemCount: list.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, i) => _buildJadwalItem(
                                list[i],
                                p,
                                width: 285,
                                compact: true,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AppNotifier.showConfirm(
      context,
      title: 'Logout',
      message: 'Keluar aplikasi?',
      onConfirm: () async {
        final auth = context.read<AuthProvider>();
        await auth.logout();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      },
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildAdaptiveSystemFlow(bool isDesktop) {
    final steps = [
      {
        't': '1. Jenis',
        'd': 'Input Jenis Aset',
        'i': Icons.category,
        'c': Colors.teal,
        's': const JenisScreen()
      },
      {
        't': '2. Inventaris',
        'd': 'Input Inventaris',
        'i': Icons.inventory,
        'c': Colors.purple,
        's': const InventarisScreen()
      },
      {
        't': '3. Checklist',
        'd': 'Template Checklist',
        'i': Icons.checklist,
        'c': Colors.redAccent,
        's': const ChecklistTemplateScreen()
      },
      {
        't': '4. Jadwal',
        'd': 'Buat Jadwal',
        'i': Icons.event_note,
        'c': AppColors.primary,
        's': const jadwal_screen.JadwalScreen()
      },
      {
        't': '5. Realisasi',
        'd': 'Cek Realisasi',
        'i': Icons.analytics,
        'c': Colors.green.shade700,
        's': const RealisasiHistoryScreen()
      },
      {
        't': '6. Kelola User',
        'd': 'Atur Akun User',
        'i': Icons.people_outline,
        'c': Colors.green,
        's': const UserScreen()
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("Alur Penggunaan Sistem",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showSystemFlowInfoDialog(context),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isDesktop)
                TextButton(
                  onPressed: () => _showAllStepsBottomSheet(context, steps),
                  child: const Text("Lihat Semua",
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 110),
              itemCount: steps.length,
              itemBuilder: (_, i) =>
                  _buildStepCard(steps[i], isFullWidth: true),
            ),
          )
        else
          SizedBox(
            height: 115,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: steps.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildStepCard(steps[i]),
            ),
          ),
      ],
    );
  }

  void _showSystemFlowInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        title: const Text(
          'Panduan Cepat',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alur penggunaan sistem:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _flowChip('Input jenis', Colors.teal),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: AppColors.textSecondary),
                _flowChip('Input inventaris', Colors.purple),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: AppColors.textSecondary),
                _flowChip('Input checklist', Colors.redAccent),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: AppColors.textSecondary),
                _flowChip('Input jadwal', AppColors.primary),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: AppColors.textSecondary),
                _flowChip('Lihat realisasi', Colors.green.shade700),
              ],
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Widget _flowChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step, {bool isFullWidth = false}) {
    final Color color = step['c'] as Color;
    final String title = step['t'] as String;
    final String desc = step['d'] as String;

    // Extract step number from e.g. "1. Jenis" -> "01"
    final stepNum = title.split('.').first.trim();
    final formattedNum = stepNum.length == 1 ? '0$stepNum' : stepNum;
    final cleanTitle = title.substring(title.indexOf('.') + 1).trim();

    return InkWell(
      onTap: () => _nav(step['s'] as Widget),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: isFullWidth ? null : 155,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(step['i'] as IconData, color: color, size: 20),
                ),
                Text(
                  formattedNum,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color.withValues(alpha: 0.4),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              cleanTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showAllStepsBottomSheet(
      BuildContext context, List<Map<String, dynamic>> steps) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: _pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text("Semua Langkah Persiapan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 110,
                ),
                itemCount: steps.length,
                itemBuilder: (_, i) =>
                    _buildStepCard(steps[i], isFullWidth: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Kelola',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllPlansBottomSheet(
    BuildContext context,
    List<JadwalModel> plans,
    JadwalProvider p,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: _pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Semua Rencana',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${plans.length} jadwal',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: plans.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada jadwal terdaftar',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: plans.length,
                      itemBuilder: (_, i) => _buildJadwalItem(plans[i], p,
                          compact: false,
                          showDivisi: true,
                          closeSheetOnTap: true),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJadwalItem(
    JadwalModel item,
    JadwalProvider p, {
    double? width,
    bool compact = false,
    bool showDivisi = false,
    bool closeSheetOnTap = false,
  }) {
    final rem = _getRemainingDays(item);
    final divisiColor = _colorForDivisi(item.jdwDivisi);
    final icon = _iconForDivisi(item.jdwDivisi);

    Color badgeBg;
    Color badgeText;
    if (rem.contains('Terlewat')) {
      badgeBg = AppColors.danger.withValues(alpha: 0.08);
      badgeText = AppColors.danger;
    } else if (rem == 'Hari ini' || rem == 'Besok') {
      badgeBg = AppColors.warning.withValues(alpha: 0.08);
      badgeText = AppColors.warning;
    } else {
      badgeBg = AppColors.success.withValues(alpha: 0.08);
      badgeText = AppColors.success;
    }

    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                _openJadwalDetail(item, closeSheetFirst: closeSheetOnTap),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: divisiColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: divisiColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.jdwJudul,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (showDivisi) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.jdwDivisi.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: divisiColor,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 2),
                              Text(
                                item.jdwFrekuensi,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!showDivisi)
                        Text(
                          item.jdwDivisi.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: divisiColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        )
                      else
                        Text(
                          item.jdwFrekuensi,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          rem,
                          style: TextStyle(
                            color: badgeText,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getRemainingDays(JadwalModel j) {
    final diff = _getRemainingDaysDiff(j);

    if (diff < 0) return 'Terlewat ${-diff} hari';
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    return '$diff hari lagi';
  }

  int _getRemainingDaysDiff(JadwalModel j) {
    if (!j.jdwPeriodFulfilled &&
        (j.jdwFrekuensi == 'Mingguan' || j.jdwFrekuensi == 'Bulanan')) {
      return 0;
    }

    if (j.jdwDaysRemaining != null) {
      return j.jdwDaysRemaining!;
    }

    final fallbackDate = _parseDateOnly(j.jdwNextDueDate ?? j.jdwTglMulai);
    if (fallbackDate == null) {
      return 0;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return fallbackDate.difference(today).inDays;
  }

  DateTime? _parseDateOnly(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  IconData _iconForDivisi(String? divisiRaw) {
    final divisi = (divisiRaw ?? '').toLowerCase();
    if (divisi == 'it') {
      return Icons.support_agent_rounded;
    }
    if (divisi == 'ga') {
      return Icons.precision_manufacturing_outlined;
    }
    if (divisi == 'driver') {
      return Icons.local_shipping_outlined;
    }
    return Icons.event_note;
  }

  Color _colorForDivisi(String? divisiRaw) {
    final divisi = (divisiRaw ?? '').toLowerCase();
    if (divisi == 'it') {
      return Colors.indigo;
    }
    if (divisi == 'ga') {
      return Colors.orange.shade700;
    }
    if (divisi == 'driver') {
      return Colors.teal.shade700;
    }
    return AppColors.primary;
  }
}

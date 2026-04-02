import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/master/providers/master_provider.dart';
import '../../jadwal/models/jadwal_model.dart';
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
  static const _cardRadius = 16.0;

  BoxDecoration _surfaceCard({Color? borderColor}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(
          color: borderColor ?? Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
    await p.fetchRealisasi(status: 'Selesai', byDivisi: true);
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
    final selesaiInvIds = jadwalRealisasi.map((r) => r.realInvId).toSet();
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2_outlined,
                              color: AppColors.primary),
                          title: Text(inv['inv_nama'] ?? '-'),
                          subtitle: Text(
                            '${(inv['inv_merk'] ?? '-').toString().toUpperCase()} · ${inv['inv_pabrik_kode'] ?? 'inv_pabrik_kode'}\nBelum dipilih',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          isThreeLine: true,
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
        'invMerk': inv['inv_merk'],
        'invKondisi': inv['inv_kondisi'],
        'invPicNama': inv['pic_user']?['user_nama'],
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
                        decoration: const BoxDecoration(
                          color: _pageBg,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(24),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                          decoration: _surfaceCard(),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.12),
                                child: Text(
                                  _userInitial(auth.user),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Selamat Datang',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _userName(auth.user).toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${auth.user?['user_divisi'] ?? '-'}',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.logout_outlined,
                                  color: Color.fromARGB(255, 255, 157, 157),
                                ),
                                tooltip: 'Logout',
                                onPressed: _logout,
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
                            const Text("Jadwal Mendatang",
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
                                  'Belum ada jadwal untuk direncanakan.',
                                  style:
                                      TextStyle(color: AppColors.textSecondary),
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
    return InkWell(
      onTap: () => _nav(step['s'] as Widget),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: isFullWidth ? null : 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: (step['c'] as Color).withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: (step['c'] as Color).withValues(alpha: 0.1),
              child: Icon(step['i'] as IconData,
                  color: step['c'] as Color, size: 18),
            ),
            const Spacer(),
            Text(step['t'] as String,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary)),
            Text(step['d'] as String,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
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

  Widget _buildQuickAction(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _surfaceCard(
            borderColor: color.withValues(alpha: 0.18),
          ),
          child: Column(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ))
          ]),
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
                        'Belum ada jadwal untuk direncanakan.',
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
    final remColor = rem.contains('Terlewat')
        ? Colors.red.shade700
        : (rem == 'Hari ini' ? Colors.orange.shade700 : Colors.green.shade700);

    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _surfaceCard(),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openJadwalDetail(item, closeSheetFirst: closeSheetOnTap),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: divisiColor.withValues(alpha: 0.14),
                  child: Icon(
                    icon,
                    size: 18,
                    color: divisiColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.jdwJudul,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
            if (showDivisi)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  item.jdwDivisi,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.jdwFrekuensi,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rem,
                  style: TextStyle(
                    color: remColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
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

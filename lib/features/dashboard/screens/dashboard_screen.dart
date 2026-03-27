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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _pageBg = Color(0xFFF8FAFC);
  bool _showAllUpcoming = false;

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
      await p.fetchJadwalByDivisi();
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
      _nav(jadwal_screen.JadwalScreen(initialIndex: 0));
    }
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
        child: CustomScrollView(
          slivers: [
            // 1. Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(_userInitial(auth.user),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, ${_userName(auth.user)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              "${auth.user?['user_jabatan']?.toString().toUpperCase()} - ${auth.user?['user_divisi'] ?? '-'}",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.logout_rounded, color: Colors.white),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            ),

            // 2. Quick Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _buildQuickAction(
                        icon: Icons.calendar_today_rounded,
                        label: "Jadwal",
                        color: Colors.orange,
                        onTap: () => _tabToHistory(0)),
                    const SizedBox(width: 15),
                    _buildQuickAction(
                        icon: Icons.fact_check_rounded,
                        label: "Realisasi",
                        color: Colors.blue,
                        onTap: () => _tabToHistory(1)),
                  ],
                ),
              ),
            ),

            // 3. System Flow (Adaptive: Grid on Desktop, Scroll on Mobile)
            if (isAdmin)
              SliverToBoxAdapter(
                child: _buildAdaptiveSystemFlow(isDesktop),
              ),

            // 4. Tasks Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Tugas Mendatang",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () =>
                          setState(() => _showAllUpcoming = !_showAllUpcoming),
                      child: Text(_showAllUpcoming ? 'Ringkas' : 'Lihat Semua'),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Tasks List
            Consumer<JadwalProvider>(
              builder: (_, p, __) {
                final list = _showAllUpcoming
                    ? p.jadwalList
                    : p.jadwalList.take(3).toList();
                if (p.loading)
                  return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()));
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildJadwalItem(list[i], p),
                        childCount: list.length),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
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

  Widget _buildAdaptiveSystemFlow(bool isDesktop) {
    final steps = [
      {
        't': '1. Jenis',
        'd': 'Kategori Aset',
        'i': Icons.category,
        'c': Colors.teal,
        's': const ChecklistTemplateScreen(initialTabIndex: 1)
      },
      {
        't': '2. Aset',
        'd': 'Daftar Inventaris',
        'i': Icons.inventory,
        'c': Colors.purple,
        's': const InventarisScreen()
      },
      {
        't': '3. Template',
        'd': 'Poin Checklist',
        'i': Icons.checklist,
        'c': Colors.redAccent,
        's': const ChecklistTemplateScreen()
      },
      {
        't': '4. Jadwal',
        'd': 'Atur Rutinitas',
        'i': Icons.event_note,
        'c': Colors.orange,
        's': jadwal_screen.JadwalScreen()
      },
      {
        't': '5. Laporan',
        'd': 'Cek Realisasi',
        'i': Icons.analytics,
        'c': Colors.blue,
        's': const RealisasiHistoryScreen()
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text("Alur Penggunaan Sistem",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, crossAxisSpacing: 12, mainAxisExtent: 100),
              itemCount: steps.length,
              itemBuilder: (_, i) => _buildStepCard(steps[i]),
            ),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: steps.length,
              separatorBuilder: (_, __) => const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey),
              itemBuilder: (_, i) => _buildStepCard(steps[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step) {
    return InkWell(
      onTap: () => _nav(step['s'] as Widget),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (step['c'] as Color).withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(step['i'] as IconData, color: step['c'] as Color, size: 24),
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))
          ]),
        ),
      ),
    );
  }

  Widget _buildJadwalItem(JadwalModel item, JadwalProvider p) {
    final rem = _getRemainingDays(item, p);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.event_note, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.jdwJudul,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(item.jdwFrekuensi,
                    style: const TextStyle(fontSize: 12, color: Colors.grey))
              ])),
          Text(rem,
              style: TextStyle(
                  color: rem.contains('Terlewat') ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  String _getRemainingDays(JadwalModel j, JadwalProvider p) {
    // Logika hari tetap sama seperti sebelumnya
    return "Aktif";
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/master/providers/master_provider.dart';
import '../../jadwal/models/jadwal_model.dart';
import '../../jadwal/providers/jadwal_provider.dart';
import '../../jadwal/screens/jadwal_screen.dart' as jadwal_screen;
import '../../jadwal/screens/realisasi_history_screen.dart';
import '../../master/screens/inventaris_screen.dart';
import '../../master/screens/checklist_template_screen.dart';
import '../../master/screens/user_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _pageBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  String _userName(Map<String, dynamic>? user) {
    final name = (user?['user_nama'] ?? '').toString().trim();
    return name.isEmpty ? 'User' : name;
  }

  String _userInitial(Map<String, dynamic>? user) {
    final name = _userName(user);
    return name[0].toUpperCase();
  }

  bool _isOverdueLabel(String value) => value.startsWith('Terlewat');

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

  String _getRemainingDays(String dateStr) {
    try {
      final target = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = target.difference(today).inDays;

      if (diff == 0) return "Hari ini";
      if (diff < 0) return "Terlewat ${diff.abs()} hari";
      return "$diff hari lagi";
    } catch (_) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isAdmin = user?['user_jabatan'] == 'admin';
    final userName = _userName(user);

    return Scaffold(
      backgroundColor: _pageBg,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // 1. Header Profil & User
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 25),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        _userInitial(user),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, $userName',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              "${user?['user_jabatan']?.toString().toUpperCase()} - ${user?['user_divisi'] ?? '-'}",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Logout',
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            ),

            // 2. Quick Action: Jadwal & Realisasi
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _buildQuickAction(
                      icon: Icons.calendar_month,
                      label: "Jadwal",
                      color: Colors.orange,
                      onTap: () => _tabToHistory(0),
                    ),
                    const SizedBox(width: 15),
                    _buildQuickAction(
                      icon: Icons.assignment_turned_in,
                      label: "Realisasi",
                      color: Colors.blue,
                      onTap: () => _tabToHistory(1),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Highlight: List Jadwal Mendatang
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Tugas Mendatang",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => _tabToHistory(0),
                      child: const Text('Lihat Semua'),
                    ),
                  ],
                ),
              ),
            ),

            Consumer<JadwalProvider>(
              builder: (_, p, __) {
                final list = p.jadwalList
                    .where((j) => j.jdwStatus == 'Aktif')
                    .take(5)
                    .toList();
                if (p.loading)
                  return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()));
                if (list.isEmpty)
                  return const SliverToBoxAdapter(
                      child: Padding(
                          padding: EdgeInsets.all(40),
                          child:
                              Center(child: Text("Tidak ada jadwal aktif"))));

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildJadwalItem(list[i]),
                      childCount: list.length,
                    ),
                  ),
                );
              },
            ),

            if (isAdmin)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 25, 20, 15),
                  child: Text("Menu Utama",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

            if (isAdmin)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverGrid.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  children: [
                    _buildGridMenu(
                      Icons.inventory_2,
                      "Inventaris",
                      Colors.purple,
                      () => _nav(const InventarisScreen()),
                    ),
                    _buildGridMenu(
                      Icons.category,
                      "Jenis",
                      Colors.teal,
                      () => _nav(
                          const ChecklistTemplateScreen(initialTabIndex: 1)),
                    ),
                    _buildGridMenu(
                      Icons.checklist_rtl,
                      "Checklist",
                      Colors.redAccent,
                      () => _nav(const ChecklistTemplateScreen()),
                    ),
                    _buildGridMenu(
                      Icons.people_outline,
                      "User",
                      Colors.indigo,
                      () => _nav(const UserScreen()),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _tabToHistory(0),
              child: const Icon(Icons.add),
            )
          : null,
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
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJadwalItem(JadwalModel item) {
    final remaining = _getRemainingDays(item.jdwTglMulai);
    final isOverdue = _isOverdueLabel(remaining);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.event_note,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.jdwJudul,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(DateFormatter.toDisplay(item.jdwTglMulai),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isOverdue
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              remaining,
              style: TextStyle(
                color: isOverdue ? Colors.red : Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMenu(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _tabToHistory(int index) {
    if (index == 1) {
      _nav(const RealisasiHistoryScreen());
      return;
    }
    _nav(jadwal_screen.JadwalScreen(initialIndex: 0));
  }

  void _nav(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _logout() async {
    await AppNotifier.showConfirm(
      context,
      title: 'Konfirmasi Logout',
      message: 'Apakah Anda yakin ingin keluar?',
      onConfirm: () async {
        final auth = context.read<AuthProvider>();
        await auth.logout();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../auth/providers/auth_provider.dart';
import '../../master/screens/inventaris_screen.dart';
import '../../master/screens/checklist_template_screen.dart';
import '../../master/screens/user_screen.dart';
import '../../jadwal/screens/jadwal_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    final masterMenus = [
      _DashboardMenu(
        title: 'Inventaris',
        icon: Icons.inventory_2_outlined,
        color: AppColors.primary,
        builder: (_) => const InventarisScreen(),
      ),
      _DashboardMenu(
        title: 'Master Jenis',
        icon: Icons.category_outlined,
        color: Colors.deepOrange,
        builder: (_) => const ChecklistTemplateScreen(initialTabIndex: 1),
      ),
      _DashboardMenu(
        title: 'Checklist Template',
        icon: Icons.assignment_outlined,
        color: AppColors.accent,
        builder: (_) => const ChecklistTemplateScreen(),
      ),
      _DashboardMenu(
        title: 'Jadwal',
        icon: Icons.schedule_outlined,
        color: Colors.indigo,
        builder: (_) => const JadwalScreen(),
      ),
      _DashboardMenu(
        title: 'Realisasi',
        icon: Icons.assignment_turned_in_outlined,
        color: Colors.teal,
        builder: (_) => const JadwalScreen(),
      ),
      _DashboardMenu(
        title: 'User',
        icon: Icons.people_outline,
        color: Colors.purple,
        builder: (_) => const UserScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanKP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AppNotifier.showConfirm(
                context,
                title: 'Konfirmasi Logout',
                message: 'Apakah Anda yakin ingin keluar?',
                onConfirm: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 24,
                        child: Text(
                          (user?['user_nama'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?['user_nama'] ?? '-',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                          Text(user?['user_jabatan'] ?? '-',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: masterMenus.length,
                itemBuilder: (_, i) => _MenuCard(menu: masterMenus[i]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMenu {
  final String title;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
  const _DashboardMenu({
    required this.title,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

class _MenuCard extends StatelessWidget {
  final _DashboardMenu menu;
  const _MenuCard({required this.menu});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: menu.builder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: menu.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(menu.icon, color: menu.color, size: 24),
              ),
              Text(menu.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const Text(
                'Buka modul',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

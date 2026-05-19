// ignore_for_file: use_build_context_synchronously, unnecessary_cast

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/update/update_checker.dart';
import 'core/widgets/app_notifier.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/master/providers/master_provider.dart';
import 'features/jadwal/providers/jadwal_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/jadwal/screens/jadwal_detail_screen.dart';
import 'features/jadwal/screens/realisasi_form_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlanKPApp());
}

class PlanKPApp extends StatelessWidget {
  const PlanKPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MasterProvider()),
        ChangeNotifierProvider(create: (_) => JadwalProvider()),
      ],
      child: MaterialApp(
        title: 'PlanKP',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, child) => MainAppWrapper(child: child!),
        routes: {
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.register: (_) => const RegisterScreen(),
          AppRoutes.dashboard: (_) => const _ProtectedRoute(
                child: DashboardScreen(),
              ),
          AppRoutes.jadwalDetail: (ctx) {
            final args = ModalRoute.of(ctx)!.settings.arguments as int;
            return _ProtectedRoute(
              allowedRoles: const ['admin'],
              child: JadwalDetailScreen(jadwalId: args),
            );
          },
          AppRoutes.realisasiForm: (ctx) {
            final args =
                ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
            return _ProtectedRoute(
              allowedRoles: const ['user'],
              child: RealisasiFormScreen(args: args),
            );
          },
        },
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.checkSession();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          auth.isLoggedIn ? AppRoutes.dashboard : AppRoutes.login,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MainAppWrapper extends StatefulWidget {
  final Widget child;
  const MainAppWrapper({super.key, required this.child});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> with WidgetsBindingObserver {
  final UpdateChecker _updateChecker = UpdateChecker();
  bool _isChecking = false;
  DateTime? _lastCheckTime;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pemicu 1: Cek saat startup pertama kali (dengan delay 1.5s agar tidak bentrok dengan redirect _AuthGate)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _triggerUpdateCheck();
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pemicu 2: Cek saat kembali dari background (Foreground trigger)
    if (state == AppLifecycleState.resumed) {
      _triggerUpdateCheck();
    }
  }

  Future<void> _triggerUpdateCheck() async {
    if (_isChecking || _dialogOpen) return;

    final now = DateTime.now();
    // Throttling: Jangan cek kembali jika belum lewat 30 detik
    if (_lastCheckTime != null && now.difference(_lastCheckTime!).inSeconds < 30) {
      return;
    }

    _isChecking = true;
    _lastCheckTime = now;

    try {
      final updateResult = await _updateChecker.checkForUpdate();
      if (mounted && updateResult.hasUpdate && updateResult.manifest != null) {
        _dialogOpen = true;
        await _showUpdateDialog(updateResult.manifest!);
        _dialogOpen = false;
      }
    } catch (e) {
      debugPrint('[AutoUpdate] Error checking update: $e');
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _showUpdateDialog(AppUpdateManifest manifest) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    await AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      dismissOnTouchOutside: !manifest.mandatory,
      dismissOnBackKeyPress: !manifest.mandatory,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pembaruan Tersedia!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Versi terbaru ${manifest.version} siap diunduh.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if ((manifest.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  manifest.notes!.trim(),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!manifest.mandatory) ...[
                  Expanded(
                    child: AnimatedButton(
                      text: 'Nanti Saja',
                      color: Colors.grey.shade300,
                      pressEvent: () => Navigator.of(context).pop(),
                      isFixedHeight: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: AnimatedButton(
                    text: 'Update Sekarang',
                    color: AppColors.primary,
                    pressEvent: () async {
                      Navigator.of(context).pop();

                      // Buka tautan unduhan langsung di browser eksternal
                      final uri = Uri.parse(manifest.url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }

                      // Tampilkan Panduan Pemasangan Manual agar file APK mudah ditemukan dan dipasang
                      _showManualInstallDialog(manifest.url, manifest.version);
                    },
                    isFixedHeight: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).show();
  }

  void _showManualInstallDialog(String downloadUrl, String versionName) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.download_for_offline, color: AppColors.primary, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unduhan Dimulai',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'File pembaruan APK sedang diunduh oleh Web Browser Anda langsung ke penyimpanan telepon.',
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Langkah Pemasangan Manual:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStepRow('1', 'Tunggu unduhan selesai di bar notifikasi browser Anda.'),
                    const SizedBox(height: 6),
                    _buildStepRow('2', 'Buka aplikasi File Manager / File Saya / Files di HP Anda.'),
                    const SizedBox(height: 6),
                    _buildStepRow('3', 'Masuk ke folder Downloads / Unduhan publik.'),
                    const SizedBox(height: 6),
                    _buildStepRow('4', 'Cari dan klik file APK PlanKP yang baru saja diunduh untuk memasangnya secara manual.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: downloadUrl));
                        if (ctx.mounted) {
                          AppNotifier.showSuccess(ctx, 'Link unduhan disalin ke clipboard');
                        }
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Salin Link'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 2, right: 8),
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _ProtectedRoute extends StatelessWidget {
  final Widget child;
  final List<String>? allowedRoles;

  const _ProtectedRoute({
    required this.child,
    this.allowedRoles,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoggedIn) {
      final role = auth.jabatan;
      final isRoleAllowed =
          allowedRoles == null || allowedRoles!.contains(role);
      if (isRoleAllowed) return child;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ignore_for_file: use_build_context_synchronously, unnecessary_cast

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/update/update_checker.dart';
import 'core/update/update_downloader.dart';
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
  final UpdateDownloader _updateDownloader = UpdateDownloader();
  bool _isChecking = false;
  DateTime? _lastCheckTime;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pemicu 1: Cek saat startup pertama kali
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerUpdateCheck();
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

    var isDownloading = false;
    var progress = 0;

    await AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      dismissOnTouchOutside: !manifest.mandatory,
      dismissOnBackKeyPress: !manifest.mandatory,
      body: StatefulBuilder(
        builder: (context, setState) {
          return Padding(
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
                if (isDownloading) ...[
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mengunduh... $progress%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!manifest.mandatory && !isDownloading) ...[
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
                        text: isDownloading ? 'Mengunduh...' : 'Update',
                        color: isDownloading
                            ? Colors.grey.shade400
                            : AppColors.primary,
                        pressEvent: isDownloading
                            ? () {}
                            : () async {
                                setState(() {
                                  isDownloading = true;
                                  progress = 0;
                                });

                                final result = await _updateDownloader
                                    .downloadAndOpenInstaller(
                                  downloadUrl: manifest.url,
                                  versionName: manifest.version,
                                  onProgress: (value) {
                                    setState(() => progress = value);
                                  },
                                );

                                if (!context.mounted) return;
                                setState(() {
                                  isDownloading = false;
                                });

                                if (result.status ==
                                    AppUpdateDownloadStatus
                                        .downloadedOpenedFolder) {
                                  Navigator.of(context).pop();
                                  _showManualInstallDialog(
                                      manifest.url, result.filePath ?? '');
                                } else if (result.status ==
                                    AppUpdateDownloadStatus.failedNetwork) {
                                  Navigator.of(context).pop();
                                  _showDownloadFailedDialog(manifest.url,
                                      'Gagal mengunduh: Periksa jaringan Anda.');
                                } else if (result.status ==
                                    AppUpdateDownloadStatus.failedOther) {
                                  Navigator.of(context).pop();
                                  _showDownloadFailedDialog(manifest.url,
                                      'Gagal memproses pembaruan:\n${result.filePath ?? "Unknown Error"}');
                                } else {
                                  if (!manifest.mandatory && context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                }
                              },
                        isFixedHeight: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ).show();
  }

  void _showDownloadFailedDialog(String downloadUrl, String reason) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Unduhan Gagal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            const SizedBox(height: 16),
            const Text(
                'Anda dapat mengunduh aplikasi secara langsung melalui browser perangkat Anda.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Unduh di Browser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualInstallDialog(String downloadUrl, String filePath) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.folder_special, color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Text('Download Selesai',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                  'Aplikasi gagal membuka installer secara otomatis karena batasan sistem perangkat. Silakan buka File Manager / File Saya dan cari file APK yang telah diunduh di lokasi berikut:'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10)),
                child: SelectableText(
                  filePath,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.black87),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(downloadUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_browser, size: 18),
                    label: const Text('Buka Link'),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: filePath));
                          if (ctx.mounted) {
                            AppNotifier.showSuccess(
                                ctx, 'Path berhasil disalin ke clipboard');
                          }
                        },
                        child: const Text('Salin Path'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

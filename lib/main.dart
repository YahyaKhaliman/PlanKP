// ignore_for_file: use_build_context_synchronously, unnecessary_cast

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
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
  final UpdateChecker _updateChecker = UpdateChecker();
  final UpdateDownloader _updateDownloader = UpdateDownloader();

  Future<void> _showUpdateDialog(AppUpdateManifest manifest) async {
    var isDownloading = false;
    var progress = 0;

    await showDialog<void>(
      context: context,
      barrierDismissible: !manifest.mandatory,
      builder: (dialogContext) {
        return PopScope(
          canPop: !manifest.mandatory,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 16,
                          offset: Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.system_update_rounded,
                            size: 48, color: AppColors.primary),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Pembaruan Tersedia!',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Versi terbaru ${manifest.version} siap diunduh.',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      if ((manifest.notes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            manifest.notes!.trim(),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87),
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
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (!manifest.mandatory && !isDownloading)
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  side:
                                      const BorderSide(color: Colors.grey),
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('Nanti Saja',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                          if (!manifest.mandatory && !isDownloading)
                            const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: isDownloading
                                  ? null
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

                                      if (!dialogContext.mounted) return;
                                      setState(() {
                                        isDownloading = false;
                                      });

                                      if (result.status ==
                                          AppUpdateDownloadStatus
                                              .downloadedOpenedFolder) {
                                        Navigator.of(dialogContext).pop();
                                        _showManualInstallDialog(
                                            result.filePath ?? '');
                                      } else if (result.status ==
                                          AppUpdateDownloadStatus
                                              .failedNetwork) {
                                        AppNotifier.showError(
                                            dialogContext,
                                            'Gagal mengunduh: Periksa jaringan Anda.');
                                      } else if (result.status ==
                                          AppUpdateDownloadStatus.failedOther) {
                                        AppNotifier.showError(
                                            dialogContext,
                                            'Gagal memproses pembaruan.');
                                      } else {
                                        // Success
                                        if (!manifest.mandatory &&
                                            dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                      }
                                    },
                              child: Text(
                                isDownloading
                                    ? 'Mengunduh...'
                                    : 'Update Sekarang',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showManualInstallDialog(String filePath) {
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: filePath));
                      if (ctx.mounted) {
                        AppNotifier.showSuccess(
                            ctx, 'Path berhasil disalin ke clipboard');
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Salin Path'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: const Text('Tutup'),
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();

      final updateResult = await _updateChecker.checkForUpdate();
      if (mounted && updateResult.hasUpdate && updateResult.manifest != null) {
        await _showUpdateDialog(updateResult.manifest!);
      }

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

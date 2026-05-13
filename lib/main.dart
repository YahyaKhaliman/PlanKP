// ignore_for_file: use_build_context_synchronously, unnecessary_cast

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/update/update_checker.dart';
import 'core/update/update_downloader.dart';
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
          child: AlertDialog(
            title: const Text('Update Tersedia'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Versi terbaru: ${manifest.version} (${manifest.buildNumber})'),
                  if ((manifest.notes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Catatan rilis:'),
                    const SizedBox(height: 4),
                    Text(manifest.notes!.trim()),
                  ],
                  if (isDownloading) ...[
                    const SizedBox(height: 12),
                    Text('Mengunduh update... $progress%'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress / 100),
                  ],
                ],
              ),
            ),
            actions: [
              if (!manifest.mandatory)
                TextButton(
                  onPressed: isDownloading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Nanti'),
                ),
              FilledButton(
                onPressed: isDownloading
                    ? null
                    : () async {
                        (dialogContext as Element).markNeedsBuild();
                        isDownloading = true;
                        progress = 0;

                        final result =
                            await _updateDownloader.downloadAndOpenInstaller(
                          downloadUrl: manifest.url,
                          versionName: manifest.version,
                          onProgress: (value) {
                            progress = value;
                            if (dialogContext.mounted) {
                              (dialogContext as Element).markNeedsBuild();
                            }
                          },
                        );

                        isDownloading = false;
                        if (dialogContext.mounted) {
                          (dialogContext as Element).markNeedsBuild();
                        }

                        if (!dialogContext.mounted) return;

                        final messenger =
                            ScaffoldMessenger.maybeOf(dialogContext);

                        switch (result.status) {
                          case AppUpdateDownloadStatus
                                .downloadedOpenedInstaller:
                            messenger?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Download selesai. Installer APK dibuka untuk instalasi manual.',
                                ),
                              ),
                            );
                            break;
                          case AppUpdateDownloadStatus.downloadedOpenedFolder:
                            messenger?.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Download selesai. Silakan buka file APK secara manual di: ${result.filePath ?? '-'}',
                                ),
                              ),
                            );
                            break;
                          case AppUpdateDownloadStatus.failedNetwork:
                            messenger?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Gagal mengunduh update karena masalah jaringan.',
                                ),
                              ),
                            );
                            return;
                          case AppUpdateDownloadStatus.failedOther:
                            messenger?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Gagal memproses update. Coba lagi beberapa saat.',
                                ),
                              ),
                            );
                            return;
                        }

                        if (!manifest.mandatory && dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: Text(isDownloading ? 'Mengunduh...' : 'Download Update'),
              ),
            ],
          ),
        );
      },
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

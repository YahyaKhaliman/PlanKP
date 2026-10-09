// ignore_for_file: use_build_context_synchronously, unnecessary_cast

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/update/update_checker.dart';
import 'core/update/update_downloader.dart';
import 'core/update/update_service.dart';
import 'core/utils/web_reload/web_reload.dart';
import 'core/widgets/app_notifier.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/master/providers/master_provider.dart';
import 'features/jadwal/providers/jadwal_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/jadwal/screens/jadwal_detail_screen.dart';
import 'features/jadwal/screens/realisasi_form_screen.dart';
import 'features/dashboard/screens/monitoring_divisi_screen.dart';
import 'features/voucher/providers/voucher_provider.dart';
import 'features/voucher/screens/voucher_screen.dart';
import 'features/voucher/screens/voucher_form_screen.dart';

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
        ChangeNotifierProvider(create: (_) => VoucherProvider()),
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
            final rawArgs = ModalRoute.of(ctx)!.settings.arguments;
            var args =
                rawArgs is int ? rawArgs : int.tryParse('$rawArgs') ?? 0;
            if (args <= 0) {
              final queryId = Uri.base.queryParameters['id'] ??
                  Uri.base.queryParameters['jdw_id'];
              if (queryId != null) {
                args = int.tryParse(queryId) ?? 0;
              }
            }
            return _ProtectedRoute(
              child: JadwalDetailScreen(jadwalId: args),
            );
          },
          AppRoutes.realisasiForm: (ctx) {
            final args =
                ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
            return _ProtectedRoute(
              allowedRoles: const ['user', 'teknisi', 'it_support'],
              child: RealisasiFormScreen(args: args),
            );
          },
          AppRoutes.monitoringDivisi: (_) => const _ProtectedRoute(
                allowedRoles: ['manager'],
                child: MonitoringDivisiScreen(),
              ),
          AppRoutes.voucher: (_) => const _ProtectedRoute(
                child: VoucherScreen(),
              ),
          AppRoutes.voucherForm: (_) => const _ProtectedRoute(
                child: VoucherFormScreen(),
              ),
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                width: 56,
                height: 56,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'PlanKP',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Maintenance Planning',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainAppWrapper extends StatefulWidget {
  final Widget child;
  const MainAppWrapper({super.key, required this.child});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper>
    with WidgetsBindingObserver {
  final UpdateService _updateService = UpdateService.instance;
  bool _isChecking = false;
  bool _dialogOpen = false;
  bool _webBannerDismissed = false;
  Timer? _webUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pemicu 1: Cek saat startup pertama kali (delay 1.5s agar tidak bentrok dengan _AuthGate)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _triggerUpdateCheck();
      });
    });

    // Pemicu khusus Web: Cek berkala setiap 2 menit saat aplikasi sedang dibuka
    if (kIsWeb) {
      _webUpdateTimer = Timer.periodic(const Duration(minutes: 2), (_) {
        if (mounted) _triggerUpdateCheck();
      });
    }
  }

  @override
  void dispose() {
    _webUpdateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pemicu 2: Cek saat kembali dari background atau tab browser kembali aktif (force check)
    if (state == AppLifecycleState.resumed) {
      _triggerUpdateCheck(force: kIsWeb);
    }
  }

  Future<void> _triggerUpdateCheck({bool force = false}) async {
    if (_isChecking || _dialogOpen) return;
    _isChecking = true;

    try {
      // Khusus Flutter Web: Cek versi server web dan munculkan WebUpdateDialog
      if (kIsWeb) {
        final navContext = navigatorKey.currentContext;
        if (navContext != null && mounted) {
          await _updateService.checkAndPromptWebUpdate(navContext,
              force: force);
        }
        return;
      }

      // Android: Throttle & skip sudah dihandle di dalam UpdateService
      final result = await _updateService.checkForUpdate();
      if (mounted &&
          result != null &&
          result.hasUpdate &&
          result.manifest != null) {
        _dialogOpen = true;
        await _showUpdateDialog(result.manifest!);
        _dialogOpen = false;
      }
    } catch (e) {
      debugPrint('[AutoUpdate] Error: $e');
    } finally {
      _isChecking = false;
    }
  }

  // ─── Dialog 1: Pemberitahuan Update Tersedia ───
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
            Text(
              'Versi Baru Tersedia!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Perbarui ke v${manifest.version} untuk mendapatkan versi terbaru.',
              style: GoogleFonts.plusJakartaSans(
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  manifest.notes!.trim(),
                  style: GoogleFonts.plusJakartaSans(
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
                      color: AppColors.surfaceAlt,
                      buttonTextStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                      pressEvent: () async {
                        // Simpan skip agar tidak ditanya lagi untuk versi ini
                        await _updateService.skipVersion(manifest.buildNumber);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      isFixedHeight: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: AnimatedButton(
                    text: 'Update Sekarang',
                    color: AppColors.primary,
                    buttonTextStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, color: Colors.white),
                    pressEvent: () {
                      Navigator.of(context).pop();
                      _startDownloadAndInstall(manifest);
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

  // ─── Proses Download + Install (In-App) ───
  Future<void> _startDownloadAndInstall(AppUpdateManifest manifest) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Cek dulu apakah file sudah ada di lokal
    final existingPath = await _updateService.checkLocalApk(
      downloadUrl: manifest.url,
      versionName: manifest.version,
    );

    if (existingPath != null && context.mounted) {
      // File sudah ada → tampilkan dialog "File ditemukan" lalu coba install
      _showLocalFileFoundDialog(manifest, existingPath);
      return;
    }

    // File belum ada → tampilkan dialog download progress
    if (context.mounted) {
      _showDownloadProgressDialog(manifest);
    }
  }

  // ─── Dialog 2: File APK Sudah Ada di Lokal ───
  void _showLocalFileFoundDialog(AppUpdateManifest manifest, String filePath) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.successSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: AppColors.success, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'APK Sudah Diunduh',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'File PlanKP v${manifest.version} sudah ada di perangkat Anda, langsung install?',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        if (!kIsWeb) {
                          try {
                            await UpdateDownloader.deleteFile(filePath);
                          } catch (_) {}
                        }
                        // Download ulang dari awal
                        _showDownloadProgressDialog(manifest);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Unduh Ulang',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        // Langsung coba install dari file lokal
                        final result = await _updateService.downloadAndInstall(
                          manifest: manifest,
                        );
                        _handleInstallResult(result, manifest);
                      },
                      icon: const Icon(Icons.install_mobile, size: 18),
                      label: Text(
                        'Pasang',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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

  // ─── Dialog 3: Progress Download In-App ───
  void _showDownloadProgressDialog(AppUpdateManifest manifest) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final progressNotifier = ValueNotifier<double>(0.0);
    bool isCancelled = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mengunduh Pembaruan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, percent, _) => Column(
                  children: [
                    LinearProgressIndicator(
                      value: percent > 0 ? percent : null,
                      backgroundColor: AppColors.surfaceAlt,
                      color: AppColors.primary,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(percent * 100).round()}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        isCancelled = true;
                        Navigator.of(ctx).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Batalkan',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Mulai download
    _updateService
        .downloadAndInstall(
      manifest: manifest,
      onProgress: (percent) {
        if (!isCancelled) {
          progressNotifier.value = (percent / 100.0).clamp(0.0, 1.0);
        }
      },
    )
        .then((result) {
      // Tutup dialog progress jika masih terbuka
      final navContext = navigatorKey.currentContext;
      if (navContext != null && !isCancelled) {
        Navigator.of(navContext, rootNavigator: true).pop();
      }
      if (!isCancelled) {
        _handleInstallResult(result, manifest);
      }
    });
  }

  // ─── Handle Hasil Install ───
  void _handleInstallResult(
      AppUpdateDownloadResult result, AppUpdateManifest manifest) {
    switch (result.status) {
      case AppUpdateDownloadStatus.downloadedOpenedInstaller:
      case AppUpdateDownloadStatus.alreadyDownloaded:
        // Berhasil membuka installer — tidak perlu tindakan tambahan
        break;
      case AppUpdateDownloadStatus.openedBrowserFallback:
        // Fallback ke browser berhasil → tampilkan panduan manual
        _showManualInstallGuide(manifest.url, manifest.version);
        break;
      case AppUpdateDownloadStatus.downloadedOpenedFolder:
      case AppUpdateDownloadStatus.failedNetwork:
      case AppUpdateDownloadStatus.failedOther:
        // Gagal total → tampilkan panduan manual juga
        _showManualInstallGuide(manifest.url, manifest.version);
        break;
    }
  }

  // ─── Dialog 4: Panduan Install Manual (Fallback Terakhir) ───
  void _showManualInstallGuide(String downloadUrl, String versionName) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.download_for_offline,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Panduan Pemasangan',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'File APK sedang diunduh oleh browser. Ikuti langkah berikut untuk memasang pembaruan:',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepRow('1',
                        'Tunggu unduhan selesai di bar notifikasi browser Anda.'),
                    const SizedBox(height: 6),
                    _buildStepRow('2',
                        'Buka aplikasi File Manager / File Saya di HP Anda.'),
                    const SizedBox(height: 6),
                    _buildStepRow('3', 'Masuk ke folder Downloads / Unduhan.'),
                    const SizedBox(height: 6),
                    _buildStepRow('4',
                        'Cari dan klik file APK PlanKP untuk memasangnya.'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.support_agent_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mengalami kendala install? Silakan hubungi IT Support.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: downloadUrl));
                        if (ctx.mounted) {
                          AppNotifier.showSuccess(
                              ctx, 'Link unduhan disalin ke clipboard');
                        }
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(
                        'Salin Link',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Tutup',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700),
                      ),
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
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildTopWebUpdateBanner(AppUpdateCheckResult update) {
    final newVer = update.manifest?.version;
    final verText = (newVer != null && newVer.isNotEmpty) ? ' (v$newVer)' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        color: Color(0xFF1E3A8A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Versi baru tersedia$verText. Simpan inputan Anda, lalu refresh halaman.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => reloadWebPage(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A8A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: Text(
                'Refresh Halaman',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 17),
              tooltip: 'Tutup sementara',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _webBannerDismissed = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;

    return ValueListenableBuilder<AppUpdateCheckResult?>(
      valueListenable: _updateService.webUpdateAvailable,
      builder: (context, updateResult, _) {
        final hasUpdate = updateResult != null && updateResult.hasUpdate;
        final showBanner = hasUpdate && !_webBannerDismissed;

        return Material(
          color: Colors.transparent,
          child: Column(
            children: [
              if (showBanner) _buildTopWebUpdateBanner(updateResult),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
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
      final role = auth.jabatan.toLowerCase();
      final isRoleAllowed = allowedRoles == null ||
          allowedRoles!.map((r) => r.toLowerCase()).contains(role);
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

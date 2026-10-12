import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppUpdateDownloadStatus {
  alreadyDownloaded,
  downloadedOpenedInstaller,
  downloadedOpenedFolder,
  openedBrowserFallback,
  failedNetwork,
  failedOther,
}

class AppUpdateDownloadResult {
  final AppUpdateDownloadStatus status;
  final String? filePath;

  const AppUpdateDownloadResult({required this.status, this.filePath});
}

class UpdateDownloader {
  final Dio _dio;

  UpdateDownloader({Dio? dio}) : _dio = dio ?? Dio();

  /// Hapus file di path tertentu. Aman di Web (langsung return).
  static Future<void> deleteFile(String filePath) async {
    if (kIsWeb) return;
    try {
      final f = File(filePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Cek apakah sebuah file adalah file APK yang valid (berukuran > 5MB dan memiliki header ZIP/APK)
  static Future<bool> isLikelyValidApk(File file) async {
    try {
      if (!await file.exists()) return false;
      final len = await file.length();
      if (len < 5 * 1024 * 1024) return false;

      // Periksa magic bytes ZIP/APK (0x50, 0x4B, 0x03, 0x04)
      final raf = await file.open(mode: FileMode.read);
      try {
        final header = await raf.read(4);
        if (header.length == 4 &&
            header[0] == 0x50 &&
            header[1] == 0x4B &&
            header[2] == 0x03 &&
            header[3] == 0x04) {
          return true;
        }
      } finally {
        await raf.close();
      }
    } catch (e) {
      debugPrint('[UpdateDownloader] Error isLikelyValidApk: $e');
    }
    return false;
  }

  // ─── Cek apakah APK versi tertentu sudah ada di storage lokal & valid ───
  Future<String?> checkLocalApk({
    required String downloadUrl,
    required String versionName,
  }) async {
    if (kIsWeb) return null;
    try {
      final fileName = _resolveFileName(downloadUrl, versionName);
      final cleanVersion = versionName.replaceAll(RegExp(r'[^0-9.]'), '');
      final dirs = await _getCandidateDirectories();

      final candidateNames = <String>{
        fileName,
        'PlanKP-v$versionName.apk',
        'PlanKP_v$versionName.apk',
        'PlanKP-$versionName.apk',
        'PlanKP-v$cleanVersion.apk',
        'PlanKP.apk',
      };

      for (final dir in dirs) {
        if (!await dir.exists()) continue;

        // 1. Cek langsung nama-nama kandidat
        for (final name in candidateNames) {
          final file = File('${dir.path}/$name');
          if (await isLikelyValidApk(file)) {
            debugPrint('[UpdateDownloader] APK lokal valid ditemukan: ${file.path}');
            return file.path;
          }
        }

        // 2. Scan file di direktori untuk mencakup unduhan browser dengan penomoran (contoh: PlanKP-v1.0.8 (1).apk)
        try {
          final entities = dir.listSync(followLinks: false);
          for (final entity in entities) {
            if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
              final base = entity.uri.pathSegments.last.toLowerCase();
              final matchesVersion = base.contains(versionName.toLowerCase()) ||
                  (cleanVersion.isNotEmpty && base.contains(cleanVersion));
              final matchesApp = base.contains('plankp') ||
                  (fileName.isNotEmpty &&
                      base.contains(fileName.toLowerCase().replaceAll('.apk', '')));

              if (matchesVersion && matchesApp && await isLikelyValidApk(entity)) {
                debugPrint('[UpdateDownloader] APK lokal scan ditemukan: ${entity.path}');
                return entity.path;
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[UpdateDownloader] Error cek file lokal: $e');
    }
    return null;
  }


  // ─── Download + Install dengan 3 lapis fallback ───
  Future<AppUpdateDownloadResult> downloadAndInstall({
    required String downloadUrl,
    required String versionName,
    void Function(int percent)? onProgress,
  }) async {
    if (kIsWeb) {
      return const AppUpdateDownloadResult(status: AppUpdateDownloadStatus.failedOther);
    }
    // Langkah 1: Cek apakah file sudah ada & valid di lokal
    final existingPath = await checkLocalApk(
      downloadUrl: downloadUrl,
      versionName: versionName,
    );

    if (existingPath != null) {
      debugPrint('[UpdateDownloader] File sudah ada & valid, langsung install...');
      final installResult = await _tryInstallApk(existingPath);
      if (installResult != null) return installResult;

      // Jika install gagal meskipun file ada → cek apakah file corrupt sebelum dihapus
      debugPrint('[UpdateDownloader] Install file lokal belum berhasil...');
      if (!await isLikelyValidApk(File(existingPath))) {
        debugPrint('[UpdateDownloader] File lokal terdeteksi corrupt, hapus dan download ulang...');
        try {
          await File(existingPath).delete();
        } catch (_) {}
      }
    }

    // Langkah 2: Download file baru ke file temporary (.tmp)
    final baseDir = await _getDownloadDirectory();
    final fileName = _resolveFileName(downloadUrl, versionName);
    final finalFile = File('${baseDir.path}/$fileName');
    final tempFile = File('${baseDir.path}/$fileName.tmp');

    try {
      // Hapus file temp bekas jika ada
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      onProgress?.call(0);

      await _dio.download(
        downloadUrl,
        tempFile.path,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final percent = ((received / total) * 100).round().clamp(0, 100);
          onProgress?.call(percent);
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (code) => code != null && code >= 200 && code < 400,
        ),
      );

      onProgress?.call(100);

      // Setelah unduhan selesai 100%, ubah nama temp file ke file APK akhir
      if (await tempFile.exists()) {
        if (await finalFile.exists()) {
          try {
            await finalFile.delete();
          } catch (_) {}
        }
        await tempFile.rename(finalFile.path);
      }

      // Langkah 3: Coba install file yang baru didownload
      final installResult = await _tryInstallApk(finalFile.path);
      if (installResult != null) return installResult;

      // Semua cara install gagal → fallback ke browser
      return await _fallbackToBrowser(downloadUrl);
    } on DioException catch (e) {
      // Bersihkan file temp jika download terputus
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      final message = (e.message ?? '').toLowerCase();
      final networkError =
          e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.connectionError ||
              message.contains('network') ||
              message.contains('timeout') ||
              message.contains('failed host lookup') ||
              message.contains('connection');

      // Jika network error → fallback ke browser
      if (networkError) {
        return await _fallbackToBrowser(downloadUrl);
      }

      return const AppUpdateDownloadResult(
        status: AppUpdateDownloadStatus.failedOther,
      );
    } catch (e) {
      debugPrint('[UpdateDownloader] Error download: $e');
      return await _fallbackToBrowser(downloadUrl);
    }
  }

  // ─── 3-Layer Install Fallback ───

  /// Coba install APK dengan 2 lapis:
  /// 1. OpenFilex.open()
  /// 2. Intent langsung via url_launcher
  /// Return null jika semua gagal (caller harus handle fallback browser)
  Future<AppUpdateDownloadResult?> _tryInstallApk(String filePath) async {
    // Lapis 1: OpenFilex.open()
    try {
      debugPrint('[UpdateDownloader] Lapis 1: OpenFilex.open($filePath)');
      final openResult = await OpenFilex.open(filePath);
      if (openResult.type == ResultType.done) {
        return AppUpdateDownloadResult(
          status: AppUpdateDownloadStatus.downloadedOpenedInstaller,
          filePath: filePath,
        );
      }
      debugPrint('[UpdateDownloader] OpenFilex gagal: ${openResult.message}');
    } catch (e) {
      debugPrint('[UpdateDownloader] OpenFilex error: $e');
    }

    // Lapis 2: Intent langsung via url_launcher (content:// URI)
    try {
      debugPrint('[UpdateDownloader] Lapis 2: Intent langsung via file URI');
      final fileUri = Uri.file(filePath);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        return AppUpdateDownloadResult(
          status: AppUpdateDownloadStatus.downloadedOpenedInstaller,
          filePath: filePath,
        );
      }
      debugPrint('[UpdateDownloader] Intent file URI gagal');
    } catch (e) {
      debugPrint('[UpdateDownloader] Intent error: $e');
    }

    // Semua lapis gagal
    return null;
  }

  /// Lapis 3: Fallback ke browser eksternal
  Future<AppUpdateDownloadResult> _fallbackToBrowser(String downloadUrl) async {
    debugPrint('[UpdateDownloader] Lapis 3: Fallback ke browser');
    try {
      String urlWithCacheBuster = downloadUrl;
      if (urlWithCacheBuster.contains('?')) {
        urlWithCacheBuster +=
            '&t=${DateTime.now().millisecondsSinceEpoch}';
      } else {
        urlWithCacheBuster +=
            '?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      final uri = Uri.parse(urlWithCacheBuster);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[UpdateDownloader] Browser fallback error: $e');
    }

    return const AppUpdateDownloadResult(
      status: AppUpdateDownloadStatus.openedBrowserFallback,
    );
  }

  // ─── Helpers ───

  Future<Directory> _getDownloadDirectory() async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      baseDir = await getExternalStorageDirectory();
    }
    baseDir ??= await getTemporaryDirectory();
    return baseDir;
  }

  Future<List<Directory>> _getCandidateDirectories() async {
    final dirs = <Directory>[];
    final seenPaths = <String>{};

    void addDir(Directory? dir) {
      if (dir != null && seenPaths.add(dir.path)) {
        dirs.add(dir);
      }
    }

    try {
      if (Platform.isAndroid) {
        addDir(await getExternalStorageDirectory());
        try {
          final downloads = await getDownloadsDirectory();
          addDir(downloads);
        } catch (_) {}

        final publicDownloadPaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/sdcard/Download',
          '/sdcard/Downloads',
        ];
        for (final p in publicDownloadPaths) {
          try {
            final d = Directory(p);
            if (await d.exists()) {
              addDir(d);
            }
          } catch (_) {}
        }
      }
      addDir(await getTemporaryDirectory());
    } catch (_) {}
    return dirs;
  }

  String _resolveFileName(String downloadUrl, String versionName) {
    final uri = Uri.tryParse(downloadUrl);
    final candidate = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';

    if (candidate.toLowerCase().endsWith('.apk')) {
      return candidate;
    }

    return 'PlanKP-v$versionName.apk';
  }
}

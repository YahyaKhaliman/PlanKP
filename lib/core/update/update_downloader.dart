import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  // ─── Cek apakah APK versi tertentu sudah ada di storage lokal ───
  Future<String?> checkLocalApk({
    required String downloadUrl,
    required String versionName,
  }) async {
    try {
      final fileName = _resolveFileName(downloadUrl, versionName);
      final dirs = await _getCandidateDirectories();

      for (final dir in dirs) {
        final file = File('${dir.path}/$fileName');
        if (await file.exists() && await file.length() > 0) {
          debugPrint('[UpdateDownloader] APK lokal ditemukan: ${file.path}');
          return file.path;
        }
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
    // Langkah 1: Cek apakah file sudah ada di lokal
    final existingPath = await checkLocalApk(
      downloadUrl: downloadUrl,
      versionName: versionName,
    );

    if (existingPath != null) {
      debugPrint('[UpdateDownloader] File sudah ada, langsung install...');
      final installResult = await _tryInstallApk(existingPath);
      if (installResult != null) return installResult;

      // Jika install gagal meskipun file ada → hapus file lama, download ulang
      debugPrint('[UpdateDownloader] Install file lama gagal, download ulang...');
      try {
        await File(existingPath).delete();
      } catch (_) {}
    }

    // Langkah 2: Download file baru
    try {
      final baseDir = await _getDownloadDirectory();
      final fileName = _resolveFileName(downloadUrl, versionName);
      final file = File('${baseDir.path}/$fileName');

      onProgress?.call(0);

      await _dio.download(
        downloadUrl,
        file.path,
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

      // Langkah 3: Coba install file yang baru didownload
      final installResult = await _tryInstallApk(file.path);
      if (installResult != null) return installResult;

      // Semua cara install gagal → fallback ke browser
      return await _fallbackToBrowser(downloadUrl);
    } on DioException catch (e) {
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
    try {
      if (Platform.isAndroid) {
        final ext = await getExternalStorageDirectory();
        if (ext != null) dirs.add(ext);
      }
      final tmp = await getTemporaryDirectory();
      dirs.add(tmp);
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

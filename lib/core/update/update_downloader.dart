import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

enum AppUpdateDownloadStatus {
  downloadedOpenedInstaller,
  downloadedOpenedFolder,
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

  Future<AppUpdateDownloadResult> downloadAndOpenInstaller({
    required String downloadUrl,
    required String versionName,
    void Function(int percent)? onProgress,
  }) async {
    try {
      Directory? baseDir;
      if (Platform.isAndroid) {
        baseDir = Directory('/storage/emulated/0/Download');
        if (!baseDir.existsSync()) {
          try {
            baseDir.createSync(recursive: true);
          } catch (_) {
            baseDir = null; // fallback
          }
        }
      }
      baseDir ??= await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();

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

      final openResult = await OpenFilex.open(file.path);
      if (openResult.type == ResultType.done) {
        return AppUpdateDownloadResult(
          status: AppUpdateDownloadStatus.downloadedOpenedInstaller,
          filePath: file.path,
        );
      }

      final folderOpenResult = await OpenFilex.open(baseDir.path);
      if (folderOpenResult.type == ResultType.done) {
        return AppUpdateDownloadResult(
          status: AppUpdateDownloadStatus.downloadedOpenedFolder,
          filePath: file.path,
        );
      }

      return AppUpdateDownloadResult(
        status: AppUpdateDownloadStatus.downloadedOpenedFolder,
        filePath: file.path,
      );
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

      return AppUpdateDownloadResult(
        status: networkError
            ? AppUpdateDownloadStatus.failedNetwork
            : AppUpdateDownloadStatus.failedOther,
      );
    } catch (e) {
      return AppUpdateDownloadResult(
        status: AppUpdateDownloadStatus.failedOther,
        filePath: e.toString(),
      );
    }
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


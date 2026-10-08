import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/app_constants.dart';

enum AppUpdateStatus {
  upToDate,
  updateAvailable,
  failedCheck,
}

class AppUpdateManifest {
  final String version;
  final int buildNumber;
  final bool mandatory;
  final String? notes;
  final String? pubDate;
  final String url;
  final String? sha256;

  const AppUpdateManifest({
    required this.version,
    required this.buildNumber,
    required this.mandatory,
    required this.url,
    this.notes,
    this.pubDate,
    this.sha256,
  });

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    final rawBuild = json['buildNumber'] ?? json['versionCode'];
    final parsedBuild = rawBuild is int
        ? rawBuild
        : int.tryParse(rawBuild?.toString() ?? '') ?? 0;

    final versionValue =
        (json['version'] ?? json['versionName'] ?? '').toString();
    final urlValue = (json['url'] ?? json['apkUrl'] ?? '').toString();

    return AppUpdateManifest(
      version: versionValue,
      buildNumber: parsedBuild,
      mandatory: json['mandatory'] == true,
      notes: json['notes']?.toString(),
      pubDate: (json['pub_date'] ?? json['releaseDate'])?.toString(),
      url: urlValue,
      sha256: json['sha256']?.toString(),
    );
  }
}

class AppUpdateCheckResult {
  final AppUpdateStatus status;
  final AppUpdateManifest? manifest;
  final String currentVersion;
  final int currentBuildNumber;

  const AppUpdateCheckResult({
    required this.status,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.manifest,
  });

  bool get hasUpdate => status == AppUpdateStatus.updateAvailable;
}

class UpdateChecker {
  final http.Client _httpClient;
  final String _manifestUrl;

  UpdateChecker({
    http.Client? httpClient,
    String? manifestUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _manifestUrl = manifestUrl ?? ApiConfig.updateManifestUrl;

  Future<AppUpdateCheckResult> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    try {
      final response = await _httpClient.get(
        Uri.parse(_manifestUrl),
        headers: const {'Accept': 'application/json'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppUpdateCheckResult(
          status: AppUpdateStatus.failedCheck,
          currentVersion: packageInfo.version,
          currentBuildNumber: currentBuild,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return AppUpdateCheckResult(
          status: AppUpdateStatus.upToDate,
          currentVersion: packageInfo.version,
          currentBuildNumber: currentBuild,
        );
      }

      final manifest = AppUpdateManifest.fromJson(decoded);
      final hasRequiredFields =
          manifest.version.isNotEmpty && manifest.url.isNotEmpty;

      if (!hasRequiredFields || manifest.buildNumber <= currentBuild) {
        return AppUpdateCheckResult(
          status: AppUpdateStatus.upToDate,
          currentVersion: packageInfo.version,
          currentBuildNumber: currentBuild,
        );
      }

      return AppUpdateCheckResult(
        status: AppUpdateStatus.updateAvailable,
        manifest: manifest,
        currentVersion: packageInfo.version,
        currentBuildNumber: currentBuild,
      );
    } catch (_) {
      return AppUpdateCheckResult(
        status: AppUpdateStatus.failedCheck,
        currentVersion: packageInfo.version,
        currentBuildNumber: currentBuild,
      );
    }
  }

  /// Khusus Flutter Web: Cek apakah versi di server web lebih tinggi daripada versi yang sedang dibuka user.
  Future<AppUpdateCheckResult> checkWebUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final currentVersion = packageInfo.version;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 1. Coba baca /version.json bawaan Flutter Web
    try {
      final uri = Uri.parse('/version.json?t=$timestamp');
      final res = await _httpClient.get(uri, headers: const {'Accept': 'application/json'});
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final serverVersion = decoded['version']?.toString() ?? '';
          final serverBuild = int.tryParse(decoded['build_number']?.toString() ?? '') ?? 0;

          final isHigherBuild = serverBuild > currentBuild;
          final isDifferentVersion = serverVersion.isNotEmpty &&
              currentVersion.isNotEmpty &&
              serverVersion != currentVersion;

          if (isHigherBuild || (serverBuild == currentBuild && isDifferentVersion)) {
            return AppUpdateCheckResult(
              status: AppUpdateStatus.updateAvailable,
              currentVersion: currentVersion,
              currentBuildNumber: currentBuild,
              manifest: AppUpdateManifest(
                version: serverVersion.isNotEmpty ? serverVersion : currentVersion,
                buildNumber: serverBuild > 0 ? serverBuild : currentBuild,
                mandatory: false,
                url: '',
              ),
            );
          }
        }
      }
    } catch (_) {}

    // 2. Fallback: Cek ke manifest /latest.json di VPS
    try {
      final uri = Uri.parse('$_manifestUrl?t=$timestamp');
      final res = await _httpClient.get(uri, headers: const {'Accept': 'application/json'});
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final manifest = AppUpdateManifest.fromJson(decoded);
          if (manifest.buildNumber > currentBuild ||
              (manifest.version.isNotEmpty && manifest.version != currentVersion)) {
            return AppUpdateCheckResult(
              status: AppUpdateStatus.updateAvailable,
              manifest: manifest,
              currentVersion: currentVersion,
              currentBuildNumber: currentBuild,
            );
          }
        }
      }
    } catch (_) {}

    return AppUpdateCheckResult(
      status: AppUpdateStatus.upToDate,
      currentVersion: currentVersion,
      currentBuildNumber: currentBuild,
    );
  }
}


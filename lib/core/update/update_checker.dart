import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/app_constants.dart';

enum AppUpdateStatus {
  upToDate,
  updateAvailable,
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
    final rawBuild = json['buildNumber'];
    final parsedBuild = rawBuild is int
        ? rawBuild
        : int.tryParse(rawBuild?.toString() ?? '') ?? 0;

    return AppUpdateManifest(
      version: (json['version'] ?? '').toString(),
      buildNumber: parsedBuild,
      mandatory: json['mandatory'] == true,
      notes: json['notes']?.toString(),
      pubDate: json['pub_date']?.toString(),
      url: (json['url'] ?? '').toString(),
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
          status: AppUpdateStatus.upToDate,
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
        status: AppUpdateStatus.upToDate,
        currentVersion: packageInfo.version,
        currentBuildNumber: currentBuild,
      );
    }
  }
}


import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  /// Initialize Remote Config with default values
  Future<void> init() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        // Dibuat lebih responsif untuk use-case update checker.
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(minutes: 15),
      ),
    );

    // Default values
    await _remoteConfig.setDefaults({
      'force_update': false,
      'latest_version': '1.0.0',
      'latest_build_number': '0',
      'update_url':
          'https://play.google.com/store/apps/details?id=com.example.artoku_app',
      'update_message':
          'Versi terbaru ArtoKu sudah tersedia! Silakan update untuk mendapatkan fitur terbaru.',
    });

    // Fetch and activate
    try {
      final bool activated = await _remoteConfig.fetchAndActivate();
      debugPrint('[RemoteConfig] Init: activated=$activated');
      debugPrint(
        '[RemoteConfig] Init status: ${_remoteConfig.lastFetchStatus} | lastFetch: ${_remoteConfig.lastFetchTime}',
      );
    } catch (e) {
      debugPrint('[RemoteConfig] Init fetch failed: $e');
    }
  }

  /// Check if update is required and show dialog
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      // Re-fetch latest config
      await _remoteConfig.fetchAndActivate();

      final bool forceUpdate = _remoteConfig.getBool('force_update');
      final String latestVersionRaw = _remoteConfig
          .getString('latest_version')
          .trim();
      final String latestBuildRaw = _remoteConfig
          .getString('latest_build_number')
          .trim();
      final String updateUrl = _remoteConfig.getString('update_url').trim();
      final String updateMessage = _remoteConfig.getString('update_message');

      // Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersionRaw = packageInfo.version.trim();
      final String currentBuildRaw = packageInfo.buildNumber.trim();

      final _VersionParts current = _VersionParts.parse(
        currentVersionRaw,
        fallbackBuild: currentBuildRaw,
      );
      final _VersionParts latest = _VersionParts.parse(
        latestVersionRaw,
        fallbackBuild: latestBuildRaw,
      );

      debugPrint(
        '[RemoteConfig] Current: ${current.debugLabel} | Latest: ${latest.debugLabel} | ForceUpdate: $forceUpdate',
      );
      debugPrint(
        '[RemoteConfig] Status: ${_remoteConfig.lastFetchStatus} | lastFetch: ${_remoteConfig.lastFetchTime}',
      );

      // Compare versions (supports x.y.z and x.y.z+build)
      final bool needsUpdate = _isVersionLower(current, latest);

      debugPrint('[RemoteConfig] Needs update: $needsUpdate');

      if (needsUpdate && context.mounted) {
        _showUpdateDialog(
          context,
          forceUpdate: forceUpdate,
          message: updateMessage,
          updateUrl: updateUrl,
          latestVersion: latest.displayLabel,
        );
      }
    } catch (e) {
      debugPrint('Check for update failed: $e');
    }
  }

  /// Compare semantic versions and optional build number.
  /// Returns true if current < latest.
  bool _isVersionLower(_VersionParts current, _VersionParts latest) {
    if (current.major != latest.major) return current.major < latest.major;
    if (current.minor != latest.minor) return current.minor < latest.minor;
    if (current.patch != latest.patch) return current.patch < latest.patch;

    // Jika major/minor/patch sama, compare build number bila latest menyediakannya.
    if (latest.build != null) {
      if (current.build == null) return true;
      return current.build! < latest.build!;
    }

    return false;
  }

  void _showUpdateDialog(
    BuildContext context, {
    required bool forceUpdate,
    required String message,
    required String updateUrl,
    required String latestVersion,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: const Color(0xFF0F4C5C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update,
                  color: Color(0xFF0F4C5C),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Update Tersedia!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Versi terbaru:',
                      style: TextStyle(fontSize: 13),
                    ),
                    Text(
                      'v$latestVersion',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF00897B),
                      ),
                    ),
                  ],
                ),
              ),
              if (forceUpdate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Update ini wajib untuk melanjutkan penggunaan aplikasi.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti Saja'),
              ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(updateUrl);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Could not launch update URL: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C5C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Update Sekarang',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionParts {
  final int major;
  final int minor;
  final int patch;
  final int? build;

  const _VersionParts({
    required this.major,
    required this.minor,
    required this.patch,
    this.build,
  });

  factory _VersionParts.parse(String raw, {String? fallbackBuild}) {
    String value = raw.trim();

    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1).trim();
    }

    final partsByPlus = value.split('+');
    final core = partsByPlus.first.split('-').first.trim();

    final coreParts = core.split('.');

    int readCorePart(int index) {
      if (index >= coreParts.length) return 0;
      final match = RegExp(r'\d+').firstMatch(coreParts[index]);
      if (match == null) return 0;
      return int.tryParse(match.group(0)!) ?? 0;
    }

    int? readBuildFrom(String source) {
      final match = RegExp(r'\d+').firstMatch(source);
      if (match == null) return null;
      return int.tryParse(match.group(0)!);
    }

    int? parsedBuild;
    if (partsByPlus.length > 1) {
      parsedBuild = readBuildFrom(partsByPlus[1]);
    }

    parsedBuild ??= readBuildFrom(fallbackBuild ?? '');

    return _VersionParts(
      major: readCorePart(0),
      minor: readCorePart(1),
      patch: readCorePart(2),
      build: parsedBuild,
    );
  }

  String get displayLabel =>
      build != null ? '$major.$minor.$patch+$build' : '$major.$minor.$patch';

  String get debugLabel => displayLabel;
}

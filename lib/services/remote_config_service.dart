import 'package:firebase_remote_config/firebase_remote_config.dart';
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
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    // Default values
    await _remoteConfig.setDefaults({
      'force_update': false,
      'latest_version': '1.0.0',
      'update_url': 'https://play.google.com/store/apps/details?id=com.example.artoku_app',
      'update_message': 'Versi terbaru ArtoKu sudah tersedia! Silakan update untuk mendapatkan fitur terbaru.',
    });

    // Fetch and activate
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config fetch failed: $e');
    }
  }

  /// Check if update is required and show dialog
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      // Re-fetch latest config
      await _remoteConfig.fetchAndActivate();

      final bool forceUpdate = _remoteConfig.getBool('force_update');
      final String latestVersion = _remoteConfig.getString('latest_version');
      final String updateUrl = _remoteConfig.getString('update_url');
      final String updateMessage = _remoteConfig.getString('update_message');

      // Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // Compare versions
      final bool needsUpdate = _isVersionLower(currentVersion, latestVersion);

      if (needsUpdate && context.mounted) {
        _showUpdateDialog(
          context,
          forceUpdate: forceUpdate,
          message: updateMessage,
          updateUrl: updateUrl,
          latestVersion: latestVersion,
        );
      }
    } catch (e) {
      debugPrint('Check for update failed: $e');
    }
  }

  /// Compare semantic versions: returns true if current < latest
  bool _isVersionLower(String current, String latest) {
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad to same length
    while (currentParts.length < 3) currentParts.add(0);
    while (latestParts.length < 3) latestParts.add(0);

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < latestParts[i]) return true;
      if (currentParts[i] > latestParts[i]) return false;
    }
    return false; // Same version
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  "Update Tersedia!",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Versi terbaru:", style: TextStyle(fontSize: 13)),
                    Text(
                      "v$latestVersion",
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
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Update ini wajib untuk melanjutkan penggunaan aplikasi.",
                          style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
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
                child: const Text("Nanti Saja"),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("Update Sekarang", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:muzo/services/abi_helper.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // Current app version - Update this when releasing a new version
  static const String currentAppVersion = '3.0';

  static const String _repoOwner = 'Shashwat-CODING';
  static const String _repoName = 'Muzo';

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String latestVersion = data['tag_name'] ?? '';
        final String htmlUrl = data['html_url'] ?? '';

        if (_isNewerVersion(latestVersion, currentAppVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, htmlUrl, latestVersion);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      debugPrint('Update Check: Remote Version: "$latest" vs Local Version: "$current"');
      
      // Remove everything except numbers and dots to ensure clean comparison
      final latestClean = latest.replaceAll(RegExp(r'[^0-9.]'), '');
      final currentClean = current.replaceAll(RegExp(r'[^0-9.]'), '');

      debugPrint('Cleaned Versions: Remote: "$latestClean" vs Local: "$currentClean"');

      if (latestClean == currentClean) return false;

      List<String> latestParts = latestClean.split('.');
      List<String> currentParts = currentClean.split('.');

      int maxLength = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        int l = i < latestParts.length ? int.tryParse(latestParts[i]) ?? 0 : 0;
        int c = i < currentParts.length ? int.tryParse(currentParts[i]) ?? 0 : 0;

        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      debugPrint('Error comparing versions: $e');
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String version, String url, String tag) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.system_update_alt_rounded,
                        size: 24, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Update Available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            )),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(version,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              )),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'A new version of Muzo is available. Update now for the latest features and improvements.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Later',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadApk(tag, url);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.onSurface,
                        foregroundColor: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Download', style: TextStyle(fontWeight: FontWeight.bold)),
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

  /// Returns the APK filename matching the current device ABI.
  /// Returns null on web or unrecognised platforms.
  String? _apkFilename() => detectApkFilename();

  Future<void> _downloadApk(String tag, String fallbackUrl) async {
    final filename = _apkFilename();
    final Uri uri;
    if (filename != null) {
      // Direct asset download URL from the GitHub release
      uri = Uri.parse(
        'https://github.com/$_repoOwner/$_repoName/releases/download/$tag/$filename',
      );
    } else {
      // Non-Android platform — open the release page
      uri = Uri.parse(fallbackUrl);
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $uri');
    }
  }
}

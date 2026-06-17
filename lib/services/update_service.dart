import 'dart:ui';
import 'package:muzo/services/abi_helper.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';


class UpdateService {
  // Current app version - Update this when releasing a new version
  static const String currentAppVersion = '3.9';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerCol = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.65) : const Color(0xFFE5E5EA).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.system_update_alt_rounded,
                              size: 20, color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Update Available',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Version $version',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Text(
                      'A new version of Muzo is available. Update now for the latest features and improvements.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.35,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  Container(height: 0.5, color: dividerCol),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                            child: Text(
                              'Later',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 17,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(width: 0.5, height: 44, color: dividerCol),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _downloadApk(tag, url);
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                            child: Text(
                              'Download',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

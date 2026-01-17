import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // Current app version - Update this when releasing a new version
  static const String currentAppVersion = '2.0.1';

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
            _showUpdateDialog(context, latestVersion, htmlUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final latestClean = latest.trim().toLowerCase().replaceAll('v', '');
      final currentClean = current.trim().toLowerCase().replaceAll('v', '');

      if (latestClean == currentClean) return false;

      List<String> latestParts = latestClean.split('.');
      List<String> currentParts = currentClean.split('.');

      int maxLength = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        int l = i < latestParts.length
            ? int.tryParse(latestParts[i].replaceAll(RegExp(r'[^0-9]'), '')) ??
                  0
            : 0;
        int c = i < currentParts.length
            ? int.tryParse(currentParts[i].replaceAll(RegExp(r'[^0-9]'), '')) ??
                  0
            : 0;

        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      debugPrint('Error comparing versions: $e');
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String version, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Text(
          'A new version of Muzo ($version) is available. Would you like to update?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(url);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}

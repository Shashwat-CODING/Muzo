import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // Current app version - Update this when releasing a new version
  static const String currentAppVersion = '1.2.1';
  
  static const String _repoOwner = 'Shashwat-CODING';
  static const String _repoName = 'Muzo';

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String latestVersion = data['tag_name'] ?? '';
        final String htmlUrl = data['html_url'] ?? '';
        
        // Simple version comparison (assumes format like v1.2.0 or 1.2.0)
        String cleanLatest = latestVersion.replaceAll('v', '');
        String cleanCurrent = currentAppVersion.replaceAll('v', '');

        if (_isNewerVersion(cleanLatest, cleanCurrent)) {
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
    List<String> latestParts = latest.split('.');
    List<String> currentParts = current.split('.');

    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      int l = int.tryParse(latestParts[i]) ?? 0;
      int c = int.tryParse(currentParts[i]) ?? 0;
      
      if (l > c) return true;
      if (l < c) return false;
    }
    
    return latestParts.length > currentParts.length;
  }

  void _showUpdateDialog(BuildContext context, String version, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Text('A new version of Muzo ($version) is available. Would you like to update?'),
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

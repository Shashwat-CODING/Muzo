import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytx/providers/settings_provider.dart';
import 'package:ytx/services/storage_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentQuality = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Audio Quality',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildQualityOption(
                context,
                ref,
                'High',
                AudioQuality.high,
                currentQuality,
              ),
              _buildQualityOption(
                context,
                ref,
                'Medium',
                AudioQuality.medium,
                currentQuality,
              ),
              _buildQualityOption(
                context,
                ref,
                'Low',
                AudioQuality.low,
                currentQuality,
              ),
              const SizedBox(height: 32),
              const Text(
                'Playback',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final storage = ref.watch(storageServiceProvider);
                  return ValueListenableBuilder(
                    valueListenable: storage.settingsListenable,
                    builder: (context, box, _) {
                      final autoQueueEnabled = storage.autoQueueEnabled;
                      return SwitchListTile(
                        title: const Text(
                          'Auto Queue Related Songs',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Automatically add related songs to queue when playing',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        value: autoQueueEnabled,
                        onChanged: (value) => storage.setAutoQueueEnabled(value),
                        activeColor: Theme.of(context).colorScheme.primary,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final storage = ref.watch(storageServiceProvider);
                  return ValueListenableBuilder(
                    valueListenable: storage.settingsListenable,
                    builder: (context, box, _) {
                      final apiKey = storage.rapidApiKey;
                      final countryCode = storage.rapidApiCountryCode;
                      return Column(
                        children: [
                          ListTile(
                            title: const Text(
                              'Ignore Battery Optimizations',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'Prevent app from being suspended in background',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            trailing: const Icon(Icons.battery_alert, color: Colors.white),
                            contentPadding: EdgeInsets.zero,
                            onTap: () async {
                              await Permission.ignoreBatteryOptimizations.request();
                            },
                          ),
                          ListTile(
                            title: const Text(
                              'RapidAPI Key (Fallback)',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              apiKey != null && apiKey.isNotEmpty
                                  ? 'Key set: ${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}'
                                  : 'Not set (Fallback disabled)',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            trailing: const Icon(Icons.edit, color: Colors.white),
                            contentPadding: EdgeInsets.zero,
                            onTap: () => _showApiKeyDialog(context, storage),
                          ),
                          ListTile(
                            title: const Text(
                              'RapidAPI Country Code',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              countryCode.isNotEmpty ? 'Current: $countryCode' : 'Default: IN',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            trailing: const Icon(Icons.public, color: Colors.white),
                            contentPadding: EdgeInsets.zero,
                            onTap: () => _showApiCountryDialog(context, storage),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 160),
            ],
          ),
        ),
      ),
    );
  }

    void _showApiKeyDialog(BuildContext context, StorageService storage) {
    final controller = TextEditingController(text: storage.rapidApiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Enter RapidAPI Key', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your RapidAPI key for "yt-api" to enable fallback playback when the primary API fails.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Paste API Key here',
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              storage.setRapidApiKey(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showApiCountryDialog(BuildContext context, StorageService storage) {
    final controller = TextEditingController(text: storage.rapidApiCountryCode);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('RapidAPI Country Code', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Country code in ISO 3166 format of the end user (e.g., IN, US).',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Not providing cgeo param may cost +1 quota. It is important to provide geo of the end user to get the best speed and direct links. If links are used in the server, then cgeo will be the geo of the server. Not providing cgeo param may lead to 403 issue.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. IN',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              storage.setRapidApiCountryCode(controller.text.trim().toUpperCase());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityOption(
    BuildContext context,
    WidgetRef ref,
    String title,
    AudioQuality quality,
    AudioQuality currentQuality,
  ) {
    final isSelected = quality == currentQuality;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.white)
          : null,
      onTap: () {
        ref.read(settingsProvider.notifier).setAudioQuality(quality);
      },
    );
  }
}

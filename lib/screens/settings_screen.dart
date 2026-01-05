import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'package:muzo/services/storage_service.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:muzo/widgets/global_background.dart';
import 'package:muzo/screens/about_screen.dart';
import 'package:muzo/services/auth_service.dart';
import 'package:muzo/screens/auth_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsProvider);
    final currentQuality = settingsState.audioQuality;
    final isLiteMode = settingsState.isLiteMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('Appearance', [
                 ListTile(
                  title: const Text('App Theme', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    settingsState.themeType.name.toUpperCase(), 
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)
                  ),
                  trailing: const Icon(FluentIcons.paint_brush_24_regular, color: Colors.white),
                  onTap: () => _showThemeDialog(context, ref, settingsState.themeType),
                ),
                 const Divider(height: 1, color: Colors.white10),
                 ListTile(
                  title: const Text('Lite Mode', style: TextStyle(color: Colors.white)),
                  subtitle: Text('Disable blur and effects for better performance', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  trailing: Switch(
                    value: isLiteMode,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setLiteMode(value);
                    },
                    activeColor: Colors.white,
                    activeTrackColor: Colors.grey[700],
                  ),
                ),
              ]),

              _buildSection('Audio Quality', [
                _buildQualityOption(context, ref, 'High', AudioQuality.high, currentQuality),
                const Divider(height: 1, color: Colors.white10),
                _buildQualityOption(context, ref, 'Medium', AudioQuality.medium, currentQuality),
                const Divider(height: 1, color: Colors.white10),
                _buildQualityOption(context, ref, 'Low', AudioQuality.low, currentQuality),
              ]),

              Consumer(
                builder: (context, ref, _) {
                  final storage = ref.watch(storageServiceProvider);
                  return ValueListenableBuilder(
                    valueListenable: storage.settingsListenable,
                    builder: (context, box, _) {
                      final apiKey = storage.rapidApiKey;
                      final countryCode = storage.rapidApiCountryCode;
                      
                      return _buildSection('Playback', [
                        ListTile(
                          title: const Text('Lofi Mode Settings', style: TextStyle(color: Colors.white)),
                          subtitle: const Text('Adjust Speed and Pitch', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: const Icon(FluentIcons.music_note_2_24_regular, color: Colors.white),
                          onTap: () {
                            _showLofiSettingsDialog(context, storage);
                          },
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        ListTile(
                          title: const Text('Auto Queue', style: TextStyle(color: Colors.white)),
                          subtitle: Text('Automatically add recommended songs to queue', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          trailing: Switch(
                            value: storage.isAutoQueueEnabled,
                            onChanged: (value) => storage.setAutoQueueEnabled(value),
                            activeColor: Colors.white,
                            activeTrackColor: Colors.grey[700],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        ListTile(
                          title: const Text('Ignore Battery Optimizations', style: TextStyle(color: Colors.white)),
                          subtitle: Text('Prevent app from being suspended', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          trailing: const Icon(FluentIcons.battery_warning_24_regular, color: Colors.white),
                          onTap: () async => await Permission.ignoreBatteryOptimizations.request(),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        ListTile(
                          title: const Text('RapidAPI Key', style: TextStyle(color: Colors.white)),
                          subtitle: Text(
                            apiKey != null && apiKey.isNotEmpty ? 'Key set' : 'Not set',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                          trailing: const Icon(FluentIcons.edit_24_regular, color: Colors.white),
                          onTap: () => _showApiKeyDialog(context, storage),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        ListTile(
                          title: const Text('RapidAPI Country Code', style: TextStyle(color: Colors.white)),
                          subtitle: Text(
                            countryCode.isNotEmpty ? 'Current: $countryCode' : 'Default: IN',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                          trailing: const Icon(FluentIcons.globe_24_regular, color: Colors.white),
                          onTap: () => _showApiCountryDialog(context, storage),
                        ),
                      ]);
                    },
                  );
                },
              ),

              Consumer(
                builder: (context, ref, _) {
                  final storage = ref.watch(storageServiceProvider);
                  return ValueListenableBuilder(
                    valueListenable: storage.settingsListenable,
                    builder: (context, box, _) {
                      return _buildSection('Account', [
                        // Show User Info if logged in
                        if (storage.username != null) ...[
                          ListTile(
                            leading: const Icon(FluentIcons.person_24_regular, color: Colors.white),
                            title: Text('Logged in as ${storage.username}', style: const TextStyle(color: Colors.white)),
                            subtitle: Text(storage.email ?? '', style: const TextStyle(color: Colors.grey)),
                            trailing: TextButton(
                              onPressed: () async {
                                await ref.read(authServiceProvider).logout();
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                                    (route) => false,
                                  );
                                }
                              },
                              child: const Text('Logout', style: TextStyle(color: Colors.red)),
                            ),
                          ),
                        ] else ...[
                          ListTile(
                            leading: const Icon(FluentIcons.person_add_24_regular, color: Colors.white),
                            title: const Text('Login / Signup', style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AuthScreen()),
                              );
                            },
                          ),
                        ],
                      ]);
                    },
                  );
                },
              ),

              _buildSection('App Info', [
                ListTile(
                  title: const Text('About', style: TextStyle(color: Colors.white)),
                  subtitle: Text('Version 1.2.0', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  trailing: const Icon(FluentIcons.info_24_regular, color: Colors.white),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                  },
                ),
              ]),
              
              const SizedBox(height: 160), // Increased padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: 24),
      ],
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
          ? const Icon(FluentIcons.checkmark_24_regular, color: Colors.white)
          : null,
      onTap: () {
        ref.read(settingsProvider.notifier).setAudioQuality(quality);
      },
    );
  }
  void _showTextInputDialog({
    required BuildContext context,
    required String title,
    String? initialValue,
    required Function(String) onSubmitted,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onSubmitted(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLofiSettingsDialog(BuildContext context, StorageService storage) {
    // We need state for sliders
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Lofi Mode Settings', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Playback Speed', style: TextStyle(color: Colors.white70)),
                Row(
                  children: [
                    Text('${storage.lofiSpeed.toStringAsFixed(2)}x', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: storage.lofiSpeed,
                        min: 0.5,
                        max: 1.5,
                        divisions: 20,
                        activeColor: Colors.white,
                        inactiveColor: Colors.grey[800],
                        onChanged: (value) {
                          setState(() {
                             storage.setLofiSpeed(value);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Playback Pitch', style: TextStyle(color: Colors.white70)),
                Row(
                  children: [
                    Text('${storage.lofiPitch.toStringAsFixed(2)}x', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: storage.lofiPitch,
                        min: 0.5,
                        max: 1.5,
                        divisions: 20,
                        activeColor: Colors.white,
                        inactiveColor: Colors.grey[800],
                        onChanged: (value) {
                          setState(() {
                             storage.setLofiPitch(value);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        }
      ),
    );
  }
  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeType currentTheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Select Theme', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeType.values.map((theme) {
            final isSelected = theme == currentTheme;
            return ListTile(
              title: Text(
                theme.name.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? const Icon(FluentIcons.checkmark_24_regular, color: Colors.white)
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setThemeType(theme);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:muzo/services/auth_service.dart';
import 'package:muzo/screens/auth_screen.dart';
import 'package:muzo/screens/settings/components/font_picker_dialog.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/auth_gate_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _buildSettingIconBox(IconData icon, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsProvider);
    final currentQuality = settingsState.audioQuality;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(context, 'Appearance', [
                ListTile(
                  leading: _buildSettingIconBox(FluentIcons.paint_brush_24_regular, Colors.purple),
                  title: Text(
                    'App Theme',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    _themeLabel(settingsState.themeType),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11),
                  ),
                  trailing: Icon(
                    CupertinoIcons.chevron_right,
                    size: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                  onTap: () =>
                      _showThemeDialog(context, ref, settingsState.themeType),
                ),
                ListTile(
                  leading: _buildSettingIconBox(Icons.dark_mode_rounded, Colors.blueGrey),
                  title: Text(
                    'AMOLED Black',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Use pure black background in dark mode',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11),
                  ),
                  trailing: Switch(
                    value: settingsState.isAmoled,
                    onChanged: (value) =>
                        ref.read(settingsProvider.notifier).setAmoled(value),
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final currentFont = ref.watch(settingsProvider).appFontFamily;
                    return ListTile(
                      leading: _buildSettingIconBox(FluentIcons.text_font_24_regular, Colors.indigo),
                      title: Text(
                        'App Font',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        currentFont,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11),
                      ),
                      trailing: Icon(
                        CupertinoIcons.chevron_right,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                      ),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const FontPickerDialog(),
                        );
                      },
                    );
                  },
                ),
              ]),

              _buildSection(context, 'Audio Quality', [
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
              ]),

              Consumer(
                builder: (context, ref, _) {
                  final storage = ref.watch(storageServiceProvider);
                  return ValueListenableBuilder(
                    valueListenable: storage.settingsListenable,
                    builder: (context, box, _) {
                      return _buildSection(context, 'Playback', [
                        ValueListenableBuilder<bool>(
                          valueListenable: ref.watch(audioHandlerProvider).isLofiModeNotifier,
                          builder: (context, isLofi, _) {
                            return ListTile(
                              leading: _buildSettingIconBox(Icons.waves_rounded, Colors.blue),
                              title: Text(
                                'Lofi Mode',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                'Apply speed and pitch effects',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                              trailing: Switch(
                                value: isLofi,
                                onChanged: (value) =>
                                    ref.read(audioHandlerProvider).toggleLofiMode(),
                                activeThumbColor: Theme.of(context).colorScheme.primary,
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: _buildSettingIconBox(FluentIcons.music_note_2_24_regular, Colors.teal),
                          title: Text(
                            'Lofi Mode Fine-tuning',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Adjust Speed and Pitch',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11),
                          ),
                          trailing: Icon(
                            CupertinoIcons.chevron_right,
                            size: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                          ),
                          onTap: () {
                            _showLofiSettingsDialog(context, ref, storage);
                          },
                        ),
                        ListTile(
                          leading: _buildSettingIconBox(Icons.all_inclusive, Colors.tealAccent.shade700),
                          title: Text(
                            'Auto Queue',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Automatically add recommended songs to queue',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Switch(
                            value: storage.isAutoQueueEnabled,
                            onChanged: (value) =>
                                storage.setAutoQueueEnabled(value),
                            activeThumbColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        ListTile(
                          leading: _buildSettingIconBox(FluentIcons.open_24_regular, Colors.red),
                          title: Text(
                            'Open YouTube Links in App',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Intercept YouTube URLs to play locally',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Switch(
                            value: storage.handleAppLinks,
                            onChanged: (value) async {
                              await storage.setHandleAppLinks(value);
                            },
                            activeThumbColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        ListTile(
                          leading: _buildSettingIconBox(FluentIcons.battery_warning_24_regular, Colors.amber.shade800),
                          title: Text(
                            'Ignore Battery Optimizations',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Prevent app from being suspended',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                          trailing: Icon(
                            CupertinoIcons.chevron_right,
                            size: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                          ),
                          onTap: () async => await Permission
                              .ignoreBatteryOptimizations
                              .request(),
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
                      return _buildSection(context, 'Account', [
                        // Show User Info if logged in
                        if (storage.username != null) ...[
                          ListTile(
                            leading: _buildSettingIconBox(FluentIcons.person_24_regular, Colors.grey),
                            title: Text(
                              'Logged in as ${storage.username}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              storage.email ?? '',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11),
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                await ref.read(authServiceProvider).logout();
                                ref.read(isGuestModeProvider.notifier).state = false;
                              },
                              child: const Text(
                                'Logout',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        ] else ...[
                          ListTile(
                            leading: _buildSettingIconBox(FluentIcons.person_add_24_regular, Colors.grey),
                            title: Text(
                              'Login / Signup',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            trailing: Icon(
                              CupertinoIcons.chevron_right,
                              size: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ]);
                    },
                  );
                },
              ),

              _buildSection(context, 'About', [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.network(
                              'https://avatars.githubusercontent.com/Shashwat-CODING',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset('assets/logo.png', fit: BoxFit.contain),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Muzo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Premium Music Client',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: _buildSettingIconBox(FluentIcons.info_24_regular, Colors.grey),
                  title: Text('Version', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
                  trailing: Text('v3.9', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                ),
                ListTile(
                  leading: _buildSettingIconBox(FluentIcons.person_24_regular, Colors.blue),
                  title: Text('Developer', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
                  trailing: Text('Shashwat', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                ),
                ListTile(
                  leading: _buildSettingIconBox(FluentIcons.code_24_regular, Colors.black87),
                  title: Text('Source Code', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text('View on GitHub', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11)),
                  trailing: Icon(
                    CupertinoIcons.chevron_right,
                    size: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://github.com/Shashwat-CODING/Muzo'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ]),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03);
    final cardBorder = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cardBorder,
                  width: 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    for (int i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i < children.length - 1)
                        Divider(
                          height: 1,
                          indent: 56,
                          color: cardBorder,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
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
      leading: _buildSettingIconBox(Icons.music_note_rounded, isSelected ? Colors.orange : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      trailing: isSelected
          ? const Icon(FluentIcons.checkmark_24_regular, color: Colors.white, size: 18)
          : null,
      onTap: () {
        ref.read(settingsProvider.notifier).setAudioQuality(quality);
      },
    );
  }

  void _showLofiSettingsDialog(BuildContext context, WidgetRef ref, StorageService storage) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerCol = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
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
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Lofi Mode Settings',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Playback Speed',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  '${storage.lofiSpeed.toStringAsFixed(2)}x',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: CupertinoSlider(
                                value: storage.lofiSpeed,
                                min: 0.5,
                                max: 1.5,
                                divisions: 20,
                                activeColor: theme.primaryColor,
                                onChanged: (value) {
                                  setState(() {
                                    storage.setLofiSpeed(value);
                                  });
                                  ref.read(audioHandlerProvider).updateLofiSettings();
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Playback Pitch',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  '${storage.lofiPitch.toStringAsFixed(2)}x',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: CupertinoSlider(
                                value: storage.lofiPitch,
                                min: 0.5,
                                max: 1.5,
                                divisions: 20,
                                activeColor: theme.primaryColor,
                                onChanged: (value) {
                                  setState(() {
                                    storage.setLofiPitch(value);
                                  });
                                  ref.read(audioHandlerProvider).updateLofiSettings();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 0.5, color: dividerCol),
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          child: Text(
                            'Done',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _themeLabel(ThemeType t) {
    switch (t) {
      case ThemeType.auto: return 'Auto (System)';
      case ThemeType.dark: return 'Dark';
      case ThemeType.light: return 'Light';
    }
  }

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeType currentTheme,
  ) {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final currentTheme = ref.watch(settingsProvider).themeType;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8) 
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'App Theme',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildThemeCard(context, ref, ThemeType.auto, currentTheme,
                                icon: FluentIcons.phone_24_regular,
                                label: 'Auto',
                                sublabel: 'Follow system',
                                topColor: const Color(0xFF1a1a2e),
                                bottomColor: const Color(0xFFf0f4ff),
                                splitDiagonal: true),
                            const SizedBox(width: 12),
                            _buildThemeCard(context, ref, ThemeType.dark, currentTheme,
                                icon: Icons.brightness_3,
                                label: 'Dark',
                                sublabel: 'Always dark',
                                topColor: const Color(0xFF1a1a2e),
                                bottomColor: const Color(0xFF2d2d44),
                                splitDiagonal: false),
                            const SizedBox(width: 12),
                            _buildThemeCard(context, ref, ThemeType.light, currentTheme,
                                icon: FluentIcons.weather_sunny_24_regular,
                                label: 'Light',
                                sublabel: 'Always light',
                                topColor: const Color(0xFFfafafa),
                                bottomColor: const Color(0xFFe8eaf6),
                                splitDiagonal: false),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    WidgetRef ref,
    ThemeType theme,
    ThemeType currentTheme, {
    required IconData icon,
    required String label,
    required String sublabel,
    required Color topColor,
    required Color bottomColor,
    required bool splitDiagonal,
  }) {
    final isSelected = theme == currentTheme;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(settingsProvider.notifier).setThemeType(theme);
          Navigator.pop(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                SizedBox(
                  height: 120,
                  child: splitDiagonal
                      ? CustomPaint(
                          size: const Size(double.infinity, 120),
                          painter: _DiagonalSplitPainter(topColor, bottomColor),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [topColor, bottomColor],
                            ),
                          ),
                        ),
                ),
                if (isSelected)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Icon(FluentIcons.checkmark_circle_24_filled,
                          size: 16, color: Theme.of(context).primaryColor),
                    ),
                  ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 13, color: Theme.of(context).colorScheme.onSurface),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          sublabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _DiagonalSplitPainter extends CustomPainter {
  final Color top;
  final Color bottom;
  const _DiagonalSplitPainter(this.top, this.bottom);

  @override
  void paint(Canvas canvas, Size size) {
    final paintTop = Paint()..color = top;
    final paintBottom = Paint()..color = bottom;
    final path1 = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    final path2 = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path1, paintTop);
    canvas.drawPath(path2, paintBottom);
  }

  @override
  bool shouldRepaint(_DiagonalSplitPainter old) => old.top != top || old.bottom != bottom;
}

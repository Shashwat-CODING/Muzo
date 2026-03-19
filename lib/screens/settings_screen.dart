import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'package:muzo/services/storage_service.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:muzo/services/auth_service.dart';
import 'package:muzo/screens/auth_screen.dart';
import 'package:muzo/screens/settings/components/font_picker_dialog.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(context, 'Appearance', [
                ListTile(
                  title: Text(
                    'App Theme',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    _themeLabel(settingsState.themeType),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                  ),
                  trailing: Icon(
                    FluentIcons.paint_brush_24_regular,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onTap: () =>
                      _showThemeDialog(context, ref, settingsState.themeType),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                Consumer(
                  builder: (context, ref, _) {
                    final currentFont = ref.watch(settingsProvider).appFontFamily;
                    return ListTile(
                      title: Text(
                        'App Font',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                      subtitle: Text(
                        currentFont,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                      ),
                      trailing: Icon(
                        FluentIcons.text_font_24_regular,
                        color: Theme.of(context).colorScheme.onSurface,
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
                Divider(height: 1, color: Theme.of(context).dividerColor),
                _buildQualityOption(
                  context,
                  ref,
                  'Medium',
                  AudioQuality.medium,
                  currentQuality,
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
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
                              title: Text(
                                'Lofi Mode',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              ),
                              subtitle: Text(
                                'Apply speed and pitch effects',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Switch(
                                value: isLofi,
                                onChanged: (value) =>
                                    ref.read(audioHandlerProvider).toggleLofiMode(),
                                activeThumbColor: Theme.of(context).colorScheme.primary,
                                activeTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, color: Theme.of(context).dividerColor),
                        ListTile(
                          title: Text(
                            'Lofi Mode Fine-tuning',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            'Adjust Speed and Pitch',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                          ),
                          trailing: Icon(
                            FluentIcons.music_note_2_24_regular,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onTap: () {
                            _showLofiSettingsDialog(context, ref, storage);
                          },
                        ),
                        Divider(height: 1, color: Theme.of(context).dividerColor),
                        ListTile(
                          title: Text(
                            'Auto Queue',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            'Automatically add recommended songs to queue',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Switch(
                            value: storage.isAutoQueueEnabled,
                            onChanged: (value) =>
                                storage.setAutoQueueEnabled(value),
                            activeThumbColor: Theme.of(context).colorScheme.primary,
                            activeTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        Divider(height: 1, color: Theme.of(context).dividerColor),
                        ListTile(
                          title: Text(
                            'Open YouTube Links in App',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            'Intercept YouTube URLs to play locally',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Switch(
                            value: storage.handleAppLinks,
                            onChanged: (value) async {
                              await storage.setHandleAppLinks(value);
                            },
                            activeThumbColor: Theme.of(context).colorScheme.primary,
                            activeTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        Divider(height: 1, color: Theme.of(context).dividerColor),
                        ListTile(
                          title: Text(
                            'Show YouTube Music on Home',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            'Display dynamic content rows from YTM on your Home Feed',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          trailing: StatefulBuilder(
                            builder: (context, setState) {
                              return Switch(
                                value: storage.showYtmHome,
                                onChanged: (value) async {
                                  await storage.setShowYtmHome(value);
                                  setState(() {});
                                },
                                activeThumbColor: Theme.of(context).colorScheme.primary,
                                activeTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              );
                            }
                          ),
                        ),
                        Divider(height: 1, color: Theme.of(context).dividerColor),
                        ListTile(
                          title: Text(
                            'Ignore Battery Optimizations',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            'Prevent app from being suspended',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            FluentIcons.battery_warning_24_regular,
                            color: Theme.of(context).colorScheme.onSurface,
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
                            leading: Icon(
                              FluentIcons.person_24_regular,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            title: Text(
                              'Logged in as ${storage.username}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            ),
                            subtitle: Text(
                              storage.email ?? '',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                await ref.read(authServiceProvider).logout();
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const AuthScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                              child: const Text(
                                'Logout',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        ] else ...[
                          ListTile(
                            leading: Icon(
                              FluentIcons.person_add_24_regular,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            title: Text(
                              'Login / Signup',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                blurRadius: 12,
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
                        const SizedBox(height: 12),
                        Text(
                          'Muzo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Premium Music Client',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                ListTile(
                  leading: Icon(FluentIcons.info_24_regular, color: Theme.of(context).colorScheme.onSurface, size: 20),
                  title: Text('Version', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Text('2.1.6', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                ListTile(
                  leading: Icon(FluentIcons.person_24_regular, color: Theme.of(context).colorScheme.onSurface, size: 20),
                  title: Text('Developer', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Text('Shashwat', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                ListTile(
                  leading: Icon(FluentIcons.code_24_regular, color: Theme.of(context).colorScheme.onSurface, size: 20),
                  title: Text('Source Code', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  subtitle: Text('View on GitHub', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                  trailing: Icon(FluentIcons.open_24_regular, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 18),
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://github.com/Shashwat-CODING/Muzo'),
                      mode: LaunchMode.externalApplication,
                    );
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

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          child: Column(children: children),
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
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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


  void _showLofiSettingsDialog(BuildContext context, WidgetRef ref, StorageService storage) {
    // We need state for sliders
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
            title: Text(
              'Lofi Mode Settings',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Playback Speed',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                Row(
                  children: [
                    Text(
                      '${storage.lofiSpeed.toStringAsFixed(2)}x',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: storage.lofiSpeed,
                        min: 0.5,
                        max: 1.5,
                        divisions: 20,
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        onChanged: (value) {
                          setState(() {
                            storage.setLofiSpeed(value);
                          });
                          ref.read(audioHandlerProvider).updateLofiSettings();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Playback Pitch',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                Row(
                  children: [
                    Text(
                      '${storage.lofiPitch.toStringAsFixed(2)}x',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: storage.lofiPitch,
                        min: 0.5,
                        max: 1.5,
                        divisions: 20,
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
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
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
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
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
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
                // Preview background
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
                // Checkmark badge top-right
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
                          size: 16, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                // Label block at bottom
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

/// Paints a diagonal split with two colors (top-left dark, bottom-right light)
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

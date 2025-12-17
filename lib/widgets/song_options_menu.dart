import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/download_provider.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/download_service.dart';
import 'package:muzo/widgets/playlist_selection_dialog.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/widgets/app_alert_dialog.dart';
import 'package:muzo/services/navigator_key.dart';

class SongOptionsMenu extends ConsumerWidget {
  final YtifyResult result;

  const SongOptionsMenu({super.key, required this.result});

  static void show(BuildContext context, YtifyResult result) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
            builder: (context, ref, _) {
                 final isLiteMode = ref.watch(settingsProvider).isLiteMode;
                 return Center(
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: isLiteMode
                            ? Container(
                                width: 300,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E), 
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: SongOptionsMenu(result: result),
                              )
                            : BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  width: 300,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: SongOptionsMenu(result: result),
                                ),
                              ),
                      ),
                    ),
                  );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final storage = ref.watch(storageServiceProvider);
      return ValueListenableBuilder<List<YtifyResult>>(
        valueListenable: storage.favoritesListenable,
        builder: (context, favorites, _) {
          final isFav = result.videoId != null && storage.isFavorite(result.videoId!);
          final isDownloaded = result.videoId != null && storage.isDownloaded(result.videoId!);

          return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                result.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                result.artists?.map((a) => a.name).join(', ') ?? '',
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            _buildMenuOption(
              context,
              icon: FluentIcons.list_24_regular,
              label: 'Add to queue',
              onTap: () {
                Navigator.pop(context);
                ref.read(audioHandlerProvider).addToQueue(result);
                showGlassSnackBar(context, 'Added to queue');
              },
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            ValueListenableBuilder<bool>(
              valueListenable: ref.watch(audioHandlerProvider).isLofiModeNotifier,
              builder: (context, isLofi, _) {
                return _buildSwitchOption(
                  context,
                  icon: FluentIcons.wand_24_regular,
                  label: 'Lofi Mode',
                  value: isLofi,
                  onChanged: (val) => ref.read(audioHandlerProvider).toggleLofiMode(),
                );
              },
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            _buildMenuOption(
              context,
              icon: FluentIcons.play_circle_24_regular,
              label: 'Play next',
              onTap: () {
                Navigator.pop(context);
                ref.read(audioHandlerProvider).playNext(result);
              },
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            _buildMenuOption(
              context,
              icon: FluentIcons.add_24_regular,
              label: 'Add to playlist',
              onTap: () {
                Navigator.pop(context);
                showCupertinoDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => PlaylistSelectionDialog(song: result),
                );
              },
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            _buildMenuOption(
              context,
              icon: isFav ? FluentIcons.heart_24_filled : FluentIcons.heart_24_regular,
              label: isFav ? 'Remove from favorites' : 'Add to favorites',
              iconColor: isFav ? Colors.red : Colors.white,
              onTap: () {
                Navigator.pop(context);
                storage.toggleFavorite(result);
                showGlassSnackBar(context, isFav ? 'Removed from favorites' : 'Added to favorites');
              },
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            _buildMenuOption(
              context,
              icon: isDownloaded ? FluentIcons.checkmark_24_regular : FluentIcons.arrow_download_24_regular,
              label: isDownloaded ? 'Remove download' : 'Download',
              onTap: () async {
                Navigator.pop(context);
                final downloadService = DownloadService();
                if (result.videoId != null) {
                    if (storage.isDownloaded(result.videoId!)) {
                      await downloadService.deleteDownload(result.videoId!);
                      if (context.mounted) showGlassSnackBar(context, 'Removed from downloads');
                    } else {
                      // Show downloading alert
                      bool isDialogVisible = true;
                      if (context.mounted) {
                          showAppAlertDialog(
                            context: context,
                            title: 'Downloading',
                            content: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Please wait while the song is being downloaded...'),
                                SizedBox(height: 16),
                                CupertinoActivityIndicator(),
                              ],
                            ),
                            actions: [
                                CupertinoDialogAction(
                                  onPressed: () {
                                    // Use navigator key to safely pop the dialog from the root navigator
                                    if (navigatorKey.currentState != null && navigatorKey.currentState!.canPop()) {
                                       navigatorKey.currentState!.pop();
                                    }
                                  },
                                  child: const Text('Hide'),
                                ),
                            ],
                          ).then((_) => isDialogVisible = false);
                      }
                      
                      // Use provider to start download and track progress
                      final success = await ref.read(downloadProvider.notifier).startDownload(result);
                      
                      // Close the downloading alert if it's still visible
                      if (context.mounted) {
                        if (isDialogVisible) {
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                        
                        if (success) {
                          showGlassSnackBar(context, 'Download complete');
                        } else {
                          showGlassSnackBar(context, 'Download failed - Please try again');
                        }
                      }
                    }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        );
        }
      );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color iconColor = Colors.white,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: CupertinoSwitch(
                value: value,
                onChanged: (val) {
                   HapticFeedback.lightImpact();
                   onChanged(val);
                },
                activeColor: Colors.white,
                trackColor: Colors.grey.withOpacity(0.3),
                thumbColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

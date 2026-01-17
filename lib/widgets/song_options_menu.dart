import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/download_provider.dart';
import 'package:muzo/providers/bottom_sheet_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/download_service.dart';
import 'package:muzo/widgets/playlist_selection_dialog.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/navigator_key.dart';

class SongOptionsMenu extends ConsumerWidget {
  final YtifyResult result;
  final bool fromHistory;
  final bool fromPlayer;
  final VoidCallback? onClose;

  const SongOptionsMenu({
    super.key,
    required this.result,
    this.fromHistory = false,
    this.fromPlayer = false,
    this.onClose,
  });

  /// Show the bottom sheet using the provider (renders in MainLayout's Stack)
  static void show(
    WidgetRef ref,
    YtifyResult result, {
    bool fromHistory = false,
    bool fromPlayer = false,
  }) {
    ref
        .read(bottomSheetProvider.notifier)
        .show(result, fromHistory: fromHistory, fromPlayer: fromPlayer);
  }

  /// Hide the bottom sheet
  static void hide(WidgetRef ref) {
    ref.read(bottomSheetProvider.notifier).hide();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    return ValueListenableBuilder<List<YtifyResult>>(
      valueListenable: storage.favoritesListenable,
      builder: (context, favorites, _) {
        final isFav =
            result.videoId != null && storage.isFavorite(result.videoId!);
        final isDownloaded =
            result.videoId != null && storage.isDownloaded(result.videoId!);

        // Get Thumbnail URL
        String imageUrl = '';
        if (result.thumbnails.isNotEmpty) {
          imageUrl = result.thumbnails.last.url;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey[900],
                                  child: const Icon(
                                    FluentIcons.music_note_2_24_regular,
                                    color: Colors.white,
                                  ),
                                ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey[900],
                            child: const Icon(
                              FluentIcons.music_note_2_24_regular,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.artists?.map((a) => a.name).join(', ') ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            _buildMenuOption(
              context,
              icon: FluentIcons.list_24_regular,
              label: 'Add to queue',
              onTap: () {
                onClose?.call();
                ref.read(audioHandlerProvider).addToQueue(result);
                final ctx = navigatorKey.currentContext;
                if (ctx != null) showGlassSnackBar(ctx, 'Added to queue');
              },
            ),
            if (fromPlayer) ...[
              ValueListenableBuilder<bool>(
                valueListenable: ref
                    .watch(audioHandlerProvider)
                    .isLofiModeNotifier,
                builder: (context, isLofi, _) {
                  return _buildSwitchOption(
                    context,
                    icon: FluentIcons.wand_24_regular,
                    label: 'Lofi Mode',
                    value: isLofi,
                    onChanged: (val) =>
                        ref.read(audioHandlerProvider).toggleLofiMode(),
                  );
                },
              ),
            ],
            _buildMenuOption(
              context,
              icon: FluentIcons.play_circle_24_regular,
              label: 'Play next',
              onTap: () {
                onClose?.call();
                ref.read(audioHandlerProvider).playNext(result);
              },
            ),
            _buildMenuOption(
              context,
              icon: FluentIcons.add_24_regular,
              label: 'Add to playlist',
              onTap: () {
                onClose?.call();
                showCupertinoDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => PlaylistSelectionDialog(song: result),
                );
              },
            ),
            _buildMenuOption(
              context,
              icon: isFav
                  ? FluentIcons.heart_24_filled
                  : FluentIcons.heart_24_regular,
              label: isFav ? 'Remove from favorites' : 'Add to favorites',
              iconColor: isFav ? Colors.red : Colors.white,
              onTap: () {
                onClose?.call();
                storage.toggleFavorite(result);
                final ctx = navigatorKey.currentContext;
                if (ctx != null) {
                  showGlassSnackBar(
                    ctx,
                    isFav ? 'Removed from favorites' : 'Added to favorites',
                  );
                }
              },
            ),
            if (fromHistory) ...[
              _buildMenuOption(
                context,
                icon: FluentIcons.history_24_regular,
                label: 'Remove from history',
                onTap: () {
                  onClose?.call();
                  if (result.videoId != null) {
                    storage.removeFromHistory(result.videoId!);
                    final ctx = navigatorKey.currentContext;
                    if (ctx != null) {
                      showGlassSnackBar(ctx, 'Removed from history');
                    }
                  }
                },
              ),
            ],
            _buildMenuOption(
              context,
              icon: isDownloaded
                  ? FluentIcons.checkmark_24_regular
                  : FluentIcons.arrow_download_24_regular,
              label: isDownloaded ? 'Remove download' : 'Download',
              onTap: () async {
                onClose?.call();
                final downloadService = DownloadService();
                final ctx = navigatorKey.currentContext;
                if (result.videoId != null) {
                  if (storage.isDownloaded(result.videoId!)) {
                    await downloadService.deleteDownload(result.videoId!);
                    if (ctx != null) {
                      showGlassSnackBar(ctx, 'Removed from downloads');
                    }
                  } else {
                    // Show downloading snackbar
                    if (ctx != null) {
                      showGlassSnackBar(ctx, 'Downloading...');
                    }

                    // Use provider to start download and track progress
                    final success = await ref
                        .read(downloadProvider.notifier)
                        .startDownload(result);

                    final ctxAfter = navigatorKey.currentContext;
                    if (ctxAfter != null) {
                      if (success) {
                        showGlassSnackBar(ctxAfter, 'Download complete');
                      } else {
                        showGlassSnackBar(
                          ctxAfter,
                          'Download failed - Please try again',
                        );
                      }
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
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
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.grey.withOpacity(0.3),
                thumbColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

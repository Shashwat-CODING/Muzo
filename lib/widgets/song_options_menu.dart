import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/download_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/download_service.dart';
import 'package:muzo/widgets/playlist_selection_dialog.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/providers/overlay_provider.dart';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
import 'package:muzo/widgets/sleep_timer_dialog.dart';

class SongOptionsMenu extends ConsumerWidget {
  final MuzoItem result;
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

  static DateTime? _lastShowTime;

  static void show(
    WidgetRef ref,
    MuzoItem result, {
    bool fromHistory = false,
    bool fromPlayer = false,
  }) {
    final now = DateTime.now();
    if (_lastShowTime != null &&
        now.difference(_lastShowTime!) < const Duration(milliseconds: 500)) {
      return; // Debounce rapid taps
    }
    _lastShowTime = now;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (fromPlayer) {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xD91C1C1E) : const Color(0xD9F2F2F7),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    top: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SongOptionsMenu(
                      result: result,
                      fromHistory: fromHistory,
                      fromPlayer: fromPlayer,
                      onClose: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    ref.read(globalBottomSheetProvider.notifier).state = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xD91C1C1E) : const Color(0xD9F2F2F7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: SongOptionsMenu(
                result: result,
                fromHistory: fromHistory,
                fromPlayer: fromPlayer,
                onClose: () => ref.read(globalBottomSheetProvider.notifier).state = null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void hide(WidgetRef ref) {
    ref.read(globalBottomSheetProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<List<MuzoItem>>(
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

        final List<Widget> options = [
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
          _buildMenuOption(
            context,
            icon: FluentIcons.share_24_regular,
            label: 'Share',
            onTap: () {
              onClose?.call();
              if (result.videoId != null) {
                // ignore: deprecated_member_use
                Share.share('https://youtube.com/watch?v=${result.videoId}');
              }
            },
          ),
          if (fromPlayer) ...[
            _buildMenuOption(
              context,
              icon: FluentIcons.timer_24_regular,
              label: 'Sleep Timer',
              onTap: () {
                onClose?.call();
                final ctx = navigatorKey.currentContext;
                if (ctx != null) {
                  showDialog(
                    context: ctx,
                    builder: (context) => const SleepTimerDialog(),
                  );
                }
              },
            ),
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
              final ctx = navigatorKey.currentContext;
              if (ctx != null) {
                showCupertinoDialog(
                  context: ctx,
                  barrierDismissible: true,
                  builder: (context) => PlaylistSelectionDialog(song: result),
                );
              }
            },
          ),
          _buildMenuOption(
            context,
            icon: isFav
                ? FluentIcons.heart_24_filled
                : FluentIcons.heart_24_regular,
            label: isFav ? 'Remove from favorites' : 'Add to favorites',
            iconColor: isFav ? Colors.red : Theme.of(context).colorScheme.onSurface,
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
                  if (ctx != null && ctx.mounted) {
                    showGlassSnackBar(ctx, 'Removed from downloads');
                  }
                } else {
                  if (ctx != null) {
                    showGlassSnackBar(ctx, 'Downloading...');
                  }

                  final success = await ref
                      .read(downloadProvider.notifier)
                      .startDownload(result);

                  final ctxAfter = navigatorKey.currentContext;
                  if (ctxAfter != null && ctxAfter.mounted) {
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
        ];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
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
                                  color: isDark ? Colors.grey[900] : Colors.grey[300],
                                  child: Icon(
                                    FluentIcons.music_note_2_24_regular,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: isDark ? Colors.grey[900] : Colors.grey[300],
                            child: Icon(
                              FluentIcons.music_note_2_24_regular,
                              color: Theme.of(context).colorScheme.onSurface,
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.artists?.map((a) => a.name).join(', ') ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 0.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 4),
            Column(
              children: [
                for (int i = 0; i < options.length; i++) ...[
                  options[i],
                  if (i < options.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 60),
                      child: Container(
                        height: 0.5,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 16),
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
    Color? iconColor,
  }) {
    final effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: effectiveIconColor, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.3,
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
    Color? iconColor,
  }) {
    final effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: effectiveIconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.3,
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
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                thumbColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

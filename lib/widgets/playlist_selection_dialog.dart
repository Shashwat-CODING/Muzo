import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/widgets/app_alert_dialog.dart';

class PlaylistSelectionDialog extends ConsumerStatefulWidget {
  final MuzoItem song;

  const PlaylistSelectionDialog({super.key, required this.song});

  @override
  ConsumerState<PlaylistSelectionDialog> createState() =>
      _PlaylistSelectionDialogState();
}

class _PlaylistSelectionDialogState
    extends ConsumerState<PlaylistSelectionDialog> {
  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final playlists = storage.getPlaylistNames();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerCol = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return AppAlertDialog(
      title: 'Add to Playlist',
      content: SizedBox(
        width: double.maxFinite,
        child: playlists.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No playlists created yet.',
                  style: TextStyle(color: CupertinoColors.systemGrey),
                ),
              )
            : Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: dividerCol,
                      width: 0.8,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final name = playlists[index];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                storage.addToPlaylist(name, widget.song);
                                Navigator.pop(context);
                                showGlassSnackBar(context, 'Added to $name');
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      FluentIcons.music_note_2_24_regular,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (index < playlists.length - 1)
                              Padding(
                                padding: const EdgeInsets.only(left: 48.0),
                                child: Container(height: 0.5, color: dividerCol),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showCreatePlaylistDialog(context, storage);
          },
          child: Text(
            'New Playlist',
            style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, StorageService storage) {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    showAppAlertDialog(
      context: context,
      title: 'Create Playlist',
      content: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: CupertinoTextField(
          controller: controller,
          placeholder: 'Playlist Name',
          placeholderStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.35), fontSize: 14),
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              storage.createPlaylist(controller.text);
              storage.addToPlaylist(controller.text, widget.song);
              Navigator.pop(context);
              showGlassSnackBar(context, 'Added to ${controller.text}');
            }
          },
          child: Text(
            'Create',
            style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

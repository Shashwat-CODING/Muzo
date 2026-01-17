import 'package:flutter/cupertino.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/widgets/app_alert_dialog.dart';

class PlaylistSelectionDialog extends ConsumerStatefulWidget {
  final YtifyResult song;

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
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: SizedBox(
                    height:
                        playlists.length * 56.0 >
                            MediaQuery.of(context).size.height * 0.5
                        ? MediaQuery.of(context).size.height * 0.5
                        : playlists.length * 56.0,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final name = playlists[index];
                        return ListTile(
                          leading: const Icon(
                            FluentIcons.music_note_2_24_regular,
                            color: Colors.white,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            storage.addToPlaylist(name, widget.song);
                            Navigator.pop(context);
                            showGlassSnackBar(context, 'Added to $name');
                          },
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
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showCreatePlaylistDialog(context, storage);
          },
          child: const Text(
            'New Playlist',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, StorageService storage) {
    final controller = TextEditingController();
    showAppAlertDialog(
      context: context,
      title: 'Create Playlist',
      content: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: CupertinoTextField(
          controller: controller,
          placeholder: 'Playlist Name',
          placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey),
          style: const TextStyle(color: CupertinoColors.white),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              storage.createPlaylist(controller.text);
              // Automatically add the song to the new playlist
              storage.addToPlaylist(controller.text, widget.song);
              Navigator.pop(context);
              showGlassSnackBar(context, 'Added to ${controller.text}');
            }
          },
          child: const Text(
            'Create',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

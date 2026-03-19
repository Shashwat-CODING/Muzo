import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/models/user_data.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/providers/download_provider.dart';
import 'package:muzo/widgets/song_options_menu.dart';

class PlaylistDetailsScreen extends ConsumerWidget {
  final String playlistName;
  final bool isSystemPlaylist;

  const PlaylistDetailsScreen({
    super.key,
    required this.playlistName,
    this.isSystemPlaylist = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(playlistName),
        actions: [
          if (!isSystemPlaylist)
            IconButton(
              icon: const Icon(FluentIcons.delete_24_regular),
              onPressed: () {
                // Confirm delete
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white),
                    title: Text(
                      'Delete Playlist?',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                    content: const Text(
                      'This cannot be undone.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          storage.deletePlaylist(playlistName);
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Go back to library
                        },
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (playlistName == 'Favorites') {
            return ValueListenableBuilder<List<MuzoItem>>(
              valueListenable: storage.favoritesListenable,
              builder: (context, favorites, _) {
                return _buildSongList(context, ref, favorites, storage);
              },
            );
          } else if (playlistName == 'Downloads') {
            return ValueListenableBuilder(
              valueListenable: storage.downloadsListenable,
              builder: (context, box, _) {
                final downloadState = ref.watch(downloadProvider);
                final activeSongs = downloadState.activeDownloads.values
                    .toList();

                final downloads = storage.getDownloads();
                final storedSongs = downloads
                    .map(
                      (d) => MuzoItem.fromJson(
                        Map<String, dynamic>.from(d['result']),
                      ),
                    )
                    .toList();

                // Combine active first.
                final allSongs = [...activeSongs, ...storedSongs];

                return _buildSongList(
                  context,
                  ref,
                  allSongs,
                  storage,
                  progressMap: downloadState.progressMap,
                );
              },
            );
          } else {
            return ValueListenableBuilder<List<Playlist>>(
              valueListenable: storage.playlistsListenable,
              builder: (context, playlists, _) {
                final songs = storage.getPlaylistSongs(playlistName);
                return _buildSongList(context, ref, songs, storage);
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildSongList(
    BuildContext context,
    WidgetRef ref,
    List<MuzoItem> songs,
    StorageService storage, {
    Map<String, double>? progressMap,
  }) {
    if (songs.isEmpty) {
      return const Center(
        child: Text('No songs found', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        // Play All Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(audioHandlerProvider).playAll(songs);
              },
              icon: Icon(FluentIcons.play_24_filled, color: Theme.of(context).colorScheme.surface),
              label: Text(
                'Play All',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface,
                foregroundColor: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),

        // Songs List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              final progress = progressMap?[song.videoId];
              final isDownloading = progress != null;

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: song.thumbnails.isNotEmpty
                        ? song.thumbnails.last.url
                        : '',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      width: 48,
                      height: 48,
                      child: Icon(
                        FluentIcons.music_note_2_24_regular,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                subtitle: isDownloading
                    ? LinearProgressIndicator(
                        value: progress,
                    backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF1ED760),
                        ),
                        minHeight: 4,
                      )
                    : Text(
                        song.displayArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                trailing: IconButton(
                  icon: Icon(
                    playlistName == 'Favorites'
                        ? FluentIcons.heart_24_filled
                        : playlistName == 'Downloads'
                        ? (isDownloading
                              ? FluentIcons.dismiss_circle_24_regular
                              : FluentIcons.delete_24_regular)
                        : FluentIcons.subtract_circle_24_regular,
                    color: playlistName == 'Favorites'
                        ? const Color(0xFF1ED760)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  onPressed: () {
                    if (playlistName == 'Favorites') {
                      storage.toggleFavorite(song);
                    } else if (playlistName == 'Downloads') {
                      if (isDownloading) {
                        ref
                            .read(downloadProvider.notifier)
                            .deleteDownload(song.videoId!);
                      } else {
                        storage.removeDownload(song.videoId!);
                      }
                    } else {
                      storage.removeFromPlaylist(
                        playlistName,
                        song.videoId ?? '',
                      );
                    }
                  },
                ),
                onTap: () {
                  if (!isDownloading) {
                    ref.read(audioHandlerProvider).playVideo(song);
                  }
                },
                onLongPress: () {
                  if (!isDownloading) {
                    SongOptionsMenu.show(ref, song);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

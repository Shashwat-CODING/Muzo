import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/ytify_result.dart';
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
      backgroundColor: Colors.transparent,
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
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text(
                      'Delete Playlist?',
                      style: TextStyle(color: Colors.white),
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
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
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
            return ValueListenableBuilder<List<YtifyResult>>(
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
                      (d) => YtifyResult.fromJson(
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
            return ValueListenableBuilder<Map<String, List<YtifyResult>>>(
              valueListenable: storage.playlistsListenable,
              builder: (context, playlistsMap, _) {
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
    List<YtifyResult> songs,
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
              icon: const Icon(FluentIcons.play_24_filled, color: Colors.black),
              label: const Text(
                'Play All',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
          ),
        ),

        // Songs List
        Expanded(
          child: ListView.builder(
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
                      color: Colors.grey[800],
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: isDownloading
                    ? LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF1ED760),
                        ),
                        minHeight: 4,
                      )
                    : Text(
                        song.artists?.map((a) => a.name).join(', ') ??
                            'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[400]),
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
                        : Colors.grey,
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

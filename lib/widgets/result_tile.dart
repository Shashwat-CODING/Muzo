import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:ytx/models/ytify_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytx/providers/player_provider.dart';
import 'package:ytx/widgets/playlist_selection_dialog.dart';
import 'package:ytx/widgets/glass_snackbar.dart';
import 'package:ytx/services/storage_service.dart';
import 'package:ytx/services/download_service.dart';
import 'package:ytx/providers/download_provider.dart';
import 'package:ytx/widgets/app_alert_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:ytx/screens/artist_screen.dart';
import 'package:ytx/screens/playlist_screen.dart';
import 'package:ytx/screens/channel_screen.dart';

class ResultTile extends ConsumerWidget {
  final YtifyResult result;
  final bool compact;

  const ResultTile({super.key, required this.result, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {


    String imageUrl = '';
    if (result.thumbnails.isNotEmpty) {
      imageUrl = result.thumbnails.last.url;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (result.resultType == 'artist' && result.browseId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArtistScreen(
                  browseId: result.browseId!,
                  artistName: result.title,
                  thumbnailUrl: result.thumbnails.lastOrNull?.url,
                ),
              ),
            );
          } else if (result.resultType == 'playlist' && result.browseId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaylistScreen(
                  playlistId: result.browseId!,
                  title: result.title,
                  thumbnailUrl: result.thumbnails.lastOrNull?.url,
                ),
              ),
            );
          } else if (result.resultType == 'channel' && result.browseId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChannelScreen(
                  channelId: result.browseId!,
                  title: result.title,
                  thumbnailUrl: result.thumbnails.lastOrNull?.url,
                  subscriberCount: result.subscriberCount,
                  videoCount: result.videoCount,
                  description: result.description,
                ),
              ),
            );
          } else if (result.videoId != null) {
            ref.read(audioHandlerProvider).playVideo(result);
          }
        },
        child: Padding(
          padding: compact 
              ? const EdgeInsets.symmetric(horizontal: 0, vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 54,
                        fit: BoxFit.fitHeight,
                        placeholder: (context, url) => Container(
                          height: 54,
                          width: 54,
                          color: Colors.grey[800],
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 54,
                          width: 54,
                          color: Colors.grey[900],
                          child: const Icon(Icons.error),
                        ),
                      )
                    : Container(
                        height: 54,
                        width: 54,
                        color: Colors.grey[900],
                        child: const Icon(Icons.music_note),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      () {
                        String subtitle = '';
                        if (result.artists != null && result.artists!.isNotEmpty) {
                          subtitle += result.artists!.map((a) => a.name).join(', ');
                        } else if (result.resultType == 'artist') {
                          return 'Artist';
                        } else if (result.resultType == 'playlist') {
                          return 'Playlist';
                        }

                        if (result.duration != null) {
                          if (subtitle.isNotEmpty) subtitle += ' • ';
                          subtitle += result.duration!;
                        }
                        
                        if (result.views != null) {
                           if (subtitle.isNotEmpty) subtitle += ' • ';
                           subtitle += '${result.views} views';
                        }
                        
                        return subtitle;
                      }(),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // We need to wrap the PopupMenuButton with a Consumer to access storage
              Consumer(
                builder: (context, ref, _) {
                  final storage = ref.watch(storageServiceProvider);
                  return ValueListenableBuilder(
                    valueListenable: storage.favoritesListenable,
                    builder: (context, box, _) {
                      if (result.videoId == null) return const SizedBox.shrink();
                      final isFav = storage.isFavorite(result.videoId!);
                      return PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        color: const Color(0xFF1E1E1E),
                        onSelected: (value) async {
                          if (value == 'queue') {
                            ref.read(audioHandlerProvider).addToQueue(result);
                            showGlassSnackBar(context, 'Added to queue');
                          } else if (value == 'play_next') {
                            ref.read(audioHandlerProvider).playNext(result);
                          } else if (value == 'playlist') {
                            showDialog(
                              context: context,
                              builder: (context) => PlaylistSelectionDialog(song: result),
                            );
                          } else if (value == 'favorite') {
                            storage.toggleFavorite(result);
                            showGlassSnackBar(context, isFav ? 'Removed from favorites' : 'Added to favorites');
                          } else if (value == 'download') {
                            final downloadService = DownloadService();
                            if (storage.isDownloaded(result.videoId!)) {
                              await downloadService.deleteDownload(result.videoId!);
                              if (context.mounted) showGlassSnackBar(context, 'Removed from downloads');
                            } else {
                              // Show downloading alert
                              bool isDialogVisible = true;
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
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Hide'),
                                  ),
                                ],
                              ).then((_) => isDialogVisible = false);
                              
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
                        itemBuilder: (BuildContext context) {
                          final isDownloaded = storage.isDownloaded(result.videoId!);
                          return <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'queue',
                            child: Row(
                              children: [
                                Icon(Icons.queue_music, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Add to queue', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'play_next',
                            child: Row(
                              children: [
                                Icon(Icons.playlist_play, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Play next', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'playlist',
                            child: Row(
                              children: [
                                Icon(Icons.playlist_add, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Add to playlist', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'favorite',
                            child: Row(
                              children: [
                                Icon(isFav ? Icons.favorite : Icons.favorite_border, color: Colors.white),
                                const SizedBox(width: 12),
                                Text(isFav ? 'Remove from favorites' : 'Add to favorites', style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(isDownloaded ? Icons.download_done : Icons.download, color: Colors.white),
                                const SizedBox(width: 12),
                                Text(isDownloaded ? 'Remove download' : 'Download', style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ];
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

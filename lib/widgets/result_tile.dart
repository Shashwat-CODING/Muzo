import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
          HapticFeedback.lightImpact();
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
              // Calculate width based on result type
              Builder(
                builder: (context) {
                  final isVideo = result.resultType == 'video';
                  final width = isVideo ? 100.0 : 56.0;
                  final height = 56.0;
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: height,
                              width: width,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: height,
                                width: width,
                                color: Colors.grey[900],
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: height,
                                width: width,
                                color: Colors.grey[900],
                                child: const Icon(Icons.error, size: 20),
                              ),
                            )
                          : Container(
                              height: height,
                              width: width,
                              color: Colors.grey[900],
                              child: const Icon(Icons.music_note),
                            ),
                    ),
                  );
                }
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                      style: TextStyle(
                        color: Colors.grey[400], 
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
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
                  return ValueListenableBuilder<List<YtifyResult>>(
                    valueListenable: storage.favoritesListenable,
                    builder: (context, favorites, _) {
                      if (result.videoId == null) return const SizedBox.shrink();
                      final isFav = storage.isFavorite(result.videoId!);
                      final isDownloaded = storage.isDownloaded(result.videoId!);
                      
                      return IconButton(
                        icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, color: Colors.white, size: 20),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          showDialog(
                            context: context,
                            barrierColor: Colors.black.withValues(alpha: 0.5),
                            builder: (context) => Center(
                              child: Material(
                                color: Colors.transparent,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                    child: Container(
                                      width: 300,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E1E1E).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                      ),
                                      child: Column(
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
                                            icon: FontAwesomeIcons.list,
                                            label: 'Add to queue',
                                            onTap: () {
                                              Navigator.pop(context);
                                              ref.read(audioHandlerProvider).addToQueue(result);
                                              showGlassSnackBar(context, 'Added to queue');
                                            },
                                          ),
                                          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                                          _buildMenuOption(
                                            context,
                                            icon: FontAwesomeIcons.circlePlay,
                                            label: 'Play next',
                                            onTap: () {
                                              Navigator.pop(context);
                                              ref.read(audioHandlerProvider).playNext(result);
                                            },
                                          ),
                                          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                                          _buildMenuOption(
                                            context,
                                            icon: FontAwesomeIcons.plus,
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
                                            icon: isFav ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
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
                                            icon: isDownloaded ? FontAwesomeIcons.check : FontAwesomeIcons.download,
                                            label: isDownloaded ? 'Remove download' : 'Download',
                                            onTap: () async {
                                              Navigator.pop(context);
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
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
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
            FaIcon(icon, color: iconColor, size: 20),
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
}

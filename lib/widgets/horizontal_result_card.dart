import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/screens/artist_screen.dart';
import 'package:muzo/screens/playlist_screen.dart';
import 'package:muzo/screens/channel_screen.dart';

class HorizontalResultCard extends ConsumerWidget {
  final YtifyResult result;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool isVideo;

  const HorizontalResultCard({
    super.key,
    required this.result,
    this.onTap,
    this.width = 160,
    this.height = 160,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
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
            } else if (result.resultType == 'playlist' &&
                result.browseId != null) {
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
            } else if (result.resultType == 'channel' &&
                result.browseId != null) {
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
            } else {
              // Default action: Play the item
              ref.read(audioHandlerProvider).playVideo(result);
            }

            // Also add to queue if it's a playlist or just play this one
            // For now, just play this one.
          },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: result.thumbnails.lastOrNull?.url ?? '',
                    width: width,
                    height: isVideo
                        ? width * 9 / 16
                        : width, // 16:9 for videos, 1:1 for others
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: width,
                      height: isVideo ? width * 9 / 16 : width,
                      color: Colors.grey[900],
                      child: const Icon(
                        FluentIcons.music_note_2_24_regular,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (isVideo && result.duration != null)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          result.duration!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              result.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Subtitle (Artist / Views)
            Text(
              result.artists?.map((a) => a.name).join(', ') ??
                  result.views ??
                  '',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/screens/artist_screen.dart';
import 'package:muzo/screens/playlist_screen.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/screens/playlist_details_screen.dart';
import 'package:muzo/services/ytm_home.dart';

class HomeItemWidget extends ConsumerWidget {
  final HomeItem item;

  const HomeItemWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _handleTap(context, ref),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[900],
                          child: const Icon(FluentIcons.music_note_2_24_regular,
                              color: Colors.white),
                        ),
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: const Icon(FluentIcons.music_note_2_24_regular,
                            color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (item.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                item.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();

    if (item.videoId != null) {
      // It's a song or video
      final ytifyResult = YtifyResult(
        title: item.title,
        thumbnails: [
          if (item.thumbnailUrl != null)
            YtifyThumbnail(url: item.thumbnailUrl!, width: 500, height: 500)
        ],
        resultType: item.type == 'video_types' ? 'video' : 'song',
        isExplicit: false,
        videoId: item.videoId,
      );
      ref.read(audioHandlerProvider).playVideo(ytifyResult);
    } else if (item.playlistId != null || item.type == 'playlist' || (item.type == 'album' && item.browseId != null)) {
      // It's a playlist or album
      // For albums from YTM home, the browseId starts with MPRE usually, but we need a playlistId to fetch tracks.
      // However, YTM home items often provide a direct playlistId even for albums. 
      // If only browseId is present for an album, we might need a different handling or hope PlaylistScreen handles browseId (it usually expects playlistId).
      // Let's assume playlistId is preferred, if not fall back to browseId if PlaylistScreen supports it, 
      // OR we just pass browseId as playlistId if the service can handle it.
      
      final idToUse = item.playlistId ?? item.browseId;
      
      // Check if it's a local playlist
      final storage = ref.read(storageServiceProvider);
      final localPlaylists = storage.getPlaylistNames();
      
      // We assume if specific playlistId matches a local name, it's local.
      // Or if the item title matches a local name (since we used name as ID for local ones).
      if (localPlaylists.contains(idToUse) || localPlaylists.contains(item.title)) {
         Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailsScreen(
              playlistName: localPlaylists.contains(idToUse) ? idToUse! : item.title,
            ),
          ),
        );
      } else if (idToUse != null) {
         Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistScreen(
              playlistId: idToUse,
              title: item.title,
              thumbnailUrl: item.thumbnailUrl,
            ),
          ),
        );
      }
    } else if (item.browseId != null && (item.type == 'artist' || item.browseId!.startsWith('UC'))) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArtistScreen(
            browseId: item.browseId!,
            artistName: item.title,
            thumbnailUrl: item.thumbnailUrl,
          ),
        ),
      );
    }
  }
}

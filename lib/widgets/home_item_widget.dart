import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/screens/artist_screen.dart';
import 'package:muzo/screens/playlist_screen.dart';
import 'package:muzo/screens/album_screen.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/screens/playlist_details_screen.dart';
import 'package:muzo/services/ytm_home.dart';
import 'package:muzo/utils/page_routes.dart';

class HomeItemWidget extends ConsumerWidget {
  final HomeItem item;

  const HomeItemWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _handleTap(context, ref),
      child: Container(
        width: 140, // Reduced from 150
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8), // Reduced to 8 for a cleaner look
                child: item.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            FluentIcons.music_note_2_24_filled,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          FluentIcons.music_note_2_24_filled,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8), // slightly more spacing
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600, // Make title a bit bolder
                fontSize: 13,
              ),
            ),
            if (item.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                item.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      final muzoResult = MuzoItem(
        title: item.title,
        thumbnails: [
          if (item.thumbnailUrl != null)
            MuzoThumbnail(url: item.thumbnailUrl!, width: 500, height: 500),
        ],
        resultType: item.type == 'video_types' ? 'video' : 'song',
        isExplicit: false,
        videoId: item.videoId,
        artists: item.subtitle != null ? [MuzoArtist(name: item.subtitle!, id: null)] : null,
      );
      ref.read(audioHandlerProvider).playVideo(muzoResult);
    } else if (item.type == 'album' && item.browseId != null) {
      Navigator.push(
        context,
        SlidePageRoute(
          page: AlbumScreen(
            albumId: item.browseId!,
            albumName: item.title,
            thumbnailUrl: item.thumbnailUrl,
          ),
        ),
      );
    } else if (item.playlistId != null || item.type == 'playlist') {
      final idToUse = item.playlistId ?? item.browseId;

      // Check if it's a local playlist
      final storage = ref.read(storageServiceProvider);
      final localPlaylists = storage.getPlaylistNames();

      if (localPlaylists.contains(idToUse) || localPlaylists.contains(item.title)) {
        Navigator.push(
          context,
          SlidePageRoute(
            page: PlaylistDetailsScreen(
              playlistName: localPlaylists.contains(idToUse) ? idToUse! : item.title,
            ),
          ),
        );
      } else if (idToUse != null) {
        Navigator.push(
          context,
          SlidePageRoute(
            page: PlaylistScreen(
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
        SlidePageRoute(
          page: ArtistScreen(
            browseId: item.browseId!,
            artistName: item.title,
            thumbnailUrl: item.thumbnailUrl,
          ),
        ),
      );
    }
  }
}


import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/screens/playlist_screen.dart';
import 'package:muzo/screens/playlist_details_screen.dart';
import 'package:muzo/screens/artist_screen.dart';
import 'package:muzo/services/storage_service.dart';

class RectHomeItem extends ConsumerWidget {
  final YtifyResult item;

  const RectHomeItem({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = item.thumbnails.isNotEmpty ? item.thumbnails.last.url : '';
    final isPlaylistOrAlbum =
        item.resultType == 'playlist' || item.resultType == 'album';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (item.resultType == 'song' || item.resultType == 'video') {
          ref.read(audioHandlerProvider).playVideo(item);
        } else if (isPlaylistOrAlbum) {
          final idToUse = item.browseId;
          final storage = ref.read(storageServiceProvider);
          final localPlaylists = storage.getPlaylistNames();
          final title = item.title;

          if (localPlaylists.contains(title)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PlaylistDetailsScreen(playlistName: title),
              ),
            );
          } else if (idToUse != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaylistScreen(
                  playlistId: idToUse,
                  title: item.title,
                  thumbnailUrl: item.thumbnails.isNotEmpty
                      ? item.thumbnails.last.url
                      : null,
                ),
              ),
            );
          } else {
            ref.read(audioHandlerProvider).playVideo(item);
          }
        } else if (item.resultType == 'artist' && item.browseId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtistScreen(
                browseId: item.browseId!,
                artistName: item.title,
                thumbnailUrl: item.thumbnails.isNotEmpty
                    ? item.thumbnails.last.url
                    : null,
              ),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Album art
            imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[850],
                      child: const Icon(
                        FluentIcons.music_note_2_24_filled,
                        color: Colors.white54,
                        size: 28,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey[850],
                    child: const Icon(
                      FluentIcons.music_note_2_24_filled,
                      color: Colors.white54,
                      size: 28,
                    ),
                  ),
            // Gradient + title overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(7, 18, 7, 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.82),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            // Playlist/album arrow badge
            if (isPlaylistOrAlbum)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

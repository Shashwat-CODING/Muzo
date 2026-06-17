import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/screens/playlist_screen.dart';
import 'package:muzo/screens/playlist_details_screen.dart';
import 'package:muzo/screens/artist_screen.dart';
import 'package:muzo/services/storage_service.dart';

class RectHomeItem extends ConsumerWidget {
  final MuzoItem item;

  const RectHomeItem({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = item.thumbnails.isNotEmpty ? item.thumbnails.last.url : '';
    final isPlaylistOrAlbum =
        item.resultType == 'playlist' || item.resultType == 'album';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (isPlaylistOrAlbum) {
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
        } else if (item.videoId != null) {
          // Play anything with a valid videoId if it's not a container
          ref.read(audioHandlerProvider).playVideo(item);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Album art
              imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          FluentIcons.music_note_2_24_filled,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 32,
                        ),
                      ),
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        FluentIcons.music_note_2_24_filled,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 32,
                      ),
                    ),
              // Gradient + title overlay at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              // Playlist/album rounded icon badge
              if (isPlaylistOrAlbum)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/widgets/glass_container.dart';
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

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (item.resultType == 'song' || item.resultType == 'video') {
           ref.read(audioHandlerProvider).playVideo(item);
        } else if (item.resultType == 'playlist' || item.resultType == 'album') {
           final idToUse = item.browseId; // YtifyResult uses browseId for playlists/albums 
           
           // Check local
           final storage = ref.read(storageServiceProvider);
           final localPlaylists = storage.getPlaylistNames();
           final title = item.title;
           
           if (localPlaylists.contains(title)) { 
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlaylistDetailsScreen(playlistName: title),
                ),
              );
           } else if (idToUse != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlaylistScreen(
                    playlistId: idToUse,
                    title: item.title,
                    thumbnailUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
                  ),
                ),
              );
           } else {
             // Fallback
             ref.read(audioHandlerProvider).playVideo(item);
           }
        } else if (item.resultType == 'artist' && item.browseId != null) {
            Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArtistScreen(
                browseId: item.browseId!,
                artistName: item.title,
                thumbnailUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : null,
              ),
            ),
          );
        }
      },
      child: GlassContainer(
        blur: 10,
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 56,
                      width: 56,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        height: 56,
                        width: 56,
                        color: Colors.grey[800],
                        child: const Icon(FluentIcons.music_note_2_24_regular, color: Colors.white, size: 20),
                      ),
                    )
                  : Container(
                      height: 56,
                      width: 56,
                      color: Colors.grey[800],
                      child: const Icon(FluentIcons.music_note_2_24_regular, color: Colors.white, size: 20),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

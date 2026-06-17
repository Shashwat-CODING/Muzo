import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:muzo/models/muzo_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/screens/artist_screen.dart';
import 'package:muzo/screens/playlist_screen.dart';
import 'package:muzo/screens/channel_screen.dart';
import 'package:muzo/screens/album_screen.dart';
import 'package:muzo/widgets/song_options_menu.dart';
import 'package:muzo/utils/page_routes.dart';

class ResultTile extends ConsumerWidget {
  final MuzoItem result;
  final bool compact;
  final bool fromHistory;

  const ResultTile({
    super.key,
    required this.result,
    this.compact = false,
    this.fromHistory = false,
  });

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
          final type = result.resultType.toLowerCase();
          final bId = result.browseId;
          
          final nav = Navigator.of(context);

          if (type == 'artist' && bId != null && bId.isNotEmpty) {
            nav.push(
              SlidePageRoute(
                page: ArtistScreen(
                  browseId: bId,
                  artistName: result.title,
                  thumbnailUrl: result.thumbnails.lastOrNull?.url,
                ),
              ),
            );
          } else if (type == 'playlist' && bId != null && bId.isNotEmpty) {
            nav.push(
              SlidePageRoute(
                page: PlaylistScreen(
                  playlistId: bId,
                  title: result.title,
                  thumbnailUrl: result.thumbnails.lastOrNull?.url,
                ),
              ),
            );
          } else if (type == 'album' && bId != null && bId.isNotEmpty) {
            nav.push(
              SlidePageRoute(
                page: AlbumScreen(
                  albumId: bId,
                  albumName: result.title,
                  thumbnailUrl: result.thumbnails.lastOrNull?.url,
                ),
              ),
            );
          } else if (type == 'channel' && bId != null && bId.isNotEmpty) {
            nav.push(
              SlidePageRoute(
                page: ChannelScreen(
                  channelId: bId,
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
              ? const EdgeInsets.symmetric(horizontal: 0, vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: Row(
            children: [
              // Calculate width based on result type
              // Calculate width based on result type
              Builder(
                builder: (context) {
                  final isVideo = result.resultType == 'video';
                  final defaultWidth = isVideo ? 82.0 : 46.0;
                  final height = 46.0;
                  return Container(
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: height,
                              fit: BoxFit.fitHeight,
                              placeholder: (context, url) => Container(
                                height: height,
                                width: defaultWidth,
                                color: Colors.grey[900],
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: height,
                                width: defaultWidth,
                                color: Colors.grey[900],
                                child: const Icon(
                                  FluentIcons.error_circle_24_regular,
                                  size: 20,
                                ),
                              ),
                            )
                          : Container(
                              height: height,
                              width: defaultWidth,
                              color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
                              child: Icon(
                                FluentIcons.music_note_2_24_regular,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                            ),
                    ),
                  );
                },
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
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      () {
                        String subtitle = result.displayArtist;
                        if (result.resultType == 'artist') {
                          subtitle = 'Artist';
                        } else if (result.resultType == 'playlist') {
                          subtitle = 'Playlist';
                        }

                        if (result.duration != null) {
                          if (subtitle.isNotEmpty && subtitle != 'Unknown') subtitle += ' • ';
                          subtitle += result.duration!;
                        }

                        if (result.views != null) {
                          if (subtitle.isNotEmpty && subtitle != 'Unknown') subtitle += ' • ';
                          subtitle += '${result.views} views';
                        }

                        return subtitle == 'Unknown' && result.duration == null ? '' : subtitle;
                      }(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  if (result.videoId == null) {
                    return Icon(
                      CupertinoIcons.chevron_right,
                      size: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
                    );
                  }
                  
                  // Use ref.read instead of ref.watch to prevent unnecessary rebuilds
                  // when other unrelated storage properties change.
                  final storage = ref.read(storageServiceProvider);
                  
                  return ValueListenableBuilder<List<MuzoItem>>(
                    valueListenable: storage.favoritesListenable,
                    builder: (context, favorites, _) {
                      return IconButton(
                        icon: Icon(
                          FluentIcons.more_vertical_24_regular,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          SongOptionsMenu.show(
                            ref,
                            result,
                            fromHistory: fromHistory,
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
}

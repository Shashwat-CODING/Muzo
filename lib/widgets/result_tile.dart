import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:muzo/models/ytify_result.dart';
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
  final YtifyResult result;
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
          if (result.resultType == 'artist' && result.browseId != null) {
            Navigator.push(
              context,
              SlidePageRoute(
                page: ArtistScreen(
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
              SlidePageRoute(
                page: PlaylistScreen(
                  playlistId: result.browseId!,
                  title: result.title,
                  thumbnailUrl: result.thumbnails.lastOrNull?.url,
                ),
              ),
            );
          } else if (result.resultType == 'album' && result.browseId != null) {
            Navigator.push(
              context,
              SlidePageRoute(
                page: AlbumScreen(
                  albumId: result.browseId!,
                  albumName: result.title,
                  thumbnailUrl: result.thumbnails.lastOrNull?.url,
                ),
              ),
            );
          } else if (result.resultType == 'channel' &&
              result.browseId != null) {
            Navigator.push(
              context,
              SlidePageRoute(
                page: ChannelScreen(
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
              // Calculate width based on result type
              Builder(
                builder: (context) {
                  final isVideo = result.resultType == 'video';
                  // Default width guess for placeholders
                  final defaultWidth = isVideo ? 100.0 : 56.0;
                  final height = 56.0;
                  return Container(
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl.replaceAll(
                                RegExp(r'=[sw]\d+(-h\d+)?'),
                                '=s800',
                              ),
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
                              color: Colors.grey[900],
                              child: const Icon(
                                FluentIcons.music_note_2_24_regular,
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
                        if (result.artists != null &&
                            result.artists!.isNotEmpty) {
                          subtitle += result.artists!
                              .map((a) => a.name)
                              .join(', ');
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
                      if (result.videoId == null) {
                        return const SizedBox.shrink();
                      }

                      return IconButton(
                        icon: const Icon(
                          FluentIcons.more_vertical_24_regular,
                          color: Colors.white,
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

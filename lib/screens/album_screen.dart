import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/models/album_details.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/download_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/widgets/global_background.dart';
import 'package:muzo/widgets/song_options_menu.dart';
import 'package:muzo/widgets/glass_snackbar.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  final String albumId;
  final String? albumName;
  final String? thumbnailUrl;

  const AlbumScreen({
    super.key,
    required this.albumId,
    this.albumName,
    this.thumbnailUrl,
  });

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  Future<AlbumDetails?>? _albumFuture;
  final ScrollController _scrollController = ScrollController();
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    _albumFuture = ref.read(muzoApiServiceProvider).getAlbumDetails(widget.albumId);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (offset > 150) {
      if (_opacity < 1.0) setState(() => _opacity = 1.0);
    } else {
      if (_opacity > 0.0) setState(() => _opacity = 0.0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);

    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FutureBuilder<AlbumDetails?>(
          future: _albumFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _buildErrorState();
            }
  
            final album = snapshot.data!;
  
            return Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      pinned: true,
                      leading: IconButton(
                        icon: Icon(CupertinoIcons.back, color: Theme.of(context).colorScheme.onSurface),
                        onPressed: () => Navigator.pop(context),
                      ),
                      title: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _opacity,
                        child: Text(
                          album.title,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                        ),
                      ),
                      centerTitle: true,
                    ),
  
                    // Large Centered Album Header & Action buttons
                    SliverToBoxAdapter(
                      child: _buildNewHeader(album),
                    ),
  
                    // Tracks Card (Grouped Card List)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Builder(
                              builder: (context) {
                                final isDark = Theme.of(context).brightness == Brightness.dark;
                                final cardBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03);
                                final cardBorder = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
                                final dividerColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05);

                                return Container(
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cardBorder,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    clipBehavior: Clip.antiAlias,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Column(
                                      children: List.generate(album.tracks.length, (index) {
                                        final song = album.tracks[index];
                                        return Column(
                                          children: [
                                            _buildTrackTile(song, index, album, downloadState.progressMap),
                                            if (index < album.tracks.length - 1)
                                              Divider(
                                                height: 1,
                                                indent: 48,
                                                color: dividerColor,
                                              ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                );
                              }
                            ),
                          ),
                        ),
                      ),
                    ),
  
                    const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: BackButton(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: Center(
        child: Text(
          "Could not load album",
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }

  Widget _buildNewHeader(AlbumDetails album) {
    final List<MuzoItem> tracksWithArt = album.tracks.map<MuzoItem>((track) {
      if (track.thumbnails.isEmpty && album.thumbnail.isNotEmpty) {
        return track.copyWith(
          thumbnails: [
            MuzoThumbnail(
              url: album.thumbnail,
              width: 500,
              height: 500,
            ),
          ],
        );
      }
      return track;
    }).toList();

    final storage = ref.watch(storageServiceProvider);
    final allDownloaded = tracksWithArt.isNotEmpty && tracksWithArt.every((track) =>
        track.videoId != null && storage.isDownloaded(track.videoId!));

    final String displayType = album.type.isEmpty
        ? 'Album'
        : (album.type[0].toUpperCase() + album.type.substring(1));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Large Album Art with rounded corners and drop shadow
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final artBorderColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1);
              final placeholderColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05);

              return Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: artBorderColor,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: album.thumbnail,
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: placeholderColor,
                      child: const Icon(FluentIcons.music_note_2_24_regular, size: 48, color: Colors.grey),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: placeholderColor,
                      child: const Icon(FluentIcons.music_note_2_24_regular, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              );
            }
          ),
          const SizedBox(height: 20),
          // Album Title
          Text(
            album.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Artist Name
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // Meta info
          Text(
            '$displayType • ${album.year} • ${album.tracks.length} Songs',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          // Actions: Play & Shuffle & Download
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: FluentIcons.play_24_filled,
                  label: 'Play',
                  onTap: () {
                    ref.read(audioHandlerProvider).playAll(tracksWithArt);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionBtn(
                  icon: FluentIcons.arrow_sync_24_filled,
                  label: 'Shuffle',
                  onTap: () {
                    final shuffled = List<MuzoItem>.from(tracksWithArt)..shuffle();
                    ref.read(audioHandlerProvider).playAll(shuffled);
                  },
                ),
              ),
              const SizedBox(width: 12),
              _buildCircleActionBtn(
                icon: allDownloaded
                    ? FluentIcons.checkmark_24_regular
                    : FluentIcons.arrow_download_24_regular,
                iconColor: allDownloaded ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface,
                onTap: () {
                  if (allDownloaded) {
                    showGlassSnackBar(context, 'All songs in this album are already downloaded.');
                    return;
                  }
                  int downloadCount = 0;
                  for (final track in tracksWithArt) {
                    if (track.videoId != null && !storage.isDownloaded(track.videoId!)) {
                      ref.read(downloadProvider.notifier).startDownload(track);
                      downloadCount++;
                    }
                  }
                  if (downloadCount > 0) {
                    showGlassSnackBar(context, 'Downloading $downloadCount songs from album...');
                  } else {
                    showGlassSnackBar(context, 'All songs in this album are already downloaded.');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final btnBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05);
        final btnBorder = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
        final btnContentColor = Theme.of(context).colorScheme.onSurface;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: btnBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: btnBorder,
                  width: 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: btnContentColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            color: btnContentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildCircleActionBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final btnBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05);
        final btnBorder = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
        final btnContentColor = Theme.of(context).colorScheme.onSurface;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: btnBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: btnBorder,
                  width: 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap,
                  child: Center(
                    child: Icon(
                      icon,
                      color: iconColor ?? btnContentColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildTrackTile(MuzoItem song, int index, AlbumDetails album, Map<String, double> progressMap) {
    final progress = progressMap[song.videoId];
    final isDownloading = progress != null;

    Widget? subtitleWidget;
    if (isDownloading) {
      subtitleWidget = Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
            minHeight: 3,
          ),
        ),
      );
    } else if (song.displayArtist.toLowerCase() != album.artist.toLowerCase() && song.displayArtist != 'Unknown') {
      subtitleWidget = Text(
        song.displayArtist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      leading: Container(
        width: 28,
        alignment: Alignment.center,
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (song.isExplicit) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'E',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: subtitleWidget,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (song.duration != null)
            Text(
              song.duration!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
          const SizedBox(width: 10),
          IconButton(
            icon: Icon(
              FluentIcons.more_horizontal_24_regular,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () {
              SongOptionsMenu.show(ref, song);
            },
          ),
        ],
      ),
      onTap: () {
        final songWithArt =
            song.thumbnails.isEmpty && album.thumbnail.isNotEmpty
            ? song.copyWith(
                thumbnails: [
                  MuzoThumbnail(url: album.thumbnail, width: 500, height: 500),
                ],
              )
            : song;
        ref.read(audioHandlerProvider).playVideo(songWithArt);
      },
      onLongPress: () {
        SongOptionsMenu.show(ref, song);
      },
    );
  }
}

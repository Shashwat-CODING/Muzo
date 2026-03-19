import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/models/album_details.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/services/muzo_api_service.dart';

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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              // Content
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // App Bar (Hidden initially)
                  SliverAppBar(
                    backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white).withValues(alpha: 0.8),
                    pinned: true,
                    expandedHeight: 350,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      title: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _opacity,
                        child: Text(
                          album.title,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                      background: _buildHeader(album),
                    ),
                  ),

                  // Actions Row (Play / Shuffle)
                  SliverToBoxAdapter(child: _buildActions(album)),

                  // Tracks List
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final song = album.tracks[index];
                      return _buildTrackTile(song, index, album);
                    }, childCount: album.tracks.length),
                  ),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
                ],
              ),
            ],
          );
        },
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

  Widget _buildHeader(AlbumDetails album) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: album.thumbnail,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${album.artist} • ${album.year}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActions(AlbumDetails album) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                final List<MuzoItem> tracksWithArt = album.tracks
                    .map<MuzoItem>((track) {
                      // Ensure thumbnail is set, fallback to album thumbnail
                      if (track.thumbnails.isEmpty &&
                          album.thumbnail.isNotEmpty) {
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
                    })
                    .toList();
                ref.read(audioHandlerProvider).playAll(tracksWithArt);
              },
              icon: const Icon(FluentIcons.play_24_filled, color: Colors.black),
              label: Text(
                "Play",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              FluentIcons.arrow_download_24_regular,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              // Future: Download album
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(MuzoItem song, int index, AlbumDetails album) {
    return ListTile(
      leading: Text(
        '${index + 1}',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      subtitle: Text(
        album.artist,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
      ),
      trailing: Text(
        song.duration ?? '',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
      ),
      onTap: () {
        // Play single song - don't queue entire album
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/models/album_details.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/services/ytify_service.dart';

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
    _albumFuture = YtifyApiService().getAlbumDetails(widget.albumId);
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
      backgroundColor: Colors.transparent,
      body: FutureBuilder<AlbumDetails?>(
        future: _albumFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
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
                    backgroundColor: Colors.black.withValues(alpha: 0.8),
                    pinned: true,
                    expandedHeight: 350,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      title: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _opacity,
                        child: Text(
                          album.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
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

                  const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
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
        leading: const BackButton(color: Colors.white),
      ),
      body: const Center(
        child: Text(
          "Could not load album",
          style: TextStyle(color: Colors.white),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${album.artist} • ${album.year}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
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
                final List<YtifyResult> tracksWithArt = album.tracks
                    .map<YtifyResult>((track) {
                      // Ensure thumbnail is set, fallback to album thumbnail
                      if (track.thumbnails.isEmpty &&
                          album.thumbnail.isNotEmpty) {
                        return track.copyWith(
                          thumbnails: [
                            YtifyThumbnail(
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
              label: const Text(
                "Play",
                style: TextStyle(
                  color: Colors.black,
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
            icon: const Icon(
              FluentIcons.arrow_download_24_regular,
              color: Colors.white,
            ),
            onPressed: () {
              // Future: Download album
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(YtifyResult song, int index, AlbumDetails album) {
    return ListTile(
      leading: Text(
        '${index + 1}',
        style: const TextStyle(color: Colors.grey, fontSize: 14),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        album.artist,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 12,
        ),
      ),
      trailing: Text(
        song.duration ?? '',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      onTap: () {
        // Play single song - don't queue entire album
        final songWithArt =
            song.thumbnails.isEmpty && album.thumbnail.isNotEmpty
            ? song.copyWith(
                thumbnails: [
                  YtifyThumbnail(url: album.thumbnail, width: 500, height: 500),
                ],
              )
            : song;
        ref.read(audioHandlerProvider).playVideo(songWithArt);
      },
    );
  }
}

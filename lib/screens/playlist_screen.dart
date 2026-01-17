import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/artist_details.dart';
import 'package:muzo/services/ytify_service.dart';
import 'package:muzo/widgets/result_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/providers/player_provider.dart';

class PlaylistScreen extends ConsumerStatefulWidget {
  final String playlistId;
  final String? title;
  final String? thumbnailUrl;

  const PlaylistScreen({
    super.key,
    required this.playlistId,
    this.title,
    this.thumbnailUrl,
  });

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  final _apiService = YtifyApiService();
  bool _isLoading = true;
  PlaylistDetails? _playlistDetails;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await _apiService.getPlaylistDetails(widget.playlistId);
      if (details != null) {
        _playlistDetails = details;
      }
    } catch (e) {
      debugPrint('Error fetching playlist data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = _playlistDetails?.title ?? widget.title ?? 'Playlist';
    final displayThumbnail = _playlistDetails?.thumbnail ?? widget.thumbnailUrl;
    final author = _playlistDetails?.author ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 240.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(displayTitle),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (displayThumbnail != null)
                          CachedNetworkImage(
                            imageUrl: displayThumbnail,
                            fit: BoxFit.cover,
                            color: Colors.black.withOpacity(0.5),
                            colorBlendMode: BlendMode.darken,
                          )
                        else
                          Container(color: Colors.grey[900]),

                        // Gradient for better text visibility
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xFF0F0F0F)],
                              stops: [0.6, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Play All Button and Info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (author.isNotEmpty)
                          Text(
                            author,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_playlistDetails != null &&
                                  _playlistDetails!.tracks.isNotEmpty) {
                                ref
                                    .read(audioHandlerProvider)
                                    .playAll(_playlistDetails!.tracks);
                              }
                            },
                            icon: const Icon(
                              FluentIcons.play_24_filled,
                              color: Colors.black,
                            ),
                            label: const Text(
                              'Play All',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_playlistDetails != null &&
                    _playlistDetails!.tracks.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final track = _playlistDetails!.tracks[index];
                      return ResultTile(result: track);
                    }, childCount: _playlistDetails!.tracks.length),
                  )
                else
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No tracks found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
              ],
            ),
    );
  }
}

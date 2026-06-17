import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/artist_details.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/widgets/result_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/widgets/global_background.dart';

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
  late final _apiService = ref.read(muzoApiServiceProvider);
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

    return GlobalBackground(
      child: Scaffold(
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
                      title: Text(
                        displayTitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (displayThumbnail != null)
                            CachedNetworkImage(
                              imageUrl: displayThumbnail,
                              fit: BoxFit.cover,
                              color: Colors.black.withValues(alpha: 0),
                              colorBlendMode: BlendMode.darken,
                            )
                          else
                            Container(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
  
                          // Gradient for better text visibility
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                                  Theme.of(context).scaffoldBackgroundColor,
                                ],
                                stops: const [0.6, 0.9, 1.0],
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
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
                            ),
                          const SizedBox(height: 16),
                          Builder(
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
                                    width: double.infinity,
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
                                        onTap: () {
                                          if (_playlistDetails != null &&
                                              _playlistDetails!.tracks.isNotEmpty) {
                                            ref
                                                .read(audioHandlerProvider)
                                                .playAll(_playlistDetails!.tracks);
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                FluentIcons.play_24_filled,
                                                color: btnContentColor,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Play All',
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
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No tracks found',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ),
                      ),
                    ),
  
                  const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
                ],
              ),
      ),
    );
  }
}

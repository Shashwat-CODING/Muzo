import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/artist_details.dart';
import 'package:muzo/services/ytify_service.dart';
import 'package:muzo/widgets/result_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/screens/playlist_screen.dart';

class ArtistScreen extends ConsumerStatefulWidget {
  final String browseId;
  final String? artistName;
  final String? thumbnailUrl;

  const ArtistScreen({
    super.key,
    required this.browseId,
    this.artistName,
    this.thumbnailUrl,
  });

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  final _apiService = YtifyApiService();
  bool _isLoading = true;
  ArtistDetails? _artistDetails;
  PlaylistDetails? _topSongsPlaylist;

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
      final artistDetails = await _apiService.getArtistDetails(widget.browseId);
      if (artistDetails != null) {
        _artistDetails = artistDetails;

        if (artistDetails.playlistId.isNotEmpty) {
          final playlistDetails = await _apiService.getPlaylistDetails(
            artistDetails.playlistId,
          );
          _topSongsPlaylist = playlistDetails;
        }
      }
    } catch (e) {
      debugPrint('Error fetching artist data: $e');
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
    // Use passed name/thumbnail as fallback or initial data
    final displayName =
        _artistDetails?.artistName ?? widget.artistName ?? 'Artist';
    // We don't have a direct artist thumbnail in ArtistDetails (it's in recommended),
    // so we might rely on what was passed or maybe the first recommended artist if it's the same?
    // Actually, usually artist details would have a header image, but the API response
    // provided in the prompt doesn't seem to have a top-level thumbnail for the artist itself,
    // only for recommended artists and playlists.
    // However, the playlist thumbnail (Top Songs) often features the artist.
    final displayThumbnail =
        widget.thumbnailUrl ?? _topSongsPlaylist?.thumbnail;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 340.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: const Color(0xFF121212),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (displayThumbnail != null)
                          CachedNetworkImage(
                            imageUrl: displayThumbnail.replaceAll(
                              RegExp(r'=[sw]\d+(-h\d+)?'),
                              '=s800',
                            ),
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(color: Colors.grey[900]),
                          )
                        else
                          Container(color: Colors.grey[900]),

                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                              stops: [0.6, 1.0],
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: 24,
                          left: 20,
                          right: 20,
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_artistDetails?.featuredOnPlaylists.isNotEmpty ??
                    false) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Text(
                        'Featured On',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _artistDetails!.featuredOnPlaylists.length,
                        itemBuilder: (context, index) {
                          final playlist =
                              _artistDetails!.featuredOnPlaylists[index];
                          return _buildFeaturedCard(playlist);
                        },
                      ),
                    ),
                  ),
                ],
                if (_artistDetails?.recommendedArtists.isNotEmpty ?? false) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Text(
                        'Fans Also Like',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _artistDetails!.recommendedArtists.length,
                        itemBuilder: (context, index) {
                          final artist =
                              _artistDetails!.recommendedArtists[index];
                          return _buildArtistCard(artist);
                        },
                      ),
                    ),
                  ),
                ],
                if (_topSongsPlaylist != null &&
                    _topSongsPlaylist!.tracks.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Top Songs',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final track = _topSongsPlaylist!.tracks[index];
                      return ResultTile(result: track);
                    }, childCount: _topSongsPlaylist!.tracks.length),
                  ),
                ],
                const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
              ],
            ),
    );
  }

  Widget _buildFeaturedCard(FeaturedPlaylist playlist) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistScreen(
              playlistId: playlist.browseId,
              title: playlist.title,
              thumbnailUrl: playlist.thumbnail,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: playlist.thumbnail.replaceAll(
                    RegExp(r'=[sw]\d+(-h\d+)?'),
                    '=s800',
                  ),
                  height: 140,
                  fit: BoxFit.fitHeight,
                  placeholder: (context, url) => Container(
                    height: 140,
                    width: 140,
                    color: Colors.grey[900],
                    child: const Icon(
                      FluentIcons.music_note_2_24_regular,
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 140,
                    width: 140,
                    color: Colors.grey[900],
                    child: const Icon(
                      FluentIcons.music_note_2_24_regular,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                playlist.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistCard(RecommendedArtist artist) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistScreen(
              browseId: artist.browseId,
              artistName: artist.name,
              thumbnailUrl: artist.thumbnail,
            ),
          ),
        );
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: artist.thumbnail.replaceAll(
                  RegExp(r'=[sw]\d+(-h\d+)?'),
                  '=s800',
                ),
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[900],
                  child: const Icon(
                    FluentIcons.person_24_regular,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

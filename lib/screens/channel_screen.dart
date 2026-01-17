import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/services/youtube_api_service.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/result_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/providers/player_provider.dart';

class ChannelScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String? title;
  final String? thumbnailUrl;
  final String? subscriberCount;
  final String? videoCount;
  final String? description;

  const ChannelScreen({
    super.key,
    required this.channelId,
    this.title,
    this.thumbnailUrl,
    this.subscriberCount,
    this.videoCount,
    this.description,
  });

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  final _apiService = YouTubeApiService();
  bool _isLoading = true;
  List<YtifyResult> _videos = [];

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
      final videos = await _apiService.getChannelVideos(widget.channelId);
      if (mounted) {
        setState(() {
          _videos = videos;
        });
      }
    } catch (e) {
      debugPrint('Error fetching channel videos: $e');
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
                  backgroundColor: const Color(
                    0xFF121212,
                  ), // Match app theme or transparent
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Image
                        if (widget.thumbnailUrl != null)
                          CachedNetworkImage(
                            imageUrl: widget.thumbnailUrl!.replaceAll(
                              RegExp(r'=[sw]\d+(-h\d+)?'),
                              '=s800',
                            ),
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(color: Colors.grey[900]),
                          )
                        else
                          Container(color: Colors.grey[900]),

                        // Gradient Overlay
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

                        // Content (Name & Stats)
                        Positioned(
                          bottom: 24,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title ?? 'Unknown Artist',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.subscriberCount != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.subscriberCount} Subscribers',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Consumer(
                                builder: (context, ref, _) {
                                  final storage = ref.watch(
                                    storageServiceProvider,
                                  );
                                  return ValueListenableBuilder<
                                    List<YtifyResult>
                                  >(
                                    valueListenable:
                                        storage.subscriptionsListenable,
                                    builder: (context, subscriptions, _) {
                                      final isSubscribed = storage.isSubscribed(
                                        widget.channelId,
                                      );
                                      return SizedBox(
                                        height: 36,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            final channel = YtifyResult(
                                              title: widget.title ?? 'Unknown',
                                              thumbnails:
                                                  widget.thumbnailUrl != null
                                                  ? [
                                                      YtifyThumbnail(
                                                        url: widget
                                                            .thumbnailUrl!
                                                            .replaceAll(
                                                              RegExp(
                                                                r'=[sw]\d+(-h\d+)?',
                                                              ),
                                                              '=s800',
                                                            ),
                                                        width: 0,
                                                        height: 0,
                                                      ),
                                                    ]
                                                  : [],
                                              resultType: 'channel',
                                              isExplicit: false,
                                              browseId: widget.channelId,
                                              subscriberCount:
                                                  widget.subscriberCount,
                                              videoCount: widget.videoCount,
                                              description: widget.description,
                                            );
                                            storage.toggleSubscription(channel);
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: isSubscribed
                                                  ? Colors.grey
                                                  : Colors.white,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                            backgroundColor: isSubscribed
                                                ? Colors.transparent
                                                : Colors.transparent,
                                          ),
                                          child: Text(
                                            isSubscribed
                                                ? 'FOLLOWING'
                                                : 'FOLLOW',
                                            style: TextStyle(
                                              color: isSubscribed
                                                  ? Colors.white
                                                  : Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Popular Header & Play Button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Popular',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_videos.isNotEmpty) {
                              ref.read(audioHandlerProvider).playAll(_videos);
                            }
                          },
                          icon: const Icon(
                            FluentIcons.play_circle_24_filled,
                            color: Color(0xFF1ED760),
                            size: 40,
                          ), // Spotify Green
                        ),
                      ],
                    ),
                  ),
                ),

                // Videos List
                if (_videos.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final video = _videos[index];
                      return ResultTile(result: video);
                    }, childCount: _videos.length),
                  )
                else
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No videos found',
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

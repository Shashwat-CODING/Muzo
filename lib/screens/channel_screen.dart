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
                  expandedHeight: 280.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Image (blurred or darkened)
                        if (widget.thumbnailUrl != null)
                          Image.network(
                            widget.thumbnailUrl!,
                            fit: BoxFit.cover,
                            color: Colors.black.withOpacity(0.8),
                            colorBlendMode: BlendMode.darken,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: Colors.grey[900]),
                          )
                        else
                          Container(color: Colors.grey[900]),

                        // Content
                        SafeArea(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Channel Avatar
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: ClipOval(
                                        child: widget.thumbnailUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: widget.thumbnailUrl!,
                                                fit: BoxFit.cover,
                                                errorWidget: (context, url, error) =>
                                                    const Icon(FluentIcons.person_24_regular, size: 40, color: Colors.grey),
                                              )
                                            : const Icon(FluentIcons.person_24_regular, size: 40, color: Colors.grey),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Channel Name
                                    Text(
                                      widget.title ?? 'Unknown Channel',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    // Stats
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (widget.subscriberCount != null)
                                          Text(
                                            widget.subscriberCount!,
                                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                          ),
                                        if (widget.subscriberCount != null && widget.videoCount != null)
                                          Text(
                                            ' • ',
                                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                          ),
                                        if (widget.videoCount != null)
                                          Text(
                                            widget.videoCount!,
                                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Subscribe Button
                                    Consumer(
                                      builder: (context, ref, _) {
                                        final storage = ref.watch(storageServiceProvider);
                                        return ValueListenableBuilder<List<YtifyResult>>(
                                          valueListenable: storage.subscriptionsListenable,
                                          builder: (context, subscriptions, _) {
                                            final isSubscribed = storage.isSubscribed(widget.channelId);
                                            return SizedBox(
                                              height: 36,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  final channel = YtifyResult(
                                                    title: widget.title ?? 'Unknown',
                                                    thumbnails: widget.thumbnailUrl != null
                                                        ? [YtifyThumbnail(url: widget.thumbnailUrl!, width: 0, height: 0)]
                                                        : [],
                                                    resultType: 'channel',
                                                    isExplicit: false,
                                                    browseId: widget.channelId,
                                                    subscriberCount: widget.subscriberCount,
                                                    videoCount: widget.videoCount,
                                                    description: widget.description,
                                                  );
                                                  storage.toggleSubscription(channel);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isSubscribed ? Colors.grey[800] : Colors.white,
                                                  foregroundColor: isSubscribed ? Colors.white : Colors.black,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(18),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                                ),
                                                child: Text(
                                                  isSubscribed ? 'Subscribed' : 'Subscribe',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    if (widget.description != null && widget.description!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.description!,
                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Play All Button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_videos.isNotEmpty) {
                            ref.read(audioHandlerProvider).playAll(_videos);
                          }
                        },
                        icon: const Icon(FluentIcons.play_24_filled, color: Colors.black),
                        label: const Text('Play All', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                        ),
                      ),
                    ),
                  ),
                ),

                // Videos List
                if (_videos.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final video = _videos[index];
                        return ResultTile(result: video);
                      },
                      childCount: _videos.length,
                    ),
                  )
                else
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text('No videos found', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  ),
                  
                const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
              ],
            ),
    );
  }
}

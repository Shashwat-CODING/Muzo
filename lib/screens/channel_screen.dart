import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/models/user_data.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/result_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/widgets/global_background.dart';

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
  late final _apiService = ref.read(muzoApiServiceProvider);
  bool _isLoading = true;
  List<MuzoItem> _videos = [];

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
    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 340.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Image
                        if (widget.thumbnailUrl != null)
                          CachedNetworkImage(
                            imageUrl: widget.thumbnailUrl!,
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
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.subscriberCount != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.subscriberCount} Subscribers',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                                    List<Channel>
                                  >(
                                    valueListenable:
                                        storage.subscriptionsListenable,
                                    builder: (context, subscriptions, _) {
                                      final isSubscribed = storage.isSubscribed(
                                        widget.channelId,
                                      );
                                       return SizedBox(
                                        height: 36,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(18),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                            child: TextButton(
                                              onPressed: () {
                                                final channel = Channel(
                                                  name: widget.title ?? 'Unknown',
                                                  channelId: widget.channelId,
                                                  avatar: widget.thumbnailUrl,
                                                );
                                                storage.toggleSubscription(channel);
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: isSubscribed
                                                    ? Colors.white
                                                    : Colors.white.withValues(alpha: 0.08),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(18),
                                                  side: BorderSide(
                                                    color: isSubscribed
                                                        ? Colors.transparent
                                                        : Colors.white.withValues(alpha: 0.15),
                                                    width: 1.0,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                isSubscribed ? 'FOLLOWING' : 'FOLLOW',
                                                style: TextStyle(
                                                  color: isSubscribed ? Colors.black : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
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
                        Text(
                          'Popular',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No videos found',
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

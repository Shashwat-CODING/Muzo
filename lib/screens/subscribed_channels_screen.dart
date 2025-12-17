import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/youtube_api_service.dart';
import 'package:muzo/screens/channel_screen.dart';
import 'package:muzo/widgets/result_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/models/ytify_result.dart';

class SubscribedChannelsScreen extends ConsumerStatefulWidget {
  const SubscribedChannelsScreen({super.key});

  @override
  ConsumerState<SubscribedChannelsScreen> createState() => _SubscribedChannelsScreenState();
}

class _SubscribedChannelsScreenState extends ConsumerState<SubscribedChannelsScreen> {
  final _apiService = YouTubeApiService();
  Future<List<YtifyResult>>? _feedFuture;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  void _loadFeed() {
    final storage = ref.read(storageServiceProvider);
    final subscriptions = storage.getSubscriptions();
    if (subscriptions.isNotEmpty) {
      final channelIds = subscriptions.map((c) => c.browseId!).toList();
      _feedFuture = _apiService.getSubscriptionsFeed(channelIds);
    } else {
      _feedFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ValueListenableBuilder<List<YtifyResult>>(
          valueListenable: storage.subscriptionsListenable,
          builder: (context, subscriptions, _) {
            final subscriptions = storage.getSubscriptions();

            if (subscriptions.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.video_24_regular, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No subscriptions yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            // Reload feed if subscriptions changed (simple check: count)
            // Ideally we should check if IDs changed, but for now this is okay-ish
            // Or we can rely on pull-to-refresh.
            // Let's just keep the initial load for now to avoid loops.

            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Subscriptions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Horizontal list of channels
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: subscriptions.length,
                      itemBuilder: (context, index) {
                        final channel = subscriptions[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChannelScreen(
                                    channelId: channel.browseId!,
                                    title: channel.title,
                                    thumbnailUrl: channel.thumbnails.lastOrNull?.url,
                                    subscriberCount: channel.subscriberCount,
                                    videoCount: channel.videoCount,
                                    description: channel.description,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                                  ),
                                  child: ClipOval(
                                    child: channel.thumbnails.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: channel.thumbnails.last.url,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, url, error) =>
                                                const Icon(FluentIcons.person_24_regular, color: Colors.grey),
                                          )
                                        : const Icon(FluentIcons.person_24_regular, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    channel.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Latest',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Feed List
                FutureBuilder<List<YtifyResult>>(
                  future: _feedFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red))),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Center(child: Text('No recent videos', style: TextStyle(color: Colors.grey))),
                      );
                    }

                    final videos = snapshot.data!;
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return ResultTile(result: videos[index]);
                        },
                        childCount: videos.length,
                      ),
                    );
                  },
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            );
          },
        ),
      ),
    );
  }
}

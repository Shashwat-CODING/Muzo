import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/screens/channel_screen.dart';
import 'package:muzo/widgets/result_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/models/user_data.dart';

class SubscribedChannelsScreen extends ConsumerStatefulWidget {
  const SubscribedChannelsScreen({super.key});

  @override
  ConsumerState<SubscribedChannelsScreen> createState() =>
      _SubscribedChannelsScreenState();
}

class _SubscribedChannelsScreenState
    extends ConsumerState<SubscribedChannelsScreen> {
  late final _apiService = ref.read(muzoApiServiceProvider);
  late final StorageService _storage;
  Future<List<MuzoItem>>? _feedFuture;

  @override
  void initState() {
    super.initState();
    _storage = ref.read(storageServiceProvider);
    _storage.subscriptionsListenable.addListener(_onSubscriptionsChanged);
    _loadFeed();
  }

  @override
  void dispose() {
    _storage.subscriptionsListenable.removeListener(_onSubscriptionsChanged);
    super.dispose();
  }

  void _onSubscriptionsChanged() {
    _loadFeed();
    if (mounted) setState(() {});
  }

  void _loadFeed() {
    final storage = ref.read(storageServiceProvider);
    final subscriptions = storage.getSubscriptions();
    if (subscriptions.isNotEmpty) {
      // Prefer channelId, fall back to name for lookup
      final channelIds = subscriptions
          .where((c) => c.channelId != null)
          .map((c) => c.channelId!)
          .toList();
      if (channelIds.isNotEmpty) {
        _feedFuture = _apiService.getSubscriptionsFeed(channelIds);
      } else {
        _feedFuture = Future.value([]);
      }
    } else {
      _feedFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final subscriptions = storage.getSubscriptions();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: subscriptions.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FluentIcons.video_24_regular,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No subscriptions yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Subscriptions',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                                if (channel.channelId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChannelScreen(
                                        channelId: channel.channelId!,
                                        title: channel.name,
                                        thumbnailUrl: channel.avatar,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Column(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: channel.avatar != null
                                          ? CachedNetworkImage(
                                              imageUrl: channel.avatar!,
                                              fit: BoxFit.cover,
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const Icon(
                                                        FluentIcons
                                                            .person_24_regular,
                                                        color: Colors.grey,
                                                      ),
                                            )
                                          : const Icon(
                                              FluentIcons.person_24_regular,
                                              color: Colors.grey,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      channel.name,
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Latest',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ),
                  // Feed List
                  FutureBuilder<List<MuzoItem>>(
                    future: _feedFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      } else if (snapshot.hasError) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Center(
                            child: Text(
                              'No recent videos',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      final videos = snapshot.data!;
                      return SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return ResultTile(result: videos[index]);
                        }, childCount: videos.length),
                      );
                    },
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
                ],
              ),
      ),
    );
  }
}

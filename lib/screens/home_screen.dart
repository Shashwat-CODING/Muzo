import 'package:ytx/widgets/glass_menu_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytx/providers/navigation_provider.dart';
import 'package:ytx/providers/explore_provider.dart';
import 'package:ytx/screens/search_screen.dart';
import 'package:ytx/widgets/result_tile.dart';
import 'package:ytx/screens/library_screen.dart';
import 'package:ytx/screens/subscribed_channels_screen.dart';
import 'package:ytx/widgets/horizontal_result_card.dart';
import 'package:ytx/models/ytify_result.dart';
import 'package:ytx/services/storage_service.dart';
import 'package:ytx/providers/player_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ytx/screens/artist_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ytx/screens/settings_screen.dart';
import 'package:ytx/widgets/glass_container.dart';
import 'package:ytx/widgets/offline_indicator.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger initial data load after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      storage.refreshAll();
      storage.fetchAndCacheUserAvatar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: selectedIndex,
        children: [
          _buildExploreTab(context, ref),
          const SearchScreen(),
          const LibraryScreen(),
          const SubscribedChannelsScreen(),
          // Placeholder for Settings (index 4)
          const SizedBox.shrink(), 
          const SizedBox.shrink(), // Placeholder for About (index 5)
        ],
      ),
    );
  }

  Widget _buildExploreTab(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Colors.white,
        backgroundColor: const Color(0xFF1E1E1E),
        onRefresh: () async {
          await storage.refreshAll();
        },
        child: CustomScrollView(
          slivers: [
            // Greeting Section
            SliverToBoxAdapter(
              child: _buildGreeting(context, ref),
            ),

            // Speed Dial Section
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OfflineIndicator(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.history, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Speed dial',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                        ),
                        const Spacer(),
                        // const Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            
            _buildSpeedDial(context, ref),

            // Favorites Section
            SliverToBoxAdapter(
              child: _buildFavoritesSection(context, ref),
            ),

            // Artists Section
            SliverToBoxAdapter(
              child: _buildArtistsSection(context, ref),
            ),
            
            const SliverPadding(padding: EdgeInsets.only(bottom: 200)),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    final username = storage.username ?? 'User';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              Text(
                username,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
            icon: const Icon(Icons.search, color: Colors.white),
          ),
          const SizedBox(width: 8),


// ... (existing imports)

          PopupMenuButton<String>(
            onOpened: () => HapticFeedback.lightImpact(),
            offset: const Offset(0, 50),
            color: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: GlassMenuContent(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: const Icon(Icons.person, color: Colors.white, size: 20),
                      title: const Text('Account Info', style: TextStyle(color: Colors.white, fontSize: 14)),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                            content: GlassContainer(
                              blur: 15,
                              opacity: 0.2,
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(24),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Account Info',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Username: $username', style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 24),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: const Icon(Icons.settings, color: Colors.white, size: 20),
                      title: const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 14)),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            child: ClipOval(
              child: ValueListenableBuilder(
                valueListenable: storage.userAvatarListenable,
                builder: (context, box, _) {
                  final cachedSvg = storage.getUserAvatar();
                  if (cachedSvg != null) {
                    return SvgPicture.string(
                      cachedSvg,
                      height: 32,
                      width: 32,
                      placeholderBuilder: (BuildContext context) => Container(
                        padding: const EdgeInsets.all(10.0),
                        child: const CircularProgressIndicator(),
                      ),
                    );
                  }
                  return SvgPicture.network(
                    'https://api.dicebear.com/9.x/rings/svg?seed=$username',
                    height: 32,
                    width: 32,
                    placeholderBuilder: (BuildContext context) => Container(
                      padding: const EdgeInsets.all(10.0),
                      child: const CircularProgressIndicator(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDial(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    return ValueListenableBuilder<List<YtifyResult>>(
      valueListenable: storage.historyListenable,
      builder: (context, history, _) {
        // Filter for songs only, remove duplicates, and take top 8
        final uniqueHistory = <String>{};
        final speedDialItems = history
            .where((item) => item.resultType != 'video')
            .where((item) => uniqueHistory.add(item.videoId!))
            .take(8)
            .toList();

        if (speedDialItems.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Play some music to see it here!', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8.0,
              crossAxisSpacing: 8.0,
              childAspectRatio: 1.0, // Square items
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < speedDialItems.length) {
                  final item = speedDialItems[index];
                  return GestureDetector(
                    onTap: () {
                       HapticFeedback.lightImpact();
                       ref.read(audioHandlerProvider).playVideo(item);
                    },
                    child: _buildSpeedDialItem(context, ref, item),
                  );
                } else {
                  // Library Item (9th item or last item)
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(navigationIndexProvider.notifier).state = 2; // Switch to Library tab
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: const DecorationImage(
                          image: CachedNetworkImageProvider('https://cdn.dribbble.com/userupload/5195818/file/original-192782f93efd6f758f26c5a471163ecc.jpg?resize=752x752&vertical=center'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }
              },
              childCount: speedDialItems.length + 1,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeedDialItem(BuildContext context, WidgetRef ref, YtifyResult item) {
     final imageUrl = item.thumbnails.isNotEmpty ? item.thumbnails.last.url : '';
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Expanded(
           child: Container(
             decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(12),
               color: Colors.grey[900],
               boxShadow: [
                 BoxShadow(
                   color: Colors.black.withOpacity(0.0),
                   blurRadius: 8,
                   offset: const Offset(0, 4),
                 ),
               ],
               image: imageUrl.isNotEmpty
                   ? DecorationImage(
                       image: CachedNetworkImageProvider(imageUrl),
                       fit: BoxFit.cover,
                     )
                   : null,
             ),
             child: Stack(
               children: [
                 Positioned.fill(
                   child: Container(
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(12),
                       gradient: LinearGradient(
                         begin: Alignment.topCenter,
                         end: Alignment.bottomCenter,
                         colors: [
                           Colors.transparent,
                           Colors.black.withOpacity(0.8),
                         ],
                         stops: const [0.6, 1.0],
                       ),
                     ),
                   ),
                 ),
                 Positioned(
                   bottom: 8,
                   left: 8,
                   right: 8,
                   child: Text(
                     item.title,
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                     style: const TextStyle(
                       color: Colors.white,
                       fontWeight: FontWeight.bold,
                       fontSize: 12,
                       shadows: [
                         Shadow(
                           color: Colors.black,
                           blurRadius: 4,
                           offset: Offset(0, 2),
                         ),
                       ],
                     ),
                     textAlign: TextAlign.left,
                   ),
                 ),
               ],
             ),
           ),
         ),
       ],
     );
  }

  Widget _buildFavoritesSection(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    return ValueListenableBuilder<List<YtifyResult>>(
      valueListenable: storage.favoritesListenable,
      builder: (context, favorites, _) {
        if (favorites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Favorites',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final item = favorites[index];
                  final imageUrl = item.thumbnails.isNotEmpty ? item.thumbnails.last.url : '';
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(audioHandlerProvider).playVideo(item);
                      },
                      child: SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageUrl.isNotEmpty 
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    height: 120,
                                    width: 120,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Container(
                                      height: 120,
                                      width: 120,
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.music_note, color: Colors.white),
                                    ),
                                  )
                                : Container(
                                    height: 120,
                                    width: 120,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.music_note, color: Colors.white),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArtistsSection(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    
    final history = storage.getHistory();
    final favorites = storage.getFavorites();
    
    final uniqueArtists = <String, YtifyArtist>{};
    final seenNames = <String>{};

    for (var item in [...favorites, ...history]) {
      if (item.artists != null) {
        for (var artist in item.artists!) {
          if (artist.id != null && artist.name.isNotEmpty) {
             if (!uniqueArtists.containsKey(artist.id) && !seenNames.contains(artist.name)) {
               uniqueArtists[artist.id!] = artist;
               seenNames.add(artist.name);
             }
          }
        }
      }
    }
    
    final artistList = uniqueArtists.values.toList();

    if (artistList.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder(
      valueListenable: storage.artistImagesListenable,
      builder: (context, box, _) {
        final validArtists = artistList.where((artist) {
          final img = storage.getArtistImage(artist.id!);
          return img != 'INVALID_ARTIST';
        }).toList();

        if (validArtists.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Artists',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: validArtists.length,
                itemBuilder: (context, index) {
                  final artist = validArtists[index];
                  final cachedImage = storage.getArtistImage(artist.id!);
                  
                  if (cachedImage == null) {
                    // Trigger fetch in background
                    storage.fetchAndCacheArtistImage(artist.id!);
                  }

                  final imageUrl = cachedImage ?? '';

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (artist.id != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArtistScreen(
                              browseId: artist.id!,
                              artistName: artist.name,
                              thumbnailUrl: imageUrl,
                            ),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
                            child: imageUrl.isEmpty 
                                ? Text(
                                    artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 32),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            artist.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

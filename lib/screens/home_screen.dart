import 'package:muzo/widgets/glass_menu_content.dart';
import 'package:muzo/widgets/fade_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/navigation_provider.dart';
import 'package:muzo/screens/search_screen.dart';
import 'package:muzo/screens/library_screen.dart';
import 'package:muzo/screens/subscribed_channels_screen.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:muzo/screens/settings_screen.dart';
import 'package:muzo/widgets/glass_container.dart';
import 'package:muzo/services/update_service.dart';
import 'package:muzo/providers/home_provider.dart';
import 'package:muzo/widgets/home_section_widget.dart';
import 'package:muzo/widgets/rect_home_item.dart';
import 'package:muzo/widgets/home_item_widget.dart';
import 'package:muzo/services/ytm_home.dart';
import 'package:muzo/widgets/skeleton_loader.dart';


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
      storage.refreshAll(silent: true);
      storage.fetchAndCacheUserAvatar();
      UpdateService().checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: FadeIndexedStack(
          index: selectedIndex,
          children: [
            _buildExploreTab(context, ref),
            const SearchScreen(),
            const LibraryScreen(),
            const SubscribedChannelsScreen(),
            const SettingsScreen(), // Added Settings Tab
            const SizedBox.shrink(), // Placeholder for Sync Dialog
          ],
        ),
      ),
    );
  }

  Widget _buildExploreTab(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final homeSectionsAsync = ref.watch(filteredHomeSectionsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Theme.of(context).colorScheme.onSurface,
        backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white),
        onRefresh: () async {
          await ref.read(homeSectionsProvider.notifier).refresh();
          await storage.refreshAll();
        },
        child: CustomScrollView(
          slivers: [
            // Header Section
            SliverToBoxAdapter(child: _buildHeader(context, ref, isDesktop)),

            // Filter chips row
            SliverToBoxAdapter(
              child: _buildFilterChipsRow(context, ref, isDesktop),
            ),

            // "Speed dial" big label
            if (ref.watch(storageServiceProvider).historyListenable.value.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 20, 16, 10),
                  child: Row(
                    children: [
                      Icon(FluentIcons.flash_24_filled, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Speed Dial',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Speed dial grid — constrained on desktop
            _buildRecentsGrid(context, ref, isDesktop),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Dynamic Sections from YTM
            homeSectionsAsync.when(
              data: (sections) {
                if (sections.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          "No content available",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return HomeSectionWidget(section: sections[index]);
                  }, childCount: sections.length),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 20.0),
                  child: HomeSkeletonList(),
                ),
              ),
              error: (err, stack) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Error loading home: $err',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ),

            // Favorites Section
            _buildFavoritesSection(context, ref),

            // Your Playlists Section (At Bottom)
            _buildYourPlaylistsSection(context, ref),

            const SliverPadding(padding: EdgeInsets.only(bottom: 200)),
          ],
        ),
      ),
    );
  }



  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isDesktop) {
    final storage = ref.watch(storageServiceProvider);
    final username = storage.username ?? 'User';
    final hPad = isDesktop ? 24.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, isDesktop ? 28 : 20, hPad, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo + Muzo title
          Row(
            children: [
              Image.asset(
                'assets/logo.png',
                height: isDesktop ? 34 : 28,
                width: isDesktop ? 34 : 28,
              ),
              const SizedBox(width: 10),
              Text(
                'Muzo',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: isDesktop ? 26 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          // Avatar with popup menu
          PopupMenuButton<String>(
            onOpened: () => HapticFeedback.lightImpact(),
            offset: const Offset(0, 50),
            color: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: GlassMenuContent(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: Icon(FluentIcons.person_24_filled, color: Theme.of(context).colorScheme.onSurface, size: 20),
                      title: Text('Account Info', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
                              color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white),
                              borderRadius: BorderRadius.circular(24),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Account Info', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                  const SizedBox(height: 16),
                                  Text('Username: $username', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                  const SizedBox(height: 24),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
                      leading: Icon(FluentIcons.settings_24_filled, color: Theme.of(context).colorScheme.onSurface, size: 20),
                      title: Text('Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
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
                    return SvgPicture.string(cachedSvg,
                        height: isDesktop ? 40 : 32, width: isDesktop ? 40 : 32,
                        placeholderBuilder: (context) => Container(
                            padding: const EdgeInsets.all(10),
                            child: const CircularProgressIndicator()));
                  }
                  return SvgPicture.network(
                    'https://api.dicebear.com/9.x/rings/svg?seed=$username',
                    height: isDesktop ? 40 : 32, width: isDesktop ? 40 : 32,
                    placeholderBuilder: (context) => Container(
                        padding: const EdgeInsets.all(10),
                        child: const CircularProgressIndicator()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipsRow(BuildContext context, WidgetRef ref, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 12, isDesktop ? 24 : 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', 'Songs', 'Podcasts', 'Albums', 'Playlists']
              .map((label) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(context, ref, label),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, WidgetRef ref, String label) {
    final currentFilter = ref.watch(homeFilterProvider);
    final isSelected = label == currentFilter;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? Colors.transparent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            ref.read(homeFilterProvider.notifier).state = label;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentsGrid(BuildContext context, WidgetRef ref, bool isDesktop) {
    final storage = ref.watch(storageServiceProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine responsive grid parameters
    int crossAxisCount;
    double hPad;
    if (screenWidth >= 1200) {
      crossAxisCount = 6;
      hPad = 24;
    } else if (screenWidth >= 800) {
      crossAxisCount = 4;
      hPad = 24;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
      hPad = 20;
    } else {
      crossAxisCount = 3;
      hPad = 16;
    }

    return ValueListenableBuilder<List<YtifyResult>>(
      valueListenable: storage.historyListenable,
      builder: (context, history, _) {
        if (history.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        // Deduplicate history items by videoId
        final uniqueItems = <String, YtifyResult>{};
        for (var item in history) {
          if (item.videoId != null && !uniqueItems.containsKey(item.videoId)) {
            if (item.resultType != 'video') {
              uniqueItems[item.videoId!] = item;
            }
          }
        }

        final recentItems = uniqueItems.values.take(isDesktop ? 12 : 9).toList();

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 0.0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.0,
              mainAxisSpacing: isDesktop ? 8.0 : 4.0,
              crossAxisSpacing: isDesktop ? 8.0 : 4.0,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return RectHomeItem(item: recentItems[index]);
            }, childCount: recentItems.length),
          ),
        );
      },
    );
  }

  Widget _buildYourPlaylistsSection(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    return SliverToBoxAdapter(
      child: ValueListenableBuilder<Map<String, List<YtifyResult>>>(
        valueListenable: storage.playlistsListenable,
        builder: (context, playlists, _) {
          if (playlists.isEmpty) return const SizedBox.shrink();

          final playlistNames = playlists.keys.toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Text(
                  "Your Playlists",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: playlistNames.length,
                  itemBuilder: (context, index) {
                    final name = playlistNames[index];
                    final songs = playlists[name] ?? [];
                    final firstSong = songs.isNotEmpty ? songs.first : null;
                    final imageUrl = firstSong?.thumbnails.isNotEmpty == true
                        ? firstSong!.thumbnails.last.url
                        : '';

                    final homeItem = HomeItem(
                      title: name,
                      subtitle: '${songs.length} songs',
                      thumbnails: imageUrl.isNotEmpty
                          ? [
                              {'url': imageUrl, 'width': 500, 'height': 500},
                            ]
                          : [],
                      type: 'playlist',
                      playlistId: name,
                    );

                    return HomeItemWidget(item: homeItem);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFavoritesSection(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    return SliverToBoxAdapter(
      child: ValueListenableBuilder<List<YtifyResult>>(
        valueListenable: storage.favoritesListenable,
        builder: (context, favorites, _) {
          if (favorites.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Text(
                  "Favorites",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final item = favorites[index];
                    final imageUrl = item.thumbnails.isNotEmpty ? item.thumbnails.last.url : '';
                    final homeItem = HomeItem(
                      title: item.title,
                      subtitle: (item.artists != null && item.artists!.isNotEmpty) ? item.artists!.first.name : 'Unknown Artist',
                      thumbnails: imageUrl.isNotEmpty ? [{'url': imageUrl, 'width': 500, 'height': 500}] : [],
                      type: item.resultType == 'song' ? 'song' : 'video',
                      videoId: item.videoId,
                    );
                    return HomeItemWidget(item: homeItem);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

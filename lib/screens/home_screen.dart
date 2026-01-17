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
      body: FadeIndexedStack(
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

    final homeSectionsAsync = ref.watch(filteredHomeSectionsProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Colors.white,
        backgroundColor: const Color(0xFF1E1E1E),
        onRefresh: () async {
          // Force refresh (bypass cache)
          await ref.read(homeSectionsProvider.notifier).refresh();
          await storage.refreshAll();
        },
        child: CustomScrollView(
          slivers: [
            // Header Section
            SliverToBoxAdapter(child: _buildHeader(context, ref)),

            // Recents Grid
            _buildRecentsGrid(context, ref),

            // Your Playlists Section
            // Moved to bottom as per request
            // _buildYourPlaylistsSection(context, ref),

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

            // Your Playlists Section (At Bottom)
            _buildYourPlaylistsSection(context, ref),

            const SliverPadding(padding: EdgeInsets.only(bottom: 200)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final username = storage.username ?? 'User';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Row(
        children: [
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: const Icon(
                        FluentIcons.person_24_regular,
                        color: Colors.white,
                        size: 20,
                      ),
                      title: const Text(
                        'Account Info',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
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
                                  Text(
                                    'Username: $username',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: const Icon(
                        FluentIcons.settings_24_regular,
                        color: Colors.white,
                        size: 20,
                      ),
                      title: const Text(
                        'Settings',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
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
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(context, ref, 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, ref, 'Songs'),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, ref, 'Albums'),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, ref, 'Playlists'),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, WidgetRef ref, String label) {
    final currentFilter = ref.watch(homeFilterProvider);
    final isSelected = label == currentFilter;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.transparent, width: 0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ref.read(homeFilterProvider.notifier).state = label;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentsGrid(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
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
            // Only show songs, exclude videos
            if (item.resultType != 'video') {
              uniqueItems[item.videoId!] = item;
            }
          }
        }

        // Take top 6 unique items
        final recentItems = uniqueItems.values.take(6).toList();

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisExtent: 60,
              mainAxisSpacing: 8.0,
              crossAxisSpacing: 8.0,
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
                    color: Colors.white,
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

                    // Construct a YtifyResult-like object or just use HomeItemWidget if adaptable
                    // HomeItemWidget takes HomeItem. Let's make a HomeItem.
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
}

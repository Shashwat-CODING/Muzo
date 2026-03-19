import 'dart:ui';
import 'package:muzo/screens/profile_screen.dart';
import 'package:muzo/screens/search_screen.dart';
import 'package:muzo/widgets/glass_menu_content.dart';
import 'package:muzo/widgets/fade_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/navigation_provider.dart';
import 'package:muzo/providers/search_provider.dart';
import 'package:muzo/screens/library_screen.dart';
import 'package:muzo/screens/subscribed_channels_screen.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/models/user_data.dart';
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
import 'package:cached_network_image/cached_network_image.dart';


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
      _checkAndShowSpotifyAnnouncement();
    });
  }

  void _checkAndShowSpotifyAnnouncement() async {
    final storage = ref.read(storageServiceProvider);
    if (!storage.hasSeenSpotifyAnnouncement) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => _buildSpotifyAnnouncementDialog(context, storage),
      );
    }
  }

  Widget _buildSpotifyAnnouncementDialog(BuildContext context, StorageService storage) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final spotifyGreen = const Color(0xFF1DB954);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181A).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 15),
              )
            ],
          ),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: spotifyGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FluentIcons.music_note_2_24_filled,
                  color: spotifyGreen,
                  size: 56,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Spotify Import',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Easily bring your favorite Spotify playlists to Muzo. Head over to the Library to get started!',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    storage.setHasSeenSpotifyAnnouncement(true);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: spotifyGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Awesome', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    storage.setHasSeenSpotifyAnnouncement(true);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  child: const Text('Dismiss', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          await ref.read(storageServiceProvider).refreshAll();
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
            if (ref.read(storageServiceProvider).historyListenable.value.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 24, 16, 16),
                  child: Text(
                    'Recents',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

            // Speed dial grid — constrained on desktop
            _buildRecentsGrid(context, ref, isDesktop),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Dynamic Sections from YTM
            if (ref.watch(storageServiceProvider).showYtmHome)
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
      padding: EdgeInsets.fromLTRB(hPad, isDesktop ? 28 : 16, hPad, 4),
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

              // Search Button + Avatar
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      FluentIcons.search_24_regular,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: isDesktop ? 28 : 24,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
                    },
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onOpened: () => HapticFeedback.lightImpact(),
                    offset: const Offset(0, 50),
                    color: Colors.transparent,
                    elevation: 0,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        enabled: false,
                        padding: EdgeInsets.zero,
                        child: GlassMenuContent(
                          width: 260,
                          children: [
                            // Profile header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Row(
                                children: [
                                  // Small avatar in menu
                                  ClipOval(
                                    child: Builder(
                                      builder: (context) {
                                        final avatarUrl = storage.avatarUrl;
                                        final cachedSvg = storage.getUserAvatar();
                                        final isSvg = avatarUrl == null ||
                                            avatarUrl.contains('.svg') ||
                                            avatarUrl.contains('dicebear');
                                        if (isSvg && cachedSvg != null) {
                                          return SvgPicture.string(cachedSvg, height: 36, width: 36, fit: BoxFit.cover);
                                        }
                                        if (avatarUrl != null && !isSvg) {
                                          return CachedNetworkImage(
                                            imageUrl: avatarUrl,
                                            height: 36, width: 36, fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Icon(FluentIcons.person_24_filled, size: 20, color: Theme.of(context).colorScheme.onSurface),
                                          );
                                        }
                                        return SvgPicture.network(
                                          'https://api.dicebear.com/9.x/rings/svg?seed=$username',
                                          height: 36, width: 36, fit: BoxFit.cover,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          username,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (storage.email != null)
                                          Text(
                                            storage.email!,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                            ),
                            const SizedBox(height: 4),
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              leading: Icon(FluentIcons.person_24_regular, color: Theme.of(context).colorScheme.onSurface, size: 20),
                              title: Text('Profile', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                );
                              },
                            ),
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              leading: Icon(FluentIcons.settings_24_regular, color: Theme.of(context).colorScheme.onSurface, size: 20),
                              title: Text('Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
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
                          final avatarUrl = storage.avatarUrl;
                          final cachedSvg = storage.getUserAvatar();

                          final isSvg = avatarUrl == null || 
                                        avatarUrl.contains('.svg') || 
                                        avatarUrl.contains('dicebear');

                          if (isSvg && cachedSvg != null) {
                            return SvgPicture.string(
                              cachedSvg,
                              height: isDesktop ? 40 : 32,
                              width: isDesktop ? 40 : 32,
                              fit: BoxFit.cover,
                            );
                          }

                          if (avatarUrl != null) {
                            if (isSvg) {
                              return SvgPicture.network(
                                avatarUrl,
                                height: isDesktop ? 40 : 32,
                                width: isDesktop ? 40 : 32,
                                fit: BoxFit.cover,
                                placeholderBuilder: (context) => Container(
                                    padding: const EdgeInsets.all(10),
                                    child: const CircularProgressIndicator(strokeWidth: 2)),
                              );
                            } else {
                              return CachedNetworkImage(
                                imageUrl: avatarUrl,
                                height: isDesktop ? 40 : 32,
                                width: isDesktop ? 40 : 32,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                    padding: const EdgeInsets.all(10),
                                    child: const CircularProgressIndicator(strokeWidth: 2)),
                                errorWidget: (context, url, error) => Icon(FluentIcons.person_24_filled, size: isDesktop ? 24 : 20),
                              );
                            }
                          }

                          return SvgPicture.network(
                            'https://api.dicebear.com/9.x/rings/svg?seed=$username',
                            height: isDesktop ? 40 : 32,
                            width: isDesktop ? 40 : 32,
                            fit: BoxFit.cover,
                            placeholderBuilder: (context) => Container(
                                padding: const EdgeInsets.all(10),
                                child: const CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ref.read(homeFilterProvider.notifier).state = label;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? (isDark ? Colors.black : Colors.white)
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
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

    return ValueListenableBuilder<List<MuzoItem>>(
      valueListenable: storage.historyListenable,
      builder: (context, history, _) {
        if (history.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        // Deduplicate history items by videoId and only show songs with square thumbnails
        final uniqueItems = <String, MuzoItem>{};
        for (var item in history) {
          if (item.videoId != null && !uniqueItems.containsKey(item.videoId)) {
            final thumb = item.thumbnails.lastOrNull;
            if (thumb == null) continue;

            // Strict check for squareness
            // Videos usually have 16:9 (e.g. 320x180) while music/songs have 1:1
            bool isSquare = true;
            if (thumb.width > 0 && thumb.height > 0) {
              if (thumb.width != thumb.height) {
                isSquare = false;
              }
            } else {
              // Heuristic: URLs from i.ytimg.com are usually rectangular videos
              if (thumb.url.contains('i.ytimg.com')) {
                isSquare = false;
              }
            }

            if (isSquare) {
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
              mainAxisSpacing: isDesktop ? 6.0 : 2.0,
              crossAxisSpacing: isDesktop ? 6.0 : 2.0,
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
      child: ValueListenableBuilder<List<Playlist>>(
        valueListenable: storage.playlistsListenable,
        builder: (context, playlists, _) {
          if (playlists.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Text(
                  "Your Playlists",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              SizedBox(
                height: 195,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final name = playlist.name;
                    final songs = playlist.songs;
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
      child: ValueListenableBuilder<List<MuzoItem>>(
        valueListenable: storage.favoritesListenable,
        builder: (context, favorites, _) {
          if (favorites.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Text(
                  "Favorites",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              SizedBox(
                height: 195,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final item = favorites[index];
                    final imageUrl = item.thumbnails.isNotEmpty ? item.thumbnails.last.url : '';
                    final homeItem = HomeItem(
                      title: item.title,
                      subtitle: item.displayArtist,
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

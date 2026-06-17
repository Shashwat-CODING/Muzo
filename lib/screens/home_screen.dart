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
import 'package:muzo/screens/library_screen.dart';
import 'package:muzo/screens/community_screen.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/models/user_data.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:muzo/services/update_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/utils/page_routes.dart';
import 'package:muzo/screens/playlist_details_screen.dart';
import 'package:muzo/screens/settings_screen.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/widgets/quick_picks_section.dart';
import 'package:muzo/widgets/top_on_muzo_section.dart';
import 'package:muzo/providers/explore_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
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
    final dividerCol = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.65) : const Color(0xFFE5E5EA).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: spotifyGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.asset(
                          'assets/Spotify.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.music_note,
                            color: spotifyGreen,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Spotify Import',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Text(
                    'Easily bring your favorite Spotify playlists to Muzo. Head over to the Library to get started!',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.35,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Container(height: 0.5, color: dividerCol),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () {
                            storage.setHasSeenSpotifyAnnouncement(true);
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          child: Text(
                            'Dismiss',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 17,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(width: 0.5, height: 44, color: dividerCol),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () {
                            storage.setHasSeenSpotifyAnnouncement(true);
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          child: const Text(
                            'Awesome',
                            style: TextStyle(
                              color: Color(0xFF1DB954),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
            _buildHomeTab(context, ref),
            const SearchScreen(),
            const LibraryScreen(),
            const SettingsScreen(),
            const CommunityScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Theme.of(context).colorScheme.onSurface,
        backgroundColor: (Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).cardColor
            : Colors.white),
        onRefresh: () async {
          ref.invalidate(topOnMuzoProvider);
          await ref.read(storageServiceProvider).refreshAll();
        },
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader(context, ref)),

            // Quick Picks
            const SliverToBoxAdapter(child: QuickPicksSection()),

            // Top on Muzo (Trending)
            const SliverToBoxAdapter(child: TopOnMuzoSection()),

            // Recently Played
            _buildRecentlyPlayedSection(context, ref),

            // Favourites
            _buildFavoritesSection(context, ref),

            // Your Playlists
            _buildYourPlaylistsSection(context, ref),

            // Bottom padding for mini player + nav bar
            const SliverPadding(padding: EdgeInsets.only(bottom: 140)),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final username = storage.username ?? 'User';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo + Muzo branding
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/logo.png',
                  height: 32,
                  width: 32,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Muzo',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),

          // Avatar with popup menu
          PopupMenuButton<String>(
            onOpened: () => HapticFeedback.lightImpact(),
            offset: const Offset(0, 54),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                                width: 1.0,
                              ),
                            ),
                            child: ClipOval(
                              child: Builder(
                                builder: (context) {
                                  final avatarUrl = storage.avatarUrl;
                                  final cachedSvg = storage.getUserAvatar();
                                  final isSvg = avatarUrl == null ||
                                      avatarUrl.contains('.svg') ||
                                      avatarUrl.contains('dicebear');
                                  if (isSvg && cachedSvg != null) {
                                    return SvgPicture.string(cachedSvg,
                                        height: 36, width: 36, fit: BoxFit.cover);
                                  }
                                  if (avatarUrl != null && !isSvg) {
                                    return CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      height: 36,
                                      width: 36,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Icon(
                                          FluentIcons.person_24_filled,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface),
                                    );
                                  }
                                  return SvgPicture.network(
                                    'https://api.dicebear.com/9.x/rings/svg?seed=$username',
                                    height: 36,
                                    width: 36,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: Icon(FluentIcons.person_24_regular,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20),
                      title: Text('Profile',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14)),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          SlidePageRoute(page: const ProfileScreen()),
                        );
                      },
                    ),
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      leading: Icon(FluentIcons.settings_24_regular,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20),
                      title: Text('Settings',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14)),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          SlidePageRoute(page: const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ValueListenableBuilder(
                  valueListenable: storage.userAvatarListenable,
                  builder: (context, box, _) {
                    final avatarUrl = storage.avatarUrl;
                    final cachedSvg = storage.getUserAvatar();
                    final isSvg = avatarUrl == null ||
                        avatarUrl.contains('.svg') ||
                        avatarUrl.contains('dicebear');
  
                    if (isSvg && cachedSvg != null) {
                      return SvgPicture.string(cachedSvg,
                          height: 36, width: 36, fit: BoxFit.cover);
                    }
                    if (avatarUrl != null) {
                      if (isSvg) {
                        return SvgPicture.network(
                          avatarUrl,
                          height: 36,
                          width: 36,
                          fit: BoxFit.cover,
                          placeholderBuilder: (context) => Container(
                              padding: const EdgeInsets.all(10),
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2)),
                        );
                      } else {
                        return CachedNetworkImage(
                          imageUrl: avatarUrl,
                          height: 36,
                          width: 36,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                              padding: const EdgeInsets.all(10),
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2)),
                          errorWidget: (context, url, error) =>
                              Icon(FluentIcons.person_24_filled, size: 20),
                        );
                      }
                    }
                    return SvgPicture.network(
                      'https://api.dicebear.com/9.x/rings/svg?seed=$username',
                      height: 36,
                      width: 36,
                      fit: BoxFit.cover,
                      placeholderBuilder: (context) => Container(
                          padding: const EdgeInsets.all(10),
                          child: const CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.3,
            ),
      ),
    );
  }

  // ── Horizontal music card ──────────────────────────────────────────────────

  /// A square-ish card (width ~130) with a thumbnail and a single-line title.
  Widget _buildMusicCard({
    required BuildContext context,
    required String title,
    required String? imageUrl,
    required VoidCallback onTap,
  }) {
    const double cardWidth = 152;
    const double borderRadius = 8.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholderTile(context),
                        )
                      : _placeholderTile(context),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderTile(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        FluentIcons.music_note_2_24_filled,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ── Recently Played ────────────────────────────────────────────────────────

  Widget _buildRecentlyPlayedSection(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return SliverToBoxAdapter(
      child: ValueListenableBuilder<List<MuzoItem>>(
        valueListenable: storage.historyListenable,
        builder: (context, history, _) {
          // Deduplicate and filter to square-thumbnail items only
          final uniqueItems = <String, MuzoItem>{};
          for (final item in history) {
            if (item.videoId == null) continue;
            if (uniqueItems.containsKey(item.videoId)) continue;
            final thumb = item.thumbnails.lastOrNull;
            if (thumb == null) continue;
            bool isSquare = true;
            if (thumb.width > 0 && thumb.height > 0) {
              if (thumb.width != thumb.height) isSquare = false;
            } else {
              if (thumb.url.contains('i.ytimg.com')) isSquare = false;
            }
            if (isSquare) uniqueItems[item.videoId!] = item;
          }

          if (uniqueItems.isEmpty) return const SizedBox.shrink();

          final items = uniqueItems.values.toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Recently Played'),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final imageUrl = item.thumbnails.lastOrNull?.url;
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _buildMusicCard(
                        context: context,
                        title: item.title,
                        imageUrl: imageUrl,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(audioHandlerProvider).playVideo(item);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Favourites ─────────────────────────────────────────────────────────────

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
              _buildSectionHeader(context, 'Favourites'),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final item = favorites[index];
                    final imageUrl = item.thumbnails.isNotEmpty
                        ? item.thumbnails.last.url
                        : null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _buildMusicCard(
                        context: context,
                        title: item.title,
                        imageUrl: imageUrl,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(audioHandlerProvider).playVideo(item);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Your Playlists ─────────────────────────────────────────────────────────

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
              _buildSectionHeader(context, 'Your Playlists'),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final firstSong = playlist.songs.isNotEmpty
                        ? playlist.songs.first
                        : null;
                    final imageUrl =
                        firstSong?.thumbnails.isNotEmpty == true
                            ? firstSong!.thumbnails.last.url
                            : null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _buildMusicCard(
                        context: context,
                        title: playlist.name,
                        imageUrl: imageUrl,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            SlidePageRoute(
                              page: PlaylistDetailsScreen(
                                  playlistName: playlist.name),
                            ),
                          );
                        },
                      ),
                    );
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/models/user_data.dart';
import 'package:muzo/widgets/artist_tile.dart';
import 'package:muzo/widgets/library_tile.dart';
import 'package:muzo/screens/playlist_details_screen.dart';
import 'package:muzo/providers/download_provider.dart';
import 'package:muzo/screens/history_screen.dart';
import 'package:muzo/widgets/app_alert_dialog.dart';
import 'package:muzo/utils/page_routes.dart';
import 'package:muzo/widgets/spotify_import_dialog.dart';
import 'package:muzo/providers/navigation_provider.dart';
import 'package:muzo/screens/user_tracks_screen.dart';
import 'package:muzo/screens/auth_screen.dart';
import 'package:muzo/services/auth_service.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    ref.watch(downloadProvider); // Trigger rebuild on download state changes

    return Scaffold(
      backgroundColor: Colors.transparent, // Inherit GlobalBackground
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildAppBar(context, storage),
            _buildFilterBar(),
          ],
          body: _buildLibraryList(context, storage),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, StorageService storage) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            // User Avatar
            ValueListenableBuilder(
              valueListenable: storage.userAvatarListenable,
              builder: (context, box, _) {
                final avatarUrl = storage.avatarUrl;
                final cachedSvg = storage.getUserAvatar();
                final isSvg = avatarUrl == null ||
                    avatarUrl.contains('.svg') ||
                    avatarUrl.contains('dicebear');
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    child: ClipOval(
                      child: isSvg && cachedSvg != null
                          ? SvgPicture.string(cachedSvg, height: 32, width: 32, fit: BoxFit.cover)
                          : avatarUrl != null && !isSvg
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  height: 32, width: 32, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Icon(
                                    FluentIcons.person_24_regular,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    size: 20,
                                  ),
                                )
                              : Icon(
                                  FluentIcons.person_24_regular,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  size: 20,
                                ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
              'Your Library',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showCreatePlaylistDialog(context, storage),
              icon: Icon(FluentIcons.add_24_regular, color: Theme.of(context).colorScheme.onSurface),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SliverToBoxAdapter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildFilterChip('All'),
            const SizedBox(width: 8),
            _buildFilterChip('Playlists'),
            const SizedBox(width: 8),
            _buildFilterChip('Artists'),
            const SizedBox(width: 8),
            _buildFilterChip('Downloaded'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final selectedFilter = ref.watch(libraryFilterProvider);
    final isSelected = selectedFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final chipBgColor = isSelected
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05));
    final chipBorderColor = isSelected
        ? Colors.transparent
        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08));
    final chipTextColor = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      onTap: () {
        if (selectedFilter == label) {
          ref.read(libraryFilterProvider.notifier).state = 'All'; // Toggle off
        } else {
          ref.read(libraryFilterProvider.notifier).state = label;
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chipBgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: chipBorderColor,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: chipTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isSelected && label != 'All') ...[
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.xmark,
                    size: 11,
                    color: chipTextColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryList(BuildContext context, StorageService storage) {
    ref.watch(libraryFilterProvider); // Watch to trigger rebuild when filter changes
    return ValueListenableBuilder<List<Playlist>>(
      valueListenable: storage.playlistsListenable, // Main driver
      builder: (context, playlists, __) {
        return AnimatedBuilder(
          animation: Listenable.merge([
            storage.favoritesListenable,
            storage.subscriptionsListenable,
            storage.downloadsListenable,
          ]),
          builder: (context, _) {
            final items = _getLibraryItems(storage);

            if (items.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FluentIcons.library_24_regular,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Your library is empty',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: items.length,
              itemBuilder: (context, index) => items[index],
            );
          },
        );
      },
    );
  }

  Widget _buildGroupedSystemCard(BuildContext context, StorageService storage) {
    final list = <Widget>[];

    // 1. Liked Songs
    final favoritesCount = storage.getFavorites().length;
    list.add(
      _buildCompactSystemCell(
        context,
        title: 'Liked Songs',
        subtitle: '$favoritesCount songs',
        icon: FluentIcons.heart_24_filled,
        iconBgColor: Colors.pinkAccent,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(
              page: const PlaylistDetailsScreen(
                playlistName: 'Favorites',
                isSystemPlaylist: true,
              ),
            ),
          );
        },
      ),
    );

    // 2. History
    list.add(
      _buildCompactSystemCell(
        context,
        title: 'History',
        subtitle: 'Recently Played',
        icon: FluentIcons.history_24_filled,
        iconBgColor: Colors.orangeAccent,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(page: const HistoryScreen()),
          );
        },
      ),
    );

    // 3. Downloads
    final downloads = storage.getDownloads();
    final downloadState = ref.read(downloadProvider);
    final isDownloading = downloadState.activeDownloads.isNotEmpty;
    list.add(
      _buildCompactSystemCell(
        context,
        title: 'Downloads',
        subtitle: '${downloads.length} files',
        icon: FluentIcons.arrow_download_24_filled,
        iconBgColor: Colors.blueAccent,
        isLoading: isDownloading,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(
              page: const PlaylistDetailsScreen(
                playlistName: 'Downloads',
                isSystemPlaylist: true,
              ),
            ),
          );
        },
      ),
    );

    // 4. My Uploads
    list.add(
      _buildCompactSystemCell(
        context,
        title: 'My Uploads',
        subtitle: 'Upload and manage your tracks',
        icon: FluentIcons.cloud_arrow_up_24_filled,
        iconBgColor: Colors.teal,
        onTap: () {
          final authService = ref.read(authServiceProvider);
          if (authService.isAuthenticated) {
            Navigator.push(
              context,
              SlidePageRoute(page: const UserTracksScreen()),
            );
          } else {
            _showGuestLoginPrompt(context);
          }
        },
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03);
    final cardBorder = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cardBorder,
                width: 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (int i = 0; i < list.length; i++) ...[
                    list[i],
                    if (i < list.length - 1)
                      Divider(
                        height: 1,
                        indent: 60,
                        color: cardBorder,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedSystemCardForPlaylists(BuildContext context, StorageService storage) {
    final list = <Widget>[];

    // 1. Liked Songs
    final favoritesCount = storage.getFavorites().length;
    list.add(
      _buildCompactSystemCell(
        context,
        title: 'Liked Songs',
        subtitle: '$favoritesCount songs',
        icon: FluentIcons.heart_24_filled,
        iconBgColor: Colors.pinkAccent,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(
              page: const PlaylistDetailsScreen(
                playlistName: 'Favorites',
                isSystemPlaylist: true,
              ),
            ),
          );
        },
      ),
    );

    // 2. History
    list.add(
      _buildCompactSystemCell(
        context,
        title: 'History',
        subtitle: 'Recently Played',
        icon: FluentIcons.history_24_filled,
        iconBgColor: Colors.orangeAccent,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(page: const HistoryScreen()),
          );
        },
      ),
    );

    // 3. My Uploads
    list.add(
      _buildCompactSystemCell(
        context,
        title: 'My Uploads',
        subtitle: 'Upload and manage your tracks',
        icon: FluentIcons.cloud_arrow_up_24_filled,
        iconBgColor: Colors.teal,
        onTap: () {
          final authService = ref.read(authServiceProvider);
          if (authService.isAuthenticated) {
            Navigator.push(
              context,
              SlidePageRoute(page: const UserTracksScreen()),
            );
          } else {
            _showGuestLoginPrompt(context);
          }
        },
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03);
    final cardBorder = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cardBorder,
                width: 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (int i = 0; i < list.length; i++) ...[
                    list[i],
                    if (i < list.length - 1)
                      Divider(
                        height: 1,
                        indent: 60,
                        color: cardBorder,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedSystemCardForDownloads(BuildContext context, StorageService storage) {
    final list = <Widget>[];

    // 1. Downloads
    final downloads = storage.getDownloads();
    final downloadState = ref.read(downloadProvider);
    final isDownloading = downloadState.activeDownloads.isNotEmpty;
    list.add(
      _buildCompactSystemCell(
        context,
        title: 'Downloads',
        subtitle: '${downloads.length} files',
        icon: FluentIcons.arrow_download_24_filled,
        iconBgColor: Colors.blueAccent,
        isLoading: isDownloading,
        onTap: () {
          Navigator.push(
            context,
            SlidePageRoute(
              page: const PlaylistDetailsScreen(
                playlistName: 'Downloads',
                isSystemPlaylist: true,
              ),
            ),
          );
        },
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03);
    final cardBorder = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cardBorder,
                width: 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (int i = 0; i < list.length; i++) ...[
                    list[i],
                    if (i < list.length - 1)
                      Divider(
                        height: 1,
                        indent: 60,
                        color: cardBorder,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSystemCell(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      onTap: onTap,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 11,
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        size: 13,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
      ),
    );
  }

  List<Widget> _getLibraryItems(StorageService storage) {
    final selectedFilter = ref.read(libraryFilterProvider);
    final List<Widget> list = [];
    final showPlaylists =
        selectedFilter == 'All' || selectedFilter == 'Playlists';
    final showArtists =
        selectedFilter == 'All' || selectedFilter == 'Artists';

    // 1. Grouped System Card Block
    if (selectedFilter == 'All') {
      list.add(_buildGroupedSystemCard(context, storage));
    } else if (selectedFilter == 'Playlists') {
      list.add(_buildGroupedSystemCardForPlaylists(context, storage));
    } else if (selectedFilter == 'Downloaded') {
      list.add(_buildGroupedSystemCardForDownloads(context, storage));
    }

    // 2. Playlists (User)
    if (showPlaylists) {
      final playlists = storage.getPlaylistNames();
      for (final name in playlists) {
        final songs = storage.getPlaylistSongs(name);
        list.add(
          LibraryTile(
            title: name,
            subtitle: 'Playlist • ${songs.length} songs',
            imageUrl: songs.isNotEmpty && songs.first.thumbnails.isNotEmpty
                ? songs.first.thumbnails.last.url
                : null,
            placeholderIcon: FluentIcons.music_note_2_24_regular,
            onTap: () {
              Navigator.push(
                context,
                SlidePageRoute(page: PlaylistDetailsScreen(playlistName: name)),
              );
            },
            onLongPress: () => _showPlaylistOptions(context, name, storage),
          ),
        );
      }

      // Add the "Import from Spotify" tile
      list.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(FluentIcons.arrow_import_24_filled, color: Color(0xFF1DB954), size: 22),
          ),
          title: Text(
            'Import from Spotify',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: const Text(
            'Add playlists via URL',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: Icon(
            CupertinoIcons.chevron_right,
            size: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const SpotifyImportDialog(),
            );
          },
        ),
      );
    }

    // 3. Artists (from History)
    if (showArtists) {
      final history = storage.getHistory();
      final Set<String> processedArtistNames = {};

      for (final song in history) {
        if (song.artists != null) {
          for (final artist in song.artists!) {
            final name = artist.name.trim();
            if (name.isEmpty || name == 'Unknown') continue;
            if (name.contains(',') ||
                name.contains('&') ||
                name.toLowerCase().contains(' feat ') ||
                name.toLowerCase().contains(' ft ')) {
              continue;
            }
            if (!processedArtistNames.contains(name)) {
              processedArtistNames.add(name);
              final artistId = (artist.id != null && artist.id!.isNotEmpty)
                  ? artist.id!
                  : '';
              list.add(
                ArtistTile(artistName: name, artistId: artistId),
              );
            }
          }
        }
      }
    }

    return list;
  }

  void _showCreatePlaylistDialog(BuildContext context, StorageService storage) {
    final controller = TextEditingController();
    showAppAlertDialog(
      context: context,
      title: 'Create Playlist',
      content: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: CupertinoTextField(
          controller: controller,
          placeholder: 'Playlist Name',
          placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              storage.createPlaylist(controller.text);
              Navigator.pop(context);
            }
          },
          child: Text(
            'Create',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ],
    );
  }

  void _showPlaylistOptions(
    BuildContext context,
    String playlistName,
    StorageService storage,
  ) {
    showAppAlertDialog(
      context: context,
      title: 'Playlist Options',
      content: Text('Are you sure you want to delete the playlist "$playlistName"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            storage.deletePlaylist(playlistName);
          },
          child: Text(
            'Delete',
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showGuestLoginPrompt(BuildContext context) {
    showAppAlertDialog(
      context: context,
      title: 'Sign In Required',
      content: Text(
        'Uploads require a registered account. Sign in or sign up to start uploading your own tracks!',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
          },
          child: Text(
            'Sign In',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

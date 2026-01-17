import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/artist_tile.dart';
import 'package:muzo/widgets/library_tile.dart';
import 'package:muzo/screens/playlist_details_screen.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/providers/download_provider.dart';
import 'package:muzo/screens/history_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:muzo/widgets/app_alert_dialog.dart';
import 'package:muzo/utils/page_routes.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  // Filters: 'All', 'Playlists', 'Artists', 'Downloaded'
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    ref.watch(downloadProvider); // Trigger rebuild on download state changes

    return Scaffold(
      backgroundColor: Colors.transparent, // Inherit GlobalBackground
      body: SafeArea(
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
                final svgString = storage.getUserAvatar();
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[800],
                  child: svgString != null
                      ? ClipOval(child: SvgPicture.string(svgString))
                      : const Icon(
                          FluentIcons.person_24_regular,
                          color: Colors.white,
                          size: 20,
                        ),
                );
              },
            ),
            const SizedBox(width: 12),
            const Text(
              'Your Library',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showCreatePlaylistDialog(context, storage),
              icon: const Icon(FluentIcons.add_24_regular, color: Colors.white),
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
            _buildFilterChip(
              'All',
            ), // Implicitly maps to no filter selected visually or 'All'
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
    // If 'All' is selected, essentially no specific filter is active.
    // But for UI, let's say 'All' clears filters.
    // Or we can toggle.
    // Spotify logic: Tabs like 'Playlists', 'Artists'.
    // If nothing selected, it shows everything.
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedFilter == label) {
            _selectedFilter = 'All'; // Toggle off
          } else {
            _selectedFilter = label;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label == 'All'
              ? 'X'
              : label, // 'All' might be a clear button, but let's keep it simple
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryList(BuildContext context, StorageService storage) {
    return ValueListenableBuilder<Map<String, List<YtifyResult>>>(
      valueListenable: storage.playlistsListenable, // Main driver
      builder: (context, _, __) {
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

  List<Widget> _getLibraryItems(StorageService storage) {
    final List<Widget> list = [];
    final showPlaylists =
        _selectedFilter == 'All' || _selectedFilter == 'Playlists';
    final showArtists =
        _selectedFilter == 'All' || _selectedFilter == 'Artists';
    final showDownloads =
        _selectedFilter == 'All' ||
        _selectedFilter == 'Downloaded' ||
        _selectedFilter == 'Playlists';

    // 1. Liked Songs (Pinned) - Only show if in 'All' or 'Playlists'
    if (showPlaylists) {
      final favoritesCount = storage.getFavorites().length;
      list.add(
        LibraryTile(
          title: 'Liked Songs',
          subtitle: 'Playlist • $favoritesCount songs',
          imageUrl:
              'https://misc.scdn.co/liked-songs/liked-songs-300.png', // Fallback or static asset
          // We can use a gradient container placeholder if image fails, handled by LibraryTile errorWidget
          isPinned: true,
          placeholderIcon: FluentIcons.heart_24_filled,
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
    }

    // 2. History (Pinned)
    if (showPlaylists) {
      // Or maybe just 'All'? But user might think of History as a playlist-like thing.
      // Let's show it in 'All' and 'Playlists' (as a system playlist concept)
      // Or create a new filter 'History'? No, that's clutter.
      // Spotify puts "Listening History" under "By you" or implicitly in "Recents".
      // Let's stick to 'All' or 'Playlists'.
      // Re-using showPlaylists variable for simplicity as it covers 'All' + 'Playlists'.
      list.add(
        LibraryTile(
          title: 'History',
          subtitle: 'System • Recently Played',
          placeholderIcon: FluentIcons.history_24_filled,
          isPinned: true,
          onTap: () {
            Navigator.push(
              context,
              SlidePageRoute(page: const HistoryScreen()),
            );
          },
        ),
      );
    }

    // 3. Downloads (Pinned/Folder)
    if (showDownloads) {
      // We can aggregate all downloads

      final downloads = storage.getDownloads();
      final downloadState = ref.read(downloadProvider);
      final isDownloading = downloadState.activeDownloads.isNotEmpty;

      // Always show Downloads tile as a pinned system item
      list.add(
        LibraryTile(
          title: 'Downloads',
          subtitle: 'Folder • ${downloads.length} files',
          placeholderIcon: FluentIcons.arrow_download_24_filled,
          isPinned: true,
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

      // If filter is specific to 'Downloaded', maybe show individual songs?
      // Spotify usually shows "Downloaded" as a filter that filters the LIST of playlists/albums.
      // Here we have individual songs downloaded.
      // Let's keep it as a folder for now.
    }

    // 3. Playlists (User)
    if (showPlaylists) {
      final playlists = storage.getPlaylistNames();
      for (final name in playlists) {
        final songs = storage.getPlaylistSongs(name);
        list.add(
          LibraryTile(
            title: name,
            subtitle: 'Playlist • ${songs.length} songs',
            // Use first song art as playlist art
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
    }

    // 4. Artists (from History)
    if (showArtists) {
      final history = storage.getHistory();
      final Set<String> processedArtistIds = {};

      for (final song in history) {
        if (song.artists != null) {
          for (final artist in song.artists!) {
            if (artist.id != null && !processedArtistIds.contains(artist.id)) {
              // Exclude composite names if they weren't split by API (e.g. "Artist A & Artist B")
              // User requested only single artists.
              if (artist.name.contains(',') ||
                  artist.name.contains('&') ||
                  artist.name.toLowerCase().contains(' feat ') ||
                  artist.name.toLowerCase().contains(' ft ')) {
                continue;
              }

              processedArtistIds.add(artist.id!);
              list.add(
                ArtistTile(artistName: artist.name, artistId: artist.id!),
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
          style: const TextStyle(color: CupertinoColors.white),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              storage.createPlaylist(controller.text);
              Navigator.pop(context);
            }
          },
          child: const Text(
            'Create',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    // Re-implement or reuse existing dialog logic if possible.
    // For brevity, I'll inline a simple delete option or similar.
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              storage.deletePlaylist(playlistName);
            },
            child: const Row(
              children: [
                Icon(FluentIcons.delete_24_regular, color: Colors.red),
                SizedBox(width: 12),
                Text('Delete Playlist', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/screens/playlist_details_screen.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/providers/download_provider.dart';
import 'package:muzo/widgets/playlist_selection_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:muzo/providers/settings_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  void _showOptions(BuildContext context, YtifyResult item, String type, StorageService storage) {
    final isLiteMode = ref.read(settingsProvider).isLiteMode;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: isLiteMode
                ? Container(
                    width: 300,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E), // Solid background
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: _buildOptionsContent(context, item, type, storage),
                  )
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      width: 300,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: _buildOptionsContent(context, item, type, storage),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsContent(BuildContext context, YtifyResult item, String type, StorageService storage) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            item.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            item.artists?.map((a) => a.name).join(', ') ?? 'Unknown Artist',
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ),
        const SizedBox(height: 24),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        _buildDialogOption(
          icon: FluentIcons.play_24_regular,
          label: 'Play',
          onTap: () {
            Navigator.pop(context);
            ref.read(audioHandlerProvider).playVideo(item);
          },
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        _buildDialogOption(
          icon: FluentIcons.text_bullet_list_ltr_24_regular,
          label: 'Play Next',
          onTap: () {
            Navigator.pop(context);
            ref.read(audioHandlerProvider).playNext(item);
          },
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        _buildDialogOption(
          icon: FluentIcons.list_24_regular,
          label: 'Add to Queue',
          onTap: () {
            Navigator.pop(context);
            ref.read(audioHandlerProvider).addToQueue(item);
            // Show snackbar
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Added to queue'),
                  backgroundColor: Color(0xFF1E1E1E),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        _buildDialogOption(
          icon: FluentIcons.add_square_24_regular,
          label: 'Add to Playlist',
          onTap: () {
            Navigator.pop(context);
            showCupertinoDialog(
              context: context,
              barrierDismissible: true,
              builder: (context) => PlaylistSelectionDialog(song: item),
            );
          },
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        _buildDialogOption(
          icon: FluentIcons.delete_24_regular,
          label: 'Remove',
          color: Colors.red,
          onTap: () {
            Navigator.pop(context);
            if (type == 'favorites') {
              storage.toggleFavorite(item);
            } else if (type == 'history') {
              storage.removeFromHistory(item.videoId!);
            } else if (type == 'downloads') {
              ref.read(downloadProvider.notifier).deleteDownload(item.videoId!);
            }
          },
        ),
        const SizedBox(height: 8),
      ],
    );

  }

  void _showPlaylistOptions(BuildContext context, String playlistName, StorageService storage) {
    final isLiteMode = ref.read(settingsProvider).isLiteMode;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: isLiteMode
                ? Container(
                    width: 300,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E), // Solid background
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: _buildPlaylistOptionsContent(context, playlistName, storage),
                  )
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      width: 300,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: _buildPlaylistOptionsContent(context, playlistName, storage),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistOptionsContent(BuildContext context, String playlistName, StorageService storage) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        const Icon(FluentIcons.text_bullet_list_ltr_24_regular, color: Colors.white, size: 60),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            playlistName,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const SizedBox(height: 24),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        _buildDialogOption(
          icon: FluentIcons.play_24_regular,
          label: 'Play All',
          onTap: () {
            Navigator.pop(context);
            final songs = storage.getPlaylistSongs(playlistName);
            if (songs.isNotEmpty) {
              ref.read(audioHandlerProvider).playAll(songs);
            }
          },
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        _buildDialogOption(
          icon: FluentIcons.delete_24_regular,
          label: 'Delete Playlist',
          color: Colors.red,
          onTap: () {
            Navigator.pop(context);
            storage.deletePlaylist(playlistName);
            setState(() {});
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDialogOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.white,
          backgroundColor: const Color(0xFF1E1E1E),
          onRefresh: () async {
            await ref.read(storageServiceProvider).refreshAll();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Favorites Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Favorites',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to full favorites
                      },
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<List<YtifyResult>>(
                  valueListenable: storage.favoritesListenable,
                  builder: (context, favorites, _) {
                    if (favorites.isEmpty) {
                      return const Text('No favorites yet', style: TextStyle(color: Colors.grey));
                    }
                    return SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final item = favorites[index];
                          final itemWidth = _calculateItemWidth(item);
  
                          return GestureDetector(
                            onTap: () {
                              ref.read(audioHandlerProvider).playVideo(item);
                            },
                            onLongPress: () {
                              _showOptions(context, item, 'favorites', storage);
                            },
                            child: Container(
                              width: itemWidth,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : '',
                                      height: 110,
                                      width: itemWidth,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          Container(color: Colors.grey[800], width: itemWidth, height: 110),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );},
                ),
                
                const SizedBox(height: 32),
  
                // Downloads Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Downloads',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to full downloads
                      },
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<Box>(
                  valueListenable: storage.downloadsListenable,
                  builder: (context, box, _) {
                    final completedDownloads = storage.getDownloads();
                    final downloadState = ref.watch(downloadProvider);
                    final activeDownloads = downloadState.activeDownloads;
                    
                    if (completedDownloads.isEmpty && activeDownloads.isEmpty) {
                      return const Text('No downloads yet', style: TextStyle(color: Colors.grey));
                    }
  
                    return SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: activeDownloads.length + completedDownloads.length,
                        itemBuilder: (context, index) {
                          // Show active downloads first
                          if (index < activeDownloads.length) {
                            final videoId = activeDownloads.keys.elementAt(index);
                            final item = activeDownloads[videoId]!;
                            final progress = downloadState.progressMap[videoId] ?? 0.0;
                            
                            final itemWidth = _calculateItemWidth(item);
                            
                            return Container(
                              width: itemWidth,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: ColorFiltered(
                                          colorFilter: ColorFilter.mode(
                                            Colors.black.withOpacity(0.5), 
                                            BlendMode.darken
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : '',
                                            height: 110,
                                            width: itemWidth,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, url, error) =>
                                                Container(color: Colors.grey[800], width: itemWidth, height: 110),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: progress,
                                            color: Colors.white,
                                            strokeWidth: 4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          // Show completed downloads
                          final itemData = completedDownloads[index - activeDownloads.length];
                          final item = YtifyResult.fromJson(Map<String, dynamic>.from(itemData['result']));
                          final itemWidth = _calculateItemWidth(item);
  
                          return GestureDetector(
                            onTap: () {
                              ref.read(audioHandlerProvider).playVideo(item);
                            },
                            onLongPress: () {
                              _showOptions(context, item, 'downloads', storage);
                            },
                            child: Container(
                              width: itemWidth,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : '',
                                      height: 110,
                                      width: itemWidth,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          Container(color: Colors.grey[800], width: itemWidth, height: 110),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 32),
  
                // History Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to full history
                      },
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<List<YtifyResult>>(
                  valueListenable: storage.historyListenable,
                  builder: (context, history, _) {
                    if (history.isEmpty) {
                      return const Text('No history yet', style: TextStyle(color: Colors.grey));
                    }
                    return SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final item = history[index];
                          final itemWidth = _calculateItemWidth(item);
  
                          return GestureDetector(
                            onTap: () {
                              ref.read(audioHandlerProvider).playVideo(item);
                            },
                            onLongPress: () {
                              _showOptions(context, item, 'history', storage);
                            },
                            child: Container(
                              width: itemWidth,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: item.thumbnails.isNotEmpty ? item.thumbnails.last.url : '',
                                      height: 110,
                                      width: itemWidth,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          Container(color: Colors.grey[800], width: itemWidth, height: 110),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                  
                const SizedBox(height: 32),
                
                // Playlists Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Playlists',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.add_24_regular, color: Colors.white),
                      onPressed: () {
                        _showCreatePlaylistDialog(context, storage);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<Map<String, List<YtifyResult>>>(
                  valueListenable: storage.playlistsListenable,
                  builder: (context, playlistsMap, _) {
                    final playlists = storage.getPlaylistNames();
                    if (playlists.isEmpty) {
                      return const Text('No playlists created', style: TextStyle(color: Colors.grey));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final name = playlists[index];
                        final songs = storage.getPlaylistSongs(name);
                        return ListTile(
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(FluentIcons.text_bullet_list_ltr_24_regular, color: Colors.white),
                          ),
                          title: Text(name, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${songs.length} songs', style: TextStyle(color: Colors.grey[400])),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlaylistDetailsScreen(playlistName: name),
                              ),
                            );
                          },
                          onLongPress: () {
                            _showPlaylistOptions(context, name, storage);
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  double _calculateItemWidth(YtifyResult item) {
    if (item.thumbnails.isNotEmpty) {
      final thumb = item.thumbnails.last;
      if (thumb.width > 0 && thumb.height > 0) {
        // Calculate width based on height of 110
        return (110 * thumb.width / thumb.height);
      }
    }
    // Fallback based on type
    final isVideo = item.resultType == 'video';
    return isVideo ? 196.0 : 110.0;
  }

  void _showCreatePlaylistDialog(BuildContext context, StorageService storage) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Create Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist Name',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                storage.createPlaylist(controller.text);
                setState(() {}); // Refresh UI
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

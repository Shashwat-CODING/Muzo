import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/services/youtube_api_service.dart'; // Ensure valid import
import 'package:muzo/widgets/library_tile.dart';
import 'package:muzo/screens/artist_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/utils/page_routes.dart';

class ArtistTile extends ConsumerStatefulWidget {
  final String artistName;
  final String artistId;

  const ArtistTile({
    super.key,
    required this.artistName,
    required this.artistId,
  });

  @override
  ConsumerState<ArtistTile> createState() => _ArtistTileState();
}

class _ArtistTileState extends ConsumerState<ArtistTile> {
  final _apiService = YouTubeApiService();
  String? _avatarUrl;
  late String _navChannelId;

  @override
  void initState() {
    super.initState();
    _navChannelId = widget.artistId;
    _fetchAvatar();
  }

  Future<void> _fetchAvatar() async {
    final storage = ref.read(storageServiceProvider);

    // Check cache first
    final cachedUrl = storage.getArtistImage(widget.artistName);
    if (cachedUrl != null) {
      if (mounted) {
        setState(() {
          _avatarUrl = cachedUrl;
        });
      }
    }

    // If we have both ID and Image, no need to fetch
    if (_avatarUrl != null && _navChannelId.isNotEmpty) return;

    if (mounted) {
      try {
        final response = await _apiService.search(
          widget.artistName,
          filter: 'artists',
        );
        if (mounted && response.results.isNotEmpty) {
          final result = response.results.first;

          setState(() {
            if (result.thumbnails.isNotEmpty) {
              // Try to get high-res image by replacing size param
              final highResUrl = result.thumbnails.last.url.replaceAll(
                RegExp(r'=[sw]\d+(-h\d+)?'),
                '=s800',
              );
              _avatarUrl = highResUrl;
              // Cache the image
              storage.setArtistImage(widget.artistName, highResUrl);
            }
            // If we didn't have a valid ID (or even if we did, the search result might be more accurate/canonical), update it.
            // Especially important for split names where we pass empty ID.
            // Only update ID if we didn't have one
            if (_navChannelId.isEmpty && result.browseId != null) {
              _navChannelId = result.browseId!;
            }
          });
        }
      } catch (e) {
        // Ignore error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LibraryTile(
      title: widget.artistName,
      subtitle: 'Artist',
      imageUrl: _avatarUrl,
      isRound: true,
      placeholderIcon: FluentIcons.person_24_regular,
      onTap: () {
        if (_navChannelId.isNotEmpty) {
          Navigator.push(
            context,
            SlidePageRoute(
              page: ArtistScreen(
                browseId: _navChannelId,
                artistName: widget.artistName,
                thumbnailUrl: _avatarUrl,
              ),
            ),
          );
        }
      },
    );
  }
}

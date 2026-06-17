import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/widgets/global_background.dart';
import 'package:muzo/widgets/glass_container.dart';
import 'package:muzo/widgets/song_options_menu.dart';
import 'package:muzo/widgets/skeleton_loader.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final List<MuzoItem> _tracks = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _errorMessage;
  int _offset = 0;
  static const int _limit = 30;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTracks(isRefresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMoreTracks();
      }
    }
  }

  Future<void> _loadTracks({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _offset = 0;
        _isLoading = true;
        _errorMessage = null;
        _tracks.clear();
      });
    }

    try {
      final api = ref.read(muzoApiServiceProvider);
      final result = await api.getCommunityFeed(
        limit: _limit,
        offset: _offset,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      final List<MuzoItem> newTracks = List<MuzoItem>.from(result['tracks'] ?? []);
      final bool newHasMore = result['hasMore'] as bool? ?? false;

      if (mounted) {
        setState(() {
          _tracks.addAll(newTracks);
          _hasMore = newHasMore;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreTracks() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _offset += _limit;
    });
    await _loadTracks(isRefresh: false);
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
        _loadTracks(isRefresh: true);
      }
    });
  }

  Widget _buildUploaderAvatar(String? avatarUrl, String username, double size) {
    final isSvg = avatarUrl != null && (avatarUrl.contains('.svg') || avatarUrl.contains('dicebear'));

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: Colors.grey[800],
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? (isSvg
                ? SvgPicture.network(
                    avatarUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholderBuilder: (_) => Icon(FluentIcons.person_20_regular, size: size * 0.6, color: Colors.grey[400]),
                  )
                : CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Icon(FluentIcons.person_20_regular, size: size * 0.6, color: Colors.grey[400]),
                    errorWidget: (_, __, ___) => Icon(FluentIcons.person_20_regular, size: size * 0.6, color: Colors.grey[400]),
                  ))
            : Icon(FluentIcons.person_20_regular, size: size * 0.6, color: Colors.grey[400]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final currentMediaItem = ref.watch(currentMediaItemProvider).value;
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;

    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Premium Frosted Header and Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FluentIcons.people_community_24_regular,
                            color: theme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Community Feed',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CupertinoSearchTextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        placeholder: 'Search community music...',
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                        placeholderStyle: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                        backgroundColor: cs.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        onChanged: _onSearchChanged,
                      ),
                    ],
                  ),
                ),
              ),

              // Tracks List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadTracks(isRefresh: true),
                  color: theme.primaryColor,
                  backgroundColor: theme.cardColor,
                  child: _buildContent(currentMediaItem, isPlaying, theme, cs),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    dynamic currentMediaItem,
    bool isPlaying,
    ThemeData theme,
    ColorScheme cs,
  ) {
    if (_isLoading && _tracks.isEmpty) {
      return _buildSkeletonLoader();
    }

    if (_errorMessage != null && _tracks.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.5,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.warning_24_regular,
                size: 48,
                color: cs.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _loadTracks(isRefresh: true),
                icon: const Icon(FluentIcons.arrow_sync_24_regular),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_tracks.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.5,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.music_note_2_24_regular,
                size: 72,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No public tracks found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back later or search for something else!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
      itemCount: _tracks.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _tracks.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        final item = _tracks[index];
        final isCurrent = currentMediaItem?.id == item.videoId;
        final imageUrl = item.thumbnails.lastOrNull?.url;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(audioHandlerProvider).playVideo(item);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: isCurrent ? 0.08 : 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? theme.primaryColor.withValues(alpha: 0.25)
                          : cs.onSurface.withValues(alpha: 0.06),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail / Artwork
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: Colors.grey[900]),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey[900],
                                    child: const Icon(FluentIcons.music_note_2_24_regular),
                                  ),
                                )
                              : Container(
                                  color: cs.onSurface.withValues(alpha: 0.05),
                                  child: Icon(
                                    FluentIcons.music_note_2_24_regular,
                                    color: cs.onSurface.withValues(alpha: 0.3),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Track Title & Uploader info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent ? theme.primaryColor : cs.onSurface,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Row showing Uploader avatar and username
                            Row(
                              children: [
                                _buildUploaderAvatar(
                                  item.artists?.firstOrNull?.id, // We mapped the avatar seed/id here
                                  item.channelName ?? 'Unknown',
                                  16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'by @${item.channelName ?? "Unknown"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(alpha: 0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item.description != null && item.description!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.35),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Play status or Options Menu
                      const SizedBox(width: 8),
                      if (isCurrent) ...[
                        Icon(
                          isPlaying ? FluentIcons.play_circle_24_filled : FluentIcons.pause_circle_24_filled,
                          color: theme.primaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                      ],
                      IconButton(
                        icon: Icon(
                          FluentIcons.more_vertical_24_regular,
                          color: cs.onSurface.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          SongOptionsMenu.show(ref, item);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.all(10),
            child: const Row(
              children: [
                SkeletonLoader(width: 52, height: 52, borderRadius: 8),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 160, height: 16, borderRadius: 3),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          SkeletonLoader(width: 16, height: 16, borderRadius: 8),
                          SizedBox(width: 6),
                          SkeletonLoader(width: 80, height: 12, borderRadius: 3),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

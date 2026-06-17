import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/widgets/song_options_menu.dart';
import 'package:muzo/widgets/skeleton_loader.dart';

class QuickPicksSection extends ConsumerStatefulWidget {
  const QuickPicksSection({super.key});

  @override
  ConsumerState<QuickPicksSection> createState() => _QuickPicksSectionState();
}

class _QuickPicksSectionState extends ConsumerState<QuickPicksSection> {
  List<MuzoItem> _quickPicks = [];
  bool _isLoading = false;
  String? _error;
  List<String> _lastFetchedIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final storage = ref.read(storageServiceProvider);
        storage.historyListenable.addListener(_onHistoryChanged);
        _onHistoryChanged(); // Run initial check/fetch
      }
    });
  }

  @override
  void dispose() {
    try {
      final storage = ref.read(storageServiceProvider);
      storage.historyListenable.removeListener(_onHistoryChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onHistoryChanged() {
    if (!mounted) return;
    final storage = ref.read(storageServiceProvider);
    final history = storage.getHistory();
    
    // Extract top 15 unique video IDs from history (linked set preserves order)
    final ids = history
        .map((item) => item.videoId)
        .whereType<String>()
        .toSet()
        .take(15)
        .toList();

    if (_listEquals(ids, _lastFetchedIds)) {
      return;
    }

    _fetchQuickPicks(ids);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _fetchQuickPicks(List<String> ids) async {
    if (ids.isEmpty) {
      if (mounted) {
        setState(() {
          _quickPicks = [];
          _isLoading = false;
          _error = null;
          _lastFetchedIds = [];
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(muzoApiServiceProvider);
      final results = await apiService.getQuickPicks(ids);
      
      if (mounted) {
        setState(() {
          _quickPicks = results;
          _isLoading = false;
          _lastFetchedIds = ids;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If loading and we have no cached quick picks, show skeleton
    if (_isLoading && _quickPicks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const QuickPicksSkeleton(),
        ],
      );
    }

    // Hide section on error or empty
    if (_error != null || _quickPicks.isEmpty) {
      return const SizedBox.shrink();
    }

    final columnsCount = (_quickPicks.length / 4).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: columnsCount,
            itemBuilder: (context, columnIndex) {
              final startIndex = columnIndex * 4;
              final columnItems = _quickPicks.skip(startIndex).take(4).toList();

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 320,
                  child: Column(
                    children: columnItems
                        .map((item) => QuickPickRowItem(item: item))
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(
        'Quick Picks',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 17,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

class QuickPickRowItem extends ConsumerWidget {
  final MuzoItem item;
  const QuickPickRowItem({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = item.thumbnails.lastOrNull?.url;
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(audioHandlerProvider).playVideo(item);
      },
      onLongPress: () {
        HapticFeedback.lightImpact();
        SongOptionsMenu.show(ref, item);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(context),
                    )
                  : _placeholder(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                FluentIcons.more_vertical_24_regular,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 18,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                SongOptionsMenu.show(ref, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        FluentIcons.music_note_2_24_filled,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}

class QuickPicksSkeleton extends StatelessWidget {
  const QuickPicksSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 320,
              child: Column(
                children: List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const SkeletonLoader(width: 48, height: 48, borderRadius: 4),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SkeletonLoader(width: double.infinity, height: 14, borderRadius: 3),
                            const SizedBox(height: 6),
                            const SkeletonLoader(width: 120, height: 10, borderRadius: 3),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ),
            ),
          );
        },
      ),
    );
  }
}

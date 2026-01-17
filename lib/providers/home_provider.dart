import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/ytm_home.dart';
import 'package:muzo/services/storage_service.dart';

final ytmHomeServiceProvider = Provider<YouTubeMusicHomeService>((ref) {
  final service = YouTubeMusicHomeService();
  ref.onDispose(() => service.dispose());
  return service;
});

final homeSectionsProvider =
    AsyncNotifierProvider<HomeSectionsNotifier, List<HomeSection>>(() {
      return HomeSectionsNotifier();
    });

class HomeSectionsNotifier extends AsyncNotifier<List<HomeSection>> {
  @override
  Future<List<HomeSection>> build() async {
    final storage = ref.watch(storageServiceProvider);

    // Attempt to load from cache
    final cached = storage.getHomeCache();
    if (cached.isNotEmpty) {
      // Trigger background refresh
      // Delay slightly to allow the UI to render the cached content first
      Future.delayed(Duration.zero, _refreshBackground);
      return cached;
    }

    // Initial fetch if no cache
    final service = ref.watch(ytmHomeServiceProvider);
    await service.initialize();
    final fresh = await service.getHome(limit: 10);
    storage.setHomeCache(fresh);
    return fresh;
  }

  Future<void> _refreshBackground() async {
    try {
      final service = ref.read(ytmHomeServiceProvider);
      await service.initialize();
      final fresh = await service.getHome(limit: 10);

      // Update cache
      ref.read(storageServiceProvider).setHomeCache(fresh);

      // Update state if mounted
      state = AsyncValue.data(fresh);
    } catch (e) {
      // Silent error for background update
    }
  }

  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final service = ref.read(ytmHomeServiceProvider);
      await service.initialize();
      final fresh = await service.getHome(limit: 10);

      ref.read(storageServiceProvider).setHomeCache(fresh);
      state = AsyncValue.data(fresh);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final homeFilterProvider = StateProvider<String>((ref) => 'All');

final filteredHomeSectionsProvider = Provider<AsyncValue<List<HomeSection>>>((
  ref,
) {
  final homeSectionsAsync = ref.watch(homeSectionsProvider);
  final filter = ref.watch(homeFilterProvider);

  return homeSectionsAsync.whenData((sections) {
    if (filter == 'All') return sections;

    return sections
        .map((section) {
          final filteredItems = section.items.where((item) {
            if (filter == 'Songs') {
              return item.type == 'song' || item.videoId != null;
            }
            if (filter == 'Videos') {
              return item.type ==
                  'video'; // item.type might not be reliable for video vs song, usually song is default. YtifyResult has resultType. HomeItem has type.
            }
            // Let's check HomeItem type logic.
            // _parseMusicItem: type = 'album' | 'artist' | 'playlist'
            // _parseResponsiveItem: type = 'song' | 'playlist'
            // There is no explicit 'video' type in current parsing for HomeItem, largely 'song'.
            // However, user wants "Videos". YouTube Music "Songs" are essentially videos.
            // For now, let's map:
            // Songs -> type == 'song'
            // Albums -> type == 'album'
            // Playlists -> type == 'playlist'
            // Videos -> maybe we can't distinguish easily without more data, or we assume everything else?
            // Let's stick to what we can.
            if (filter == 'Albums') return item.type == 'album';
            if (filter == 'Playlists') return item.type == 'playlist';
            return false;
          }).toList();

          if (filteredItems.isEmpty) return null;
          return HomeSection(title: section.title, items: filteredItems);
        })
        .whereType<HomeSection>()
        .toList();
  });
});

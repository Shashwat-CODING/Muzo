import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/ytm_home.dart';
import 'package:muzo/services/storage_service.dart';

final ytmHomeServiceProvider = Provider<YouTubeMusicHomeService>((ref) {
  final service = YouTubeMusicHomeService();
  ref.onDispose(() => service.dispose());
  return service;
});

final homeSectionsProvider = AsyncNotifierProvider<HomeSectionsNotifier, List<HomeSection>>(() {
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

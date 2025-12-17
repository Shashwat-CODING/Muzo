import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/services/youtube_api_service.dart';

final trendingContentProvider = FutureProvider<Map<String, List<YtifyResult>>>((ref) async {
  final apiService = YouTubeApiService();
  return apiService.getTrendingContent();
});

final newestSongsProvider = FutureProvider<List<YtifyResult>>((ref) async {
  final content = await ref.watch(trendingContentProvider.future);
  return content['songs'] ?? [];
});

final newestVideosProvider = FutureProvider<List<YtifyResult>>((ref) async {
  final content = await ref.watch(trendingContentProvider.future);
  return content['videos'] ?? [];
});

final trendingPlaylistsProvider = FutureProvider<List<YtifyResult>>((ref) async {
  final content = await ref.watch(trendingContentProvider.future);
  return content['playlists'] ?? [];
});

// Keep this for backward compatibility if needed, or remove if unused.
// For now, I'll redefine it to combine everything or just deprecate it.
// Since HomeScreen will be rewritten, we might not need this anymore.
// But to avoid breaking other things immediately, let's leave a dummy or combined one.
final exploreContentProvider = FutureProvider<List<YtifyResult>>((ref) async {
  final songs = await ref.watch(newestSongsProvider.future);
  final videos = await ref.watch(newestVideosProvider.future);
  return [...songs, ...videos]..shuffle();
});

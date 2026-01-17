import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/services/youtube_api_service.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchFilterProvider = StateProvider<String>((ref) => 'songs');

final searchResultsProvider =
    StateNotifierProvider<SearchResultsNotifier, AsyncValue<List<YtifyResult>>>(
      (ref) {
        return SearchResultsNotifier(ref);
      },
    );

class SearchResultsNotifier
    extends StateNotifier<AsyncValue<List<YtifyResult>>> {
  final Ref ref;
  String? _continuationToken;
  bool _isLoadingMore = false;

  SearchResultsNotifier(this.ref) : super(const AsyncValue.data([])) {
    // Listen to query and filter changes
    ref.listen(searchQueryProvider, (previous, next) {
      if (next.isNotEmpty) _search(next, ref.read(searchFilterProvider));
    });
    ref.listen(searchFilterProvider, (previous, next) {
      final query = ref.read(searchQueryProvider);
      if (query.isNotEmpty) _search(query, next);
    });
  }

  Future<void> _search(String query, String filter) async {
    state = const AsyncValue.loading();
    _continuationToken = null;
    try {
      final apiService = YouTubeApiService();
      final response = await apiService.search(query, filter: filter);
      _continuationToken = response.continuationToken;
      state = AsyncValue.data(response.results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_continuationToken == null || _isLoadingMore) return;

    _isLoadingMore = true;
    final currentResults = state.value ?? [];
    final query = ref.read(searchQueryProvider);
    final filter = ref.read(searchFilterProvider);

    try {
      final apiService = YouTubeApiService();
      final response = await apiService.search(
        query,
        filter: filter,
        continuationToken: _continuationToken,
      );
      _continuationToken = response.continuationToken;
      state = AsyncValue.data([...currentResults, ...response.results]);
    } catch (e) {
      // Handle error silently or show snackbar
      print('Error loading more: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  bool get hasMore => _continuationToken != null;
}

final searchSuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];
  final apiService = YouTubeApiService();
  return await apiService.getSearchSuggestions(query);
});

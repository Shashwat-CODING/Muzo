import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/services/muzo_api_service.dart';

final searchControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

final searchFocusNodeProvider = Provider<FocusNode>((ref) {
  final focusNode = FocusNode();
  ref.onDispose(() => focusNode.dispose());
  return focusNode;
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchFilterProvider = StateProvider<String>((ref) => 'all');

final searchResultsProvider =
    StateNotifierProvider<SearchResultsNotifier, AsyncValue<List<MuzoItem>>>(
      (ref) {
        return SearchResultsNotifier(ref);
      },
    );

class SearchResultsNotifier
    extends StateNotifier<AsyncValue<List<MuzoItem>>> {
  final Ref ref;
  late final MuzoApiService _api = ref.read(muzoApiServiceProvider);
  String? _continuationToken;
  bool _isLoadingMore = false;

  SearchResultsNotifier(this.ref) : super(const AsyncValue.data([])) {
    // Listen to query and filter changes
    ref.listen(searchQueryProvider, (previous, next) {
      if (next.isNotEmpty) {
        _search(next, ref.read(searchFilterProvider));
      } else {
        state = const AsyncValue.data([]);
      }
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
      if (filter == 'all') {
        final futures = [
          _api.search(query, filter: 'songs').then((res) => res.results.map((r) => r.copyWith(category: 'Songs')).toList()),
          _api.search(query, filter: 'videos').then((res) => res.results.map((r) => r.copyWith(category: 'Videos')).toList()),
          _api.search(query, filter: 'albums').then((res) => res.results.map((r) => r.copyWith(category: 'Albums')).toList()),
          _api.search(query, filter: 'artists').then((res) => res.results.map((r) => r.copyWith(category: 'Artists')).toList()),
          _api.search(query, filter: 'playlists').then((res) => res.results.map((r) => r.copyWith(category: 'Playlists')).toList()),
          _api.search(query, filter: 'channels').then((res) => res.results.map((r) => r.copyWith(category: 'Channels')).toList()),
        ];
        final resultsArray = await Future.wait(futures);
        _continuationToken = null;
        state = AsyncValue.data(resultsArray.expand((i) => i).toList());
      } else {
        final response = await _api.search(query, filter: filter);
        _continuationToken = response.continuationToken;
        state = AsyncValue.data(response.results);
      }
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
      final response = await _api.search(
        query,
        filter: filter,
        continuationToken: _continuationToken,
      );
      _continuationToken = response.continuationToken;
      state = AsyncValue.data([...currentResults, ...response.results]);
    } catch (e) {
      debugPrint('Error loading more search results: $e');
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
  final apiService = ref.read(muzoApiServiceProvider);
  return await apiService.getSearchSuggestions(query);
});

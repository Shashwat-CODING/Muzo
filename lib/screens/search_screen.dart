import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/search_provider.dart';
import 'package:muzo/widgets/result_tile.dart';
import 'package:muzo/providers/settings_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _showSuggestions = _searchController.text.isNotEmpty;
    });
  }

  void _performSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    setState(() {
      _showSuggestions = false;
    });
    ref.read(searchQueryProvider.notifier).state = query;
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final currentFilter = ref.watch(searchFilterProvider);
    final suggestionsAsync = ref.watch(
      searchSuggestionsProvider(_searchController.text),
    );
    final isLiteMode = ref.watch(settingsProvider).isLiteMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'Search songs, albums, artists',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      prefixIcon: const Icon(
                        FluentIcons.search_24_regular,
                        color: Colors.white70,
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                FluentIcons.dismiss_24_regular,
                                color: Colors.white70,
                                size: 22,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showSuggestions = false;
                                });
                                ref.read(searchQueryProvider.notifier).state =
                                    '';
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (value) {
                      _performSearch(value);
                    },
                    onChanged: (value) {
                      // Ensure clear button visibility updates
                      setState(() {});
                    },
                  ),
                ),
              ),
            ),
            if (!_showSuggestions) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('Channels', currentFilter, isLiteMode),
                    const SizedBox(width: 8),
                    _buildFilterChip('Songs', currentFilter, isLiteMode),
                    const SizedBox(width: 8),
                    _buildFilterChip('Albums', currentFilter, isLiteMode),
                    const SizedBox(width: 8),
                    _buildFilterChip('Videos', currentFilter, isLiteMode),
                    const SizedBox(width: 8),
                    _buildFilterChip('Artists', currentFilter, isLiteMode),
                    const SizedBox(width: 8),
                    _buildFilterChip('Playlists', currentFilter, isLiteMode),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: _showSuggestions
                  ? suggestionsAsync.when(
                      data: (suggestions) {
                        return ListView.builder(
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = suggestions[index];
                            return ListTile(
                              leading: const Icon(
                                FluentIcons.search_24_regular,
                                color: Colors.grey,
                                size: 16,
                              ),
                              title: Text(
                                suggestion,
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () => _performSearch(suggestion),
                            );
                          },
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (error, stack) => const SizedBox.shrink(),
                    )
                  : searchResults.when(
                      data: (results) {
                        if (results.isEmpty) {
                          return Center(
                            child: Text(
                              'Search for something...',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 160),
                          itemCount: results.length + 1,
                          itemBuilder: (context, index) {
                            if (index == results.length) {
                              final notifier = ref.read(
                                searchResultsProvider.notifier,
                              );
                              if (!notifier.hasMore) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      notifier.loadMore();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text('Load More'),
                                  ),
                                ),
                              );
                            }
                            return ResultTile(result: results[index]);
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text(
                          'Error: $error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String currentFilter, bool isLiteMode) {
    final isSelected = label.toLowerCase() == currentFilter.toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.transparent, width: 0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ref.read(searchFilterProvider.notifier).state = label.toLowerCase();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

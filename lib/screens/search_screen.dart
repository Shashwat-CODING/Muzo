import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/search_provider.dart';
import 'package:muzo/widgets/result_tile.dart';
import 'package:muzo/models/muzo_item.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Auto-focus the search bar on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
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
    _focusNode.unfocus();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar — YouTube Music style
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  cursorColor: Theme.of(context).colorScheme.primary,
                  decoration: InputDecoration(
                    hintText: 'Search songs, albums, artists...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w400,
                    ),
                    filled: false,
                    prefixIcon: IconButton(
                      icon: Icon(
                        FluentIcons.arrow_left_24_regular,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 22,
                      ),
                      onPressed: () {
                        ref.read(searchQueryProvider.notifier).state = '';
                        Navigator.pop(context);
                      },
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              FluentIcons.dismiss_circle_24_filled,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _focusNode.requestFocus();
                              setState(() => _showSuggestions = false);
                              ref.read(searchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (value) => _performSearch(value),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),

            // Filter chips — YouTube Music style horizontal pills
            if (!_showSuggestions) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildFilterChip('All', currentFilter),
                    _buildFilterChip('Songs', currentFilter),
                    _buildFilterChip('Videos', currentFilter),
                    _buildFilterChip('Albums', currentFilter),
                    _buildFilterChip('Artists', currentFilter),
                    _buildFilterChip('Playlists', currentFilter),
                    _buildFilterChip('Channels', currentFilter),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Results / Suggestions
            Expanded(
              child: _showSuggestions
                  ? _buildSuggestions(suggestionsAsync)
                  : _buildResults(searchResults, currentFilter),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(AsyncValue<List<String>> suggestionsAsync) {
    return suggestionsAsync.when(
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return ListView.separated(
          padding: const EdgeInsets.only(top: 4),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const SizedBox.shrink(),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(
                FluentIcons.search_24_regular,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                size: 18,
              ),
              title: Text(
                suggestion,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                ),
              ),
              trailing: Icon(
                FluentIcons.arrow_up_left_24_regular,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                size: 18,
              ),
              onTap: () => _performSearch(suggestion),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildResults(AsyncValue<List<MuzoItem>> searchResults, String currentFilter) {
    return searchResults.when(
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.music_note_2_24_regular,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 16),
                Text(
                  'Search for music',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        // Grouped "All" view
        if (currentFilter == 'all') {
          final Map<String, List<MuzoItem>> grouped = {};
          for (final r in results) {
            grouped.putIfAbsent(r.category ?? 'Other', () => []).add(r);
          }
          final order = ['Songs', 'Videos', 'Albums', 'Artists', 'Playlists', 'Channels'];
          final cats = grouped.keys.toList()
            ..sort((a, b) {
              final ia = order.indexOf(a);
              final ib = order.indexOf(b);
              if (ia != -1 && ib != -1) return ia.compareTo(ib);
              if (ia != -1) return -1;
              if (ib != -1) return 1;
              return a.compareTo(b);
            });

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 160),
            itemCount: cats.length,
            itemBuilder: (context, index) {
              final cat = cats[index];
              final items = grouped[cat]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (order.contains(cat))
                          GestureDetector(
                            onTap: () => ref
                                .read(searchFilterProvider.notifier)
                                .state = cat.toLowerCase(),
                            child: Text(
                              'More',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...items.take(4).map((r) => ResultTile(result: r)),
                ],
              );
            },
          );
        }

        // Filtered list view
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 160),
          itemCount: results.length + 1,
          itemBuilder: (context, index) {
            if (index == results.length) {
              final notifier = ref.read(searchResultsProvider.notifier);
              if (!notifier.hasMore) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: TextButton(
                    onPressed: () => notifier.loadMore(),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
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
      loading: () => Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          strokeWidth: 2,
        ),
      ),
      error: (error, stack) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String currentFilter) {
    final isSelected = label.toLowerCase() == currentFilter.toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            ref.read(searchFilterProvider.notifier).state = label.toLowerCase();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
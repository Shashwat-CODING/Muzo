import 'dart:ui';
import 'package:flutter/material.dart';
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
    final suggestionsAsync = ref.watch(searchSuggestionsProvider(_searchController.text));
    final isLiteMode = ref.watch(settingsProvider).isLiteMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: isLiteMode 
                    ? Container(
                        color: const Color(0xFF1E1E1E), // Solid background for lite mode
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search songs, videos, artists',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.transparent, // Transparent because container has color
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Icon(FluentIcons.search_24_regular, color: Colors.white, size: 18),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(FluentIcons.dismiss_24_regular, color: Colors.grey, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _showSuggestions = false;
                                });
                                ref.read(searchQueryProvider.notifier).state = '';
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                          onSubmitted: (value) {
                            _performSearch(value);
                          },
                        ),
                      )
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search songs, videos, artists',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E).withValues(alpha: 0.2),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Icon(FluentIcons.search_24_regular, color: Colors.white, size: 18),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(FluentIcons.dismiss_24_regular, color: Colors.grey, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _showSuggestions = false;
                            });
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onSubmitted: (value) {
                        _performSearch(value);
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
                              leading: const Icon(FluentIcons.search_24_regular, color: Colors.grey, size: 16),
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
                              final notifier = ref.read(searchResultsProvider.notifier);
                              if (!notifier.hasMore) return const SizedBox.shrink();
                              
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      notifier.loadMore();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.1),
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
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text('Error: $error',
                            style: const TextStyle(color: Colors.red)),
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
    
    if (isLiteMode) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: const Color(0xFF1E1E1E), // Solid background
          child: FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (bool selected) {
              ref.read(searchFilterProvider.notifier).state = label.toLowerCase();
            },
            backgroundColor: Colors.transparent,
            selectedColor: Colors.white.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.white : Colors.grey[800]!,
              ),
            ),
            showCheckmark: false,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (bool selected) {
            ref.read(searchFilterProvider.notifier).state = label.toLowerCase();
          },
          backgroundColor: const Color(0xFF1E1E1E).withValues(alpha: 0.2),
          selectedColor: Colors.white.withValues(alpha: 0.2),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? Colors.white : Colors.grey[800]!,
            ),
          ),
          showCheckmark: false,
        ),
      ),
    );
  }
}

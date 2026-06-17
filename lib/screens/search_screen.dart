import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
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

  void _performSearch(String query) {
    final controller = ref.read(searchControllerProvider);
    final focusNode = ref.read(searchFocusNodeProvider);
    controller.text = query;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    focusNode.unfocus();
    ref.read(searchQueryProvider.notifier).state = query;
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final currentFilter = ref.watch(searchFilterProvider);
    final controller = ref.watch(searchControllerProvider);
    final focusNode = ref.watch(searchFocusNodeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // iOS 26 Liquid Glass Filters at the top
            _buildIos26Filters(context, ref, currentFilter),
            
            // Suggestions or Results
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, textValue, _) {
                  final text = textValue.text;
                  final showSuggestions = text.isNotEmpty && focusNode.hasFocus;
                  
                  if (showSuggestions) {
                    final suggestionsAsync = ref.watch(searchSuggestionsProvider(text));
                    return _buildSuggestions(suggestionsAsync);
                  } else {
                    return _buildResults(searchResults, currentFilter);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIos26Filters(BuildContext context, WidgetRef ref, String currentFilter) {
    final filters = ['All', 'Songs', 'Videos', 'Albums', 'Artists', 'Playlists', 'Channels'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter.toLowerCase() == currentFilter.toLowerCase();
          
          return _buildLiquidGlassChip(context, ref, filter, isSelected, isDark);
        },
      ),
    );
  }

  Widget _buildLiquidGlassChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    bool isSelected,
    bool isDark,
  ) {
    final chipBgColor = isSelected
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05));
    final chipBorderColor = isSelected
        ? Colors.transparent
        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08));
    final chipTextColor = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black);

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (isSelected) {
            ref.read(searchFilterProvider.notifier).state = 'all';
          } else {
            ref.read(searchFilterProvider.notifier).state = label.toLowerCase();
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chipBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: chipBorderColor,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: chipTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isSelected && label != 'All') ...[
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.xmark,
                      size: 11,
                      color: chipTextColor,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(AsyncValue<List<String>> suggestionsAsync) {
    return suggestionsAsync.when(
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 160),
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
}
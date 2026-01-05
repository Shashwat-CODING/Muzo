import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/result_tile.dart';
import 'package:muzo/widgets/glass_snackbar.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              floating: true,
              pinned: false,
              title: Text(
                'History',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            
            // Header / Clear Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Recently Played',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            title: const Text('Clear History', style: TextStyle(color: Colors.white)),
                            content: const Text(
                              'Are you sure you want to clear your listening history?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  storage.clearHistory();
                                  showGlassSnackBar(context, 'History cleared');
                                },
                                child: const Text('Clear', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(FluentIcons.delete_24_regular, size: 16, color: Colors.grey),
                      label: const Text('Clear', style: TextStyle(color: Colors.grey)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            ValueListenableBuilder<List<YtifyResult>>(
              valueListenable: storage.historyListenable,
              builder: (context, history, _) {
                if (history.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No history yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return ResultTile(result: history[index]);
                    },
                    childCount: history.length,
                  ),
                );
              },
            ),
            
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
    );
  }
}

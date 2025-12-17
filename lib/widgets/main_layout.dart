
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/navigation_provider.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/widgets/mini_player.dart';
import 'package:muzo/services/share_service.dart';
import 'package:muzo/widgets/global_background.dart';
import 'package:muzo/widgets/sync_progress_dialog.dart';
import 'package:muzo/widgets/glass_container.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  late final ShareService _shareService;

  @override
  void initState() {
    super.initState();
    final audioHandler = ref.read(audioHandlerProvider);
    _shareService = ShareService(audioHandler);
    // Post frame callback to ensure context is ready for snackbars if needed immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shareService.init(context);
    });
  }

  @override
  void dispose() {
    _shareService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationIndexProvider);
    final isPlayerExpanded = ref.watch(isPlayerExpandedProvider);

    final audioHandler = ref.watch(audioHandlerProvider);
    
    _setupErrorListener(ref);

    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Main Content (Navigator)
            widget.child,

            // Bottom Navigation Bar (Floating)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: IgnorePointer(
                ignoring: isPlayerExpanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isPlayerExpanded ? 0.0 : 1.0,
                  child: GlassContainer( 
                    borderRadius: BorderRadius.circular(16), // Match MiniPlayer radius (16)
                    color: Colors.black.withValues(alpha: 0.85),
                    opacity: 0.0,
                    blur: 30,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: _buildFloatingNavBar(context, ref, selectedIndex),
                    ),
                  ),
                ),
              ),
            ),

            // MiniPlayer (Floating above Navbar) - Placed AFTER Navbar to ensure z-index top
            Positioned(
              left: 16, // Aligned with Navbar
              right: 16, // Aligned with Navbar
              bottom: MediaQuery.of(context).padding.bottom + 12 + 52 + 12, // NavBottom (12) + NavHeight (52) + Spacing (12)
              child: Consumer(
                builder: (context, ref, _) {
                  final mediaItemAsync = ref.watch(currentMediaItemProvider);
                  // Check if player is expanded to hide miniplayer during transition
                  final isPlayerExpandedVal = ref.watch(isPlayerExpandedProvider);
                  
                  return mediaItemAsync.maybeWhen(
                    data: (mediaItem) {
                      if (mediaItem == null) return const SizedBox.shrink();
                      return IgnorePointer(
                        ignoring: isPlayerExpandedVal,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isPlayerExpandedVal ? 0.0 : 1.0,
                          child: GlassContainer(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.black.withValues(alpha: 0.85),
                            opacity: 0.0,
                            blur: 30,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                              child: MiniPlayer(),
                            ),
                          ),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
            ),

            // Loading Overlay
            ValueListenableBuilder<bool>(
              valueListenable: audioHandler.isLoadingStream,
              builder: (context, isAudioLoading, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: ref.watch(storageServiceProvider).isLoadingNotifier,
                  builder: (context, isStorageLoading, _) {
                    final isLoading = isAudioLoading || isStorageLoading;
                    if (!isLoading) return const SizedBox.shrink();
                    return Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setupErrorListener(WidgetRef ref) {
    ref.listen(storageServiceProvider, (previous, next) {
      if (previous?.errorNotifier.value != next.errorNotifier.value && next.errorNotifier.value != null) {
        showGlassSnackBar(context, next.errorNotifier.value!);
        // Reset error after showing
        next.errorNotifier.value = null;
      }
    });
  }

  Widget _buildFloatingNavBar(BuildContext context, WidgetRef ref, int selectedIndex) {
    return SizedBox(
      height: 52, // Matched to MiniPlayer height
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(context, ref, FluentIcons.home_24_regular, FluentIcons.home_24_filled, 0, selectedIndex),
          _buildNavItem(context, ref, FluentIcons.search_24_regular, FluentIcons.search_24_filled, 1, selectedIndex),
          _buildNavItem(context, ref, FluentIcons.library_24_regular, FluentIcons.library_24_filled, 2, selectedIndex), // Library
          _buildNavItem(context, ref, FluentIcons.people_24_regular, FluentIcons.people_24_filled, 3, selectedIndex), // Community/User
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, WidgetRef ref, IconData iconRegular, IconData iconFilled, int index, int selectedIndex) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (index == 0 || index == 1 || index == 2 || index == 3) {
          ref.read(navigationIndexProvider.notifier).state = index;
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        } else if (index == 5) {
           if (navigatorKey.currentContext != null) {
             showDialog(
               context: navigatorKey.currentContext!,
               barrierDismissible: false,
               builder: (context) => const SyncProgressDialog(),
             );
           }
        }
      },
      child: Container(
        color: Colors.transparent, // Hit test behavior
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // Reduced vertical padding to prevent overflow
        child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Icon(
               isSelected ? iconFilled : iconRegular,
               color: isSelected ? Colors.white : Colors.grey.withValues(alpha: 0.6),
               size: 26, // Spotify icons are decent size
             ),
             if (isSelected)
               Container( // Spotify often has a label or indicator, but here we just keep it clean
                 margin: const EdgeInsets.only(top: 4),
                 height: 4, 
                 width: 4,
                 decoration: const BoxDecoration(
                   color: Colors.white,
                   shape: BoxShape.circle,
                 ),
               ),
           ],
        ),
      ),
    );
  }
}

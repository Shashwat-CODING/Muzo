
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
import 'package:muzo/providers/theme_provider.dart';

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
        body: Stack(
          children: [
            // Main Content (Navigator)
            widget.child,

            // Bottom Navigation Bar (Docked)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: isPlayerExpanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isPlayerExpanded ? 0.0 : 1.0,
                  child: Container(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8), // Little dark top
                          Colors.black.withValues(alpha: 1.0), // More dark bottom
                        ],
                      ),
                    ),
                    height: 60 + MediaQuery.of(context).padding.bottom,
                    child: _buildFloatingNavBar(context, ref, selectedIndex),
                  ),
                ),
              ),
            ),

            // MiniPlayer (Floating above Navbar, ~95% Width)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60 + MediaQuery.of(context).padding.bottom, // Directly above navbar (60 + safe area)
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  widthFactor: 0.96, // Slightly wider to match Spotify "floating" look close to edges
                  child: Consumer(
                    builder: (context, ref, _) {
                      final mediaItemAsync = ref.watch(currentMediaItemProvider);
                      final palette = ref.watch(currentPaletteProvider).asData?.value;
                      // Check if player is expanded to hide miniplayer during transition
                      final isPlayerExpandedVal = ref.watch(isPlayerExpandedProvider);
                      
                      Color miniPlayerColor = const Color(0xff404040).withValues(alpha: 1.0); // Opaque default
                      if (palette != null) {
                        miniPlayerColor = (palette.darkVibrantColor?.color ?? 
                                           palette.darkMutedColor?.color ?? 
                                           palette.dominantColor?.color ?? 
                                           const Color(0xff404040)).withValues(alpha: 1.0);
                      }

                      return mediaItemAsync.maybeWhen(
                        data: (mediaItem) {
                          if (mediaItem == null) return const SizedBox.shrink();
                          return IgnorePointer(
                            ignoring: isPlayerExpandedVal,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isPlayerExpandedVal ? 0.0 : 1.0,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 0), // No gap
                                decoration: BoxDecoration(
                                  color: miniPlayerColor,
                                  borderRadius: BorderRadius.circular(6), // Slightly rounded corners
                                ),
                                child: const MiniPlayer(),
                              ),
                            ),
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
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
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround, // Space Around for even distribution
        children: [
          _buildNavItem(context, ref, FluentIcons.home_24_regular, FluentIcons.home_24_filled, "Home", 0, selectedIndex),
          _buildNavItem(context, ref, FluentIcons.search_24_regular, FluentIcons.search_24_filled, "Search", 1, selectedIndex),
          _buildNavItem(context, ref, FluentIcons.library_24_regular, FluentIcons.library_24_filled, "Library", 2, selectedIndex),
          _buildNavItem(context, ref, FluentIcons.person_24_regular, FluentIcons.person_24_filled, "Channels", 3, selectedIndex),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, WidgetRef ref, IconData iconRegular, IconData iconFilled, String label, int index, int selectedIndex) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
      child: SizedBox(
        width: 64, // Fixed width for touch target
        child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           mainAxisSize: MainAxisSize.max,
           children: [
             Icon(
               isSelected ? iconFilled : iconRegular,
               color: isSelected ? Colors.white : const Color(0xffb3b3b3),
               size: 26,
             ),
             const SizedBox(height: 4),
             Text(
               label,
               maxLines: 1,
               style: TextStyle(
                 color: isSelected ? Colors.white : const Color(0xffb3b3b3),
                 fontSize: 10,
                 fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
               ),
             ),
           ],
        ),
      ),
    );
  }
}

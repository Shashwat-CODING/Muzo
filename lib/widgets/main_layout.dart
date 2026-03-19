import 'dart:async';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/navigation_provider.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/theme_provider.dart';
import 'package:muzo/providers/search_provider.dart';
import 'package:muzo/screens/search_screen.dart';
import 'package:muzo/widgets/mini_player.dart';
import 'package:muzo/widgets/sync_progress_dialog.dart';
import 'package:muzo/services/share_service.dart';
import 'package:muzo/widgets/global_background.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/providers/overlay_provider.dart';
import 'package:muzo/services/auth_service.dart';
import 'package:app_links/app_links.dart';
import 'package:muzo/widgets/floating_sleep_timer.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with SingleTickerProviderStateMixin {
  late final ShareService _shareService;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    final audioHandler = ref.read(audioHandlerProvider);
    _shareService = ShareService(audioHandler);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shareService.init(context);
    });

    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    
    // Check initial link if app was in cold state (minimized)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial uri: $e');
    }

    // Handle link when app is in warm state (foreground or background)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep Link stream error: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received Deep Link: $uri');
    // Using the exact logic as ShareService via the audio handler for playback
    _shareService.handleSharedText(context, uri.toString());
  }


  @override
  void dispose() {
    _shareService.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationIndexProvider);
    final isPlayerExpanded = ref.watch(isPlayerExpandedProvider);

    final audioHandler = ref.read(audioHandlerProvider);

    final globalBottomSheet = ref.watch(globalBottomSheetProvider);
    final authState = ref.watch(authServiceProvider);

    // Listen for storage errors
    ref.listen(storageServiceProvider, (previous, next) {
      if (previous?.errorNotifier.value != next.errorNotifier.value &&
          next.errorNotifier.value != null) {
        showGlassSnackBar(context, next.errorNotifier.value!);
        next.errorNotifier.value = null;
      }
    });

    // Close global bottom sheet on tab change
    ref.listen(navigationIndexProvider, (previous, next) {
      if (previous != next) {
        ref.read(globalBottomSheetProvider.notifier).state = null;
      }
    });

    return GlobalBackground(
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Ensure GlobalBackground is visible
        body: Stack(
          children: [
            // 1. Main Content (Navigator)
            widget.child,

            // 2. Loading Overlay (Covers only the main content area)
            ValueListenableBuilder<bool>(
              valueListenable: audioHandler.isLoadingStream,
              builder: (context, isAudioLoading, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: ref
                      .watch(storageServiceProvider)
                      .isLoadingNotifier,
                  builder: (context, isStorageLoading, _) {
                    final isLoading = isAudioLoading || isStorageLoading;
                    if (!isLoading) return const SizedBox.shrink();
                    return Container(
                      color: const Color(0xFF121212).withValues(alpha: 0.5),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                );
              },
            ),

            // 3. Bottom Navigation Bar (Should be above loader)
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
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.6),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                    height: 50 + MediaQuery.of(context).padding.bottom,
                    child: _buildFloatingNavBar(context, ref, selectedIndex),
                  ),
                ),
              ),
            ),

            // 4. MiniPlayer (Floating above Navbar, ~95% Width)
            Positioned(
              left: 0,
              right: 0,
              bottom:
                  50 +
                  MediaQuery.of(
                    context,
                  ).padding.bottom, // Directly above navbar (50 + safe area)
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  widthFactor:
                      0.96, // Slightly wider to match Spotify "floating" look close to edges
                  child: Consumer(
                    builder: (context, ref, _) {
                      final mediaItemAsync = ref.watch(
                        currentMediaItemProvider,
                      );
                      final palette = ref
                          .watch(currentPaletteProvider)
                          .asData
                          ?.value;
                      // Check if player is expanded to hide miniplayer during transition
                      final isPlayerExpandedVal = ref.watch(
                        isPlayerExpandedProvider,
                      );

                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      Color miniPlayerColor = isDark
                          ? const Color(0xff404040)
                          : Colors.white;
                      if (palette != null) {
                        final extracted =
                            palette.darkVibrantColor?.color ??
                            palette.darkMutedColor?.color ??
                            palette.dominantColor?.color ??
                            const Color(0xff404040);
                        if (isDark) {
                          // Dark mode: use extracted color (blended with dark)
                          miniPlayerColor = Color.lerp(const Color(0xff303030), extracted, 0.6)!;
                        } else {
                          // Light mode: 50% white + 50% extracted
                          miniPlayerColor = Color.lerp(Colors.white, extracted, 0.5)!;
                        }
                      }

                      return mediaItemAsync.maybeWhen(
                        data: (mediaItem) {
                          if (mediaItem == null) return const SizedBox.shrink();
                          return IgnorePointer(
                            ignoring: isPlayerExpandedVal,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isPlayerExpandedVal ? 0.0 : 1.0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.only(
                                  bottom: 0,
                                ), // No gap
                                decoration: BoxDecoration(
                                  color: miniPlayerColor,
                                  borderRadius: BorderRadius.circular(
                                    6,
                                  ), // Slightly rounded corners
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

            // 5. Floating Sleep Timer Overlay
            const FloatingSleepTimer(),

            // 6. Global Bottom Sheet Overlay (Should cover navbar when open)
            if (globalBottomSheet != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      // Dimmed Background
                      GestureDetector(
                        onTap: () => ref.read(globalBottomSheetProvider.notifier).state = null,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                      ),
                      // Bottom Sheet Content
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: globalBottomSheet,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }






  Widget _buildFloatingNavBar(
    BuildContext context,
    WidgetRef ref,
    int selectedIndex,
  ) {
    return SizedBox(
      height: 50,
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround, // Space Around for even distribution
        children: [
          _buildNavItem(
            context,
            ref,
            FluentIcons.home_24_regular,
            FluentIcons.home_24_filled,
            "Home",
            0,
            selectedIndex,
          ),
          _buildNavItem(
            context,
            ref,
            FluentIcons.library_24_regular,
            FluentIcons.library_24_filled,
            "Library",
            1,
            selectedIndex,
          ),
          _buildNavItem(
            context,
            ref,
            FluentIcons.person_24_regular,
            FluentIcons.person_24_filled,
            "Channels",
            2,
            selectedIndex,
          ),
          _buildNavItem(
            context,
            ref,
            FluentIcons.settings_24_regular,
            FluentIcons.settings_24_filled,
            "Settings",
            3,
            selectedIndex,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref,
    IconData iconRegular,
    IconData iconFilled,
    String label,
    int index,
    int selectedIndex,
  ) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        if (index >= 0 && index <= 3) {
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
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

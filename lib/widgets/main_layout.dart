import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/navigation_provider.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/bottom_sheet_provider.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/widgets/mini_player.dart';
import 'package:muzo/widgets/song_options_menu.dart';
import 'package:muzo/services/share_service.dart';
import 'package:muzo/widgets/global_background.dart';
import 'package:muzo/widgets/sync_progress_dialog.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/providers/theme_provider.dart';
import 'package:muzo/models/ytify_result.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with SingleTickerProviderStateMixin {
  late final ShareService _shareService;
  late final AnimationController _sheetAnimController;
  late final Animation<Offset> _sheetSlideAnimation;
  late final Animation<double> _sheetFadeAnimation;
  bool _previousSheetVisible = false;

  // Cached sheet data to persist during closing animation
  YtifyResult? _cachedResult;
  bool _cachedFromHistory = false;
  bool _cachedFromPlayer = false;

  @override
  void initState() {
    super.initState();
    final audioHandler = ref.read(audioHandlerProvider);
    _shareService = ShareService(audioHandler);

    // Bottom sheet animation setup
    _sheetAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sheetSlideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 1), // Start from bottom
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _sheetAnimController,
            curve: Curves.easeOutCubic,
          ),
        );
    _sheetFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sheetAnimController, curve: Curves.easeOut),
    );

    // Post frame callback to ensure context is ready for snackbars if needed immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shareService.init(context);
    });
  }

  @override
  void dispose() {
    _sheetAnimController.dispose();
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
        backgroundColor:
            Colors.transparent, // Ensure GlobalBackground is visible
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
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6), // Visible top
                          Colors.black.withValues(alpha: 1.0), // Solid bottom
                        ],
                      ),
                    ),
                    height: 50 + MediaQuery.of(context).padding.bottom,
                    child: _buildFloatingNavBar(context, ref, selectedIndex),
                  ),
                ),
              ),
            ),

            // MiniPlayer (Floating above Navbar, ~95% Width)
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

                      Color miniPlayerColor = const Color(
                        0xff404040,
                      ).withValues(alpha: 1.0); // Opaque default
                      if (palette != null) {
                        miniPlayerColor =
                            (palette.darkVibrantColor?.color ??
                                    palette.darkMutedColor?.color ??
                                    palette.dominantColor?.color ??
                                    const Color(0xff404040))
                                .withValues(alpha: 1.0);
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

            // Loading Overlay
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
                      color: Colors.black.withValues(alpha: 0.5),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                );
              },
            ),

            // Bottom Sheet Overlay (Above everything including miniplayer/navbar)
            _buildBottomSheetOverlay(ref),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetOverlay(WidgetRef ref) {
    final sheetState = ref.watch(bottomSheetProvider);
    final isLiteMode = ref.watch(settingsProvider).isLiteMode;
    final isVisible = sheetState.isVisible && sheetState.result != null;

    // Trigger animation when visibility changes
    if (isVisible != _previousSheetVisible) {
      _previousSheetVisible = isVisible;
      if (isVisible) {
        // Cache the sheet data when opening
        _cachedResult = sheetState.result;
        _cachedFromHistory = sheetState.fromHistory;
        _cachedFromPlayer = sheetState.fromPlayer;
        _sheetAnimController.forward();
      } else {
        _sheetAnimController.reverse();
      }
    }

    // Use cached data if available, otherwise use current state
    final displayResult = _cachedResult ?? sheetState.result;
    final displayFromHistory = _cachedFromHistory;
    final displayFromPlayer = _cachedFromPlayer;

    return AnimatedBuilder(
      animation: _sheetAnimController,
      builder: (context, child) {
        // Hide when animation is dismissed AND not visible
        if (_sheetAnimController.isDismissed && !isVisible) {
          // Clear cache after animation completes
          _cachedResult = null;
          return const SizedBox.shrink();
        }

        // Safety check - if no result to display, don't render
        if (displayResult == null) {
          return const SizedBox.shrink();
        }

        // Get the same background color used in GlobalBackground
        final theme = Theme.of(context);
        final sheetBackgroundColor = isLiteMode
            ? Colors.black
            : theme.scaffoldBackgroundColor;

        return GestureDetector(
          onTap: () => _hideSheetWithAnimation(ref),
          child: Container(
            color: Colors.black.withValues(
              alpha: 0.5 * _sheetFadeAnimation.value,
            ),
            child: Column(
              children: [
                const Spacer(),
                SlideTransition(
                  position: _sheetSlideAnimation,
                  child: GestureDetector(
                    onTap: () {}, // Prevent close on sheet tap
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: isLiteMode
                          ? Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: sheetBackgroundColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: SafeArea(
                                top: false,
                                child: SongOptionsMenu(
                                  result: displayResult,
                                  fromHistory: displayFromHistory,
                                  fromPlayer: displayFromPlayer,
                                  onClose: () => _hideSheetWithAnimation(ref),
                                ),
                              ),
                            )
                          : BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: sheetBackgroundColor.withValues(
                                    alpha: 0.85,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                ),
                                child: SafeArea(
                                  top: false,
                                  child: SongOptionsMenu(
                                    result: displayResult,
                                    fromHistory: displayFromHistory,
                                    fromPlayer: displayFromPlayer,
                                    onClose: () => _hideSheetWithAnimation(ref),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hideSheetWithAnimation(WidgetRef ref) async {
    await _sheetAnimController.reverse();
    ref.read(bottomSheetProvider.notifier).hide();
  }

  void _setupErrorListener(WidgetRef ref) {
    ref.listen(storageServiceProvider, (previous, next) {
      if (previous?.errorNotifier.value != next.errorNotifier.value &&
          next.errorNotifier.value != null) {
        showGlassSnackBar(context, next.errorNotifier.value!);
        // Reset error after showing
        next.errorNotifier.value = null;
      }
    });
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
            FluentIcons.search_24_regular,
            FluentIcons.search_24_filled,
            "Search",
            1,
            selectedIndex,
          ),
          _buildNavItem(
            context,
            ref,
            FluentIcons.library_24_regular,
            FluentIcons.library_24_filled,
            "Library",
            2,
            selectedIndex,
          ),
          _buildNavItem(
            context,
            ref,
            FluentIcons.person_24_regular,
            FluentIcons.person_24_filled,
            "Channels",
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

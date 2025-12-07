import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytx/providers/navigation_provider.dart';
import 'package:ytx/providers/player_provider.dart';
import 'package:ytx/services/navigator_key.dart';
import 'package:ytx/widgets/mini_player.dart';
import 'package:ytx/services/share_service.dart';
import 'package:ytx/widgets/global_background.dart';
import 'package:ytx/widgets/sync_progress_dialog.dart';
import 'package:ytx/widgets/glass_container.dart';
import 'package:ytx/services/storage_service.dart';
import 'package:ytx/widgets/glass_snackbar.dart';

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

            // MiniPlayer and Floating Navigation Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: IgnorePointer(
                ignoring: isPlayerExpanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isPlayerExpanded ? 0.0 : 1.0,
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(32),
                    color: const Color(0xFF1E1E1E),
                    opacity: 0.1, // Decreased opacity to make background more visible
                    blur: 15, // Increased blur for stronger glass effect
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Conditional MiniPlayer
                        Consumer(
                          builder: (context, ref, _) {
                            final mediaItemAsync = ref.watch(currentMediaItemProvider);
                            return mediaItemAsync.maybeWhen(
                              data: (mediaItem) {
                                if (mediaItem == null) return const SizedBox.shrink();
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                                      child: MiniPlayer(),
                                    ),
                                    Divider(
                                      height: 1,
                                      thickness: 0.5,
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ],
                                );
                              },
                              orElse: () => const SizedBox.shrink(),
                            );
                          },
                        ),
                        _buildFloatingNavBar(context, ref, selectedIndex),
                      ],
                    ),
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
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(context, ref, FontAwesomeIcons.house, 0, selectedIndex),
          _buildNavItem(context, ref, FontAwesomeIcons.magnifyingGlass, 1, selectedIndex),
          _buildNavItem(context, ref, FontAwesomeIcons.compactDisc, 2, selectedIndex),
          _buildNavItem(context, ref, FontAwesomeIcons.userGroup, 3, selectedIndex),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, WidgetRef ref, IconData icon, int index, int selectedIndex) {
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
        padding: const EdgeInsets.all(12),
        child: FaIcon(
          icon,
          color: isSelected ? Colors.white : Colors.grey.withValues(alpha: 0.6),
          size: 20, // Adjusted size for Font Awesome
        ),
      ),
    );
  }
}

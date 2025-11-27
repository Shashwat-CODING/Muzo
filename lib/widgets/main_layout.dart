import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ytx/providers/navigation_provider.dart';
import 'package:ytx/providers/player_provider.dart';
import 'package:ytx/screens/settings_screen.dart';
import 'package:ytx/screens/about_screen.dart';
import 'package:ytx/services/navigator_key.dart';
import 'package:ytx/widgets/mini_player.dart';
import 'package:ytx/services/share_service.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // Main Content (Navigator)
          widget.child,

          // MiniPlayer and Floating Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: IgnorePointer(
                ignoring: isPlayerExpanded,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isPlayerExpanded ? 0.0 : 1.0,
                  child: Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MiniPlayer(),
                          const SizedBox(height: 2),
                          _buildFloatingNavBar(context, ref, selectedIndex),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay
          ValueListenableBuilder<bool>(
            valueListenable: audioHandler.isLoadingStream,
            builder: (context, isLoading, _) {
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
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(BuildContext context, WidgetRef ref, int selectedIndex) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(
            height: 60, // Slightly taller for better touch targets
            decoration: BoxDecoration(
              color: const Color(0xFF272727).withValues(alpha: 0.5), // More transparency
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(context, ref, CupertinoIcons.home, 0, selectedIndex),
                _buildNavItem(context, ref, CupertinoIcons.search, 1, selectedIndex),
                _buildNavItem(context, ref, CupertinoIcons.music_albums, 2, selectedIndex),
                _buildNavItem(context, ref, CupertinoIcons.person_2, 3, selectedIndex), // Subscriptions
                _buildNavItem(context, ref, CupertinoIcons.settings, 4, selectedIndex),
                _buildNavItem(context, ref, CupertinoIcons.info, 5, selectedIndex),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildNavItem(BuildContext context, WidgetRef ref, IconData icon, int index, int selectedIndex) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        ref.read(navigationIndexProvider.notifier).state = index;
        
        if (index == 4) {
           navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        } else if (index == 5) {
           navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const AboutScreen()));
        } else {
           navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      },
      child: Container(
        color: Colors.transparent, // Hit test behavior
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey.withValues(alpha: 0.6),
          size: 26,
        ),
      ),
    );
  }
}

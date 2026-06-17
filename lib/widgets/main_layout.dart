import 'dart:async';
import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/navigation_provider.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/widgets/mini_player.dart';
import 'package:muzo/services/share_service.dart';
import 'package:muzo/widgets/global_background.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/providers/overlay_provider.dart';
import 'package:app_links/app_links.dart';
import 'package:muzo/widgets/floating_sleep_timer.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/screens/profile_screen.dart';
import 'package:muzo/utils/page_routes.dart';
import 'package:muzo/providers/search_provider.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final ShareService _shareService;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  
  @override
  bool get wantKeepAlive => true;

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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final selectedIndex = ref.watch(navigationIndexProvider);
    final isPlayerExpanded = ref.watch(isPlayerExpandedProvider);

    final audioHandler = ref.read(audioHandlerProvider);

    final globalBottomSheet = ref.watch(globalBottomSheetProvider);
    final isDesktop = MediaQuery.of(context).size.width > 600;

    // Listen for storage errors
    ref.listen(storageServiceProvider, (previous, next) {
      if (previous?.errorNotifier.value != next.errorNotifier.value &&
          next.errorNotifier.value != null) {
        showGlassSnackBar(context, next.errorNotifier.value!);
        next.errorNotifier.value = null;
      }
    });

    // Close global bottom sheet and handle search on tab change
    ref.listen(navigationIndexProvider, (previous, next) {
      if (previous != next) {
        ref.read(globalBottomSheetProvider.notifier).state = null;
        if (nestedNavigatorKey.currentState != null &&
            nestedNavigatorKey.currentState!.canPop()) {
          nestedNavigatorKey.currentState!.popUntil((route) => route.isFirst);
        }
      }
      if (next != 1) {
        ref.read(searchControllerProvider).clear();
        ref.read(searchFocusNodeProvider).unfocus();
        ref.read(searchQueryProvider.notifier).state = '';
      } else {
        // Automatically request focus when switching to search
        Future.delayed(const Duration(milliseconds: 150), () {
          ref.read(searchFocusNodeProvider).requestFocus();
        });
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final nestedNavigator = Navigator(
      key: nestedNavigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => widget.child,
          settings: settings,
        );
      },
    );

    final mainBody = isDesktop
        ? Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: isPlayerExpanded ? 0 : 240,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF9F9F9),
                ),
                child: SizedBox(
                  width: 240,
                  height: double.infinity,
                  child: _buildSidebar(context, ref),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: isPlayerExpanded ? 0 : 1,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    nestedNavigator,
                    _buildLoadingOverlay(audioHandler),
                    _buildMiniPlayerPositioned(context, ref, isDesktop),
                    const FloatingSleepTimer(),
                  ],
                ),
              ),
            ],
          )
        : Stack(
            children: [
              nestedNavigator,
              _buildLoadingOverlay(audioHandler),
              _buildBottomNavBar(context, ref, selectedIndex, isPlayerExpanded),
              _buildMiniPlayerPositioned(context, ref, isDesktop),
              const FloatingSleepTimer(),
            ],
          );

    final systemOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle,
      child: GlobalBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent, // Ensure GlobalBackground is visible
          body: Stack(
            children: [
              mainBody,
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
      ),
    );
  }

  Widget _buildLoadingOverlay(dynamic audioHandler) {
    return ValueListenableBuilder<bool>(
      valueListenable: audioHandler.isLoadingStream,
      builder: (context, isAudioLoading, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: ref.watch(storageServiceProvider).isLoadingNotifier,
          builder: (context, isStorageLoading, _) {
            final isLoading = isAudioLoading || isStorageLoading;
            if (!isLoading) return const SizedBox.shrink();
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNavBar(
    BuildContext context,
    WidgetRef ref,
    int selectedIndex,
    bool isPlayerExpanded,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final floatBottom = 12.0 + bottomPadding;
    final isSearchActive = selectedIndex == 1;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final showNavBar = !isPlayerExpanded && (!keyboardVisible || isSearchActive);

    return Positioned(
      left: 16,
      right: 16,
      bottom: floatBottom,
      height: 56,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: showNavBar ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !showNavBar,
          child: Row(
            children: [
              // Main pill: Home, Library, Settings OR Search input
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 20,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.20 : 0.35),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
                            width: 0.75,
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: isSearchActive
                              ? _buildSearchTextField(context, ref)
                              : _buildNavButtons(context, ref, selectedIndex),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Search circle / Home Button
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 20,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (isSearchActive) {
                          ref.read(navigationIndexProvider.notifier).state = 0; // Go to Home
                        } else {
                          ref.read(navigationIndexProvider.notifier).state = 1; // Search index
                          nestedNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.20 : 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.20),
                            width: 0.75,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(opacity: animation, child: child),
                                  );
                                },
                                child: isSearchActive
                                    ? Icon(
                                        FluentIcons.home_24_regular,
                                        key: const ValueKey('home_button_icon'),
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        size: 18,
                                      )
                                    : Icon(
                                        FluentIcons.search_24_regular,
                                        key: const ValueKey('search_button_icon'),
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        size: 18,
                                      ),
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildNavButtons(BuildContext context, WidgetRef ref, int selectedIndex) {
    return Row(
      key: const ValueKey('nav_buttons_row'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
          FluentIcons.people_community_24_regular,
          FluentIcons.people_community_24_filled,
          "Community",
          4,
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
          FluentIcons.settings_24_regular,
          FluentIcons.settings_24_filled,
          "Settings",
          3,
          selectedIndex,
        ),
      ],
    );
  }

  Widget _buildSearchTextField(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(searchControllerProvider);
    final focusNode = ref.watch(searchFocusNodeProvider);

    return Padding(
      key: const ValueKey('search_text_field'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: Theme.of(context).colorScheme.primary,
        decoration: InputDecoration(
          hintText: 'Search songs, albums, artists...',
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
          filled: false,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 0, right: 8),
            child: Icon(
              FluentIcons.search_24_regular,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                icon: Icon(
                  FluentIcons.dismiss_circle_24_filled,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 18,
                ),
                onPressed: () {
                  controller.clear();
                  focusNode.requestFocus();
                  ref.read(searchQueryProvider.notifier).state = '';
                },
              );
            },
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            ref.read(searchQueryProvider.notifier).state = value.trim();
            focusNode.unfocus();
          }
        },
      ),
    );
  }

  Widget _buildMiniPlayerPositioned(
    BuildContext context,
    WidgetRef ref,
    bool isDesktop,
  ) {
    final isPlayerExpandedVal = ref.watch(isPlayerExpandedProvider);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final bottomOffset = isDesktop
        ? 16.0
        : 76.0 + MediaQuery.of(context).padding.bottom;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final showMiniPlayer = !isPlayerExpandedVal && !keyboardVisible;

    return Positioned(
      left: isDesktop ? 24 : 16,
      right: isDesktop ? 24 : 16,
      bottom: bottomOffset,
      height: 50,
      child: Consumer(
        builder: (context, ref, _) {
          final mediaItemAsync = ref.watch(currentMediaItemProvider);

          return mediaItemAsync.maybeWhen(
            data: (mediaItem) {
              if (mediaItem == null) return const SizedBox.shrink();
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: showMiniPlayer ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !showMiniPlayer,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDarkTheme ? 0.35 : 0.12),
                          blurRadius: 20,
                          spreadRadius: -4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                        child: Container(
                          decoration: BoxDecoration(
                            color: (isDarkTheme ? Colors.black : Colors.white).withValues(alpha: isDarkTheme ? 0.20 : 0.35),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: isDarkTheme ? 0.12 : 0.20),
                              width: 0.75,
                            ),
                          ),
                          child: const MiniPlayer(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationIndexProvider);
    final storage = ref.watch(storageServiceProvider);
    final username = storage.username ?? 'User';

    String getInitials(String name) {
      final parts = name.trim().split(' ');
      if (parts.isEmpty) return 'U';
      if (parts.length == 1) {
        return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
      }
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }

    return SafeArea(
      right: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/logo.png',
                    height: 28,
                    width: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Muzo',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebarItem(
                    context,
                    ref,
                    iconRegular: FluentIcons.search_24_regular,
                    iconFilled: FluentIcons.search_24_filled,
                    label: "Search",
                    isSelected: selectedIndex == 1,
                    onTap: () {
                      ref.read(navigationIndexProvider.notifier).state = 1;
                      nestedNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                    },
                  ),
                  _buildSidebarItem(
                    context,
                    ref,
                    iconRegular: FluentIcons.home_24_regular,
                    iconFilled: FluentIcons.home_24_filled,
                    label: "Home",
                    isSelected: selectedIndex == 0,
                    onTap: () {
                      ref.read(navigationIndexProvider.notifier).state = 0;
                      nestedNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                    },
                  ),
                  _buildSidebarItem(
                    context,
                    ref,
                    iconRegular: FluentIcons.library_24_regular,
                    iconFilled: FluentIcons.library_24_filled,
                    label: "Library",
                    isSelected: selectedIndex == 2,
                    onTap: () {
                      ref.read(navigationIndexProvider.notifier).state = 2;
                      nestedNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                    },
                  ),
                  _buildSidebarItem(
                    context,
                    ref,
                    iconRegular: FluentIcons.people_community_24_regular,
                    iconFilled: FluentIcons.people_community_24_filled,
                    label: "Community",
                    isSelected: selectedIndex == 4,
                    onTap: () {
                      ref.read(navigationIndexProvider.notifier).state = 4;
                      nestedNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                    },
                  ),
                  _buildSidebarItem(
                    context,
                    ref,
                    iconRegular: FluentIcons.settings_24_regular,
                    iconFilled: FluentIcons.settings_24_filled,
                    label: "Settings",
                    isSelected: selectedIndex == 3,
                    onTap: () {
                      ref.read(navigationIndexProvider.notifier).state = 3;
                      nestedNavigatorKey.currentState?.popUntil((route) => route.isFirst);
                    },
                  ),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: ref.read(storageServiceProvider).isLoadingNotifier,
            builder: (context, isLoading, _) {
              if (isLoading) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Syncing...",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    "Cloud Library online",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }
            },
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              nestedNavigatorKey.currentState?.push(
                SlidePageRoute(page: const ProfileScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF8E8E93),
                      child: ClipOval(
                        child: Builder(
                        builder: (context) {
                          final avatarUrl = storage.avatarUrl;
                          final cachedSvg = storage.getUserAvatar();
                          final isSvg = avatarUrl == null ||
                              avatarUrl.contains('.svg') ||
                              avatarUrl.contains('dicebear');
                          if (isSvg && cachedSvg != null) {
                            return SvgPicture.string(
                              cachedSvg,
                              height: 36,
                              width: 36,
                              fit: BoxFit.cover,
                            );
                          }
                          if (avatarUrl != null && !isSvg) {
                            return CachedNetworkImage(
                              imageUrl: avatarUrl,
                              height: 36,
                              width: 36,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Text(
                                getInitials(username),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }
                          return Text(
                            getInitials(username),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      username,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context,
    WidgetRef ref, {
    required IconData iconRegular,
    required IconData iconFilled,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? iconFilled : iconRegular,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        if (index >= 0 && index <= 4) {
          ref.read(navigationIndexProvider.notifier).state = index;
          nestedNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      },
      child: Container(
        height: 48,
        alignment: Alignment.center,
        constraints: const BoxConstraints(minWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? RadialGradient(
                  colors: [
                    Theme.of(context).primaryColor.withValues(alpha: isDark ? 0.15 : 0.10),
                    Theme.of(context).primaryColor.withValues(alpha: 0.0),
                  ],
                  radius: 0.85,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? iconFilled : iconRegular,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              size: 18,
            ),
            const SizedBox(height: 0.5),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }


}

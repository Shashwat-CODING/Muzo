import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:ionicons/ionicons.dart';
import 'package:muzo/screens/lyrics_screen.dart';

class AlbumArtNLyrics extends ConsumerStatefulWidget {
  final double playerArtImageSize;
  const AlbumArtNLyrics({super.key, required this.playerArtImageSize});

  @override
  ConsumerState<AlbumArtNLyrics> createState() => _AlbumArtNLyricsState();
}

class _AlbumArtNLyricsState extends ConsumerState<AlbumArtNLyrics> {
  bool _isSwitchingLanguage = false;

  @override
  Widget build(BuildContext context) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final isLiteMode = ref.watch(settingsProvider).isLiteMode;

    final safeSize = widget.playerArtImageSize.clamp(10.0, double.infinity);

    return SizedBox( 
      width: safeSize,
      height: safeSize,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
             BoxShadow(
              color: Colors.black45,
              blurRadius: 20,
              offset: Offset(0, 10),
            )
          ]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              mediaItemAsync.when(
                data: (mediaItem) {
                  if (mediaItem?.artUri == null) return Container(color: Colors.grey[900]);
                  return CachedNetworkImage(
                    imageUrl: mediaItem!.artUri.toString(),
                    fit: BoxFit.cover,
                    width: widget.playerArtImageSize,
                    height: widget.playerArtImageSize,
                    errorWidget: (context, url, error) => const Icon(Icons.music_note, size: 50, color: Colors.white),
                  );
                },
                loading: () => Container(color: Colors.grey[900]),
                error: (_, __) => Container(color: Colors.grey[900], child: const Icon(Icons.error)),
              ),
              // Lyrics Button Overlay
              Positioned(
                bottom: 12,
                right: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: isLiteMode 
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                         child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                               final mediaItem = mediaItemAsync.value;
                               if (mediaItem != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => LyricsScreen(
                                        title: mediaItem.title,
                                        artist: mediaItem.artist ?? '',
                                        thumbnailUrl: mediaItem.artUri?.toString(),
                                        durationSeconds: mediaItem.duration?.inSeconds ?? 0,
                                      ),
                                    ),
                                  );
                               }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(FluentIcons.text_quote_20_filled, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Lyrics",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2), // Very less opacity
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                 final mediaItem = mediaItemAsync.value;
                                 if (mediaItem != null) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => LyricsScreen(
                                          title: mediaItem.title,
                                          artist: mediaItem.artist ?? '',
                                          thumbnailUrl: mediaItem.artUri?.toString(),
                                          durationSeconds: mediaItem.duration?.inSeconds ?? 0,
                                        ),
                                      ),
                                    );
                                 }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(FluentIcons.text_quote_20_filled, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    const Text(
                                      "Lyrics",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ),
              ),

              // Language Button Overlay
              mediaItemAsync.when(
                data: (mediaItem) {
                  final availableLanguages = (mediaItem?.extras?['availableLanguages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                  final currentLanguage = mediaItem?.extras?['currentLanguage'] as String? ?? 'Default';

                  if (availableLanguages.length <= 1) return const SizedBox.shrink();

                  return Positioned(
                    bottom: 12,
                    left: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: isLiteMode 
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Material(
                                color: Colors.transparent,
                                child: IgnorePointer(
                                  ignoring: _isSwitchingLanguage, 
                                  child: PopupMenuButton<String>(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    color: const Color(0xFF1E1E1E),
                                    offset: const Offset(0, -50),
                                    tooltip: 'Select Language',
                                    onSelected: (_) async {}, 
                                    itemBuilder: (context) {
                                        return availableLanguages.map((lang) {
                                          final name = lang['name'] as String;
                                          final url = lang['url'] as String;
                                          final isSelected = name == currentLanguage;
                                          
                                          return PopupMenuItem<String>(
                                            value: url,
                                            child: Row(
                                              children: [
                                                if (isSelected) 
                                                  const Icon(Icons.check, color: Colors.white, size: 16)
                                                else 
                                                  const SizedBox(width: 16),
                                                const SizedBox(width: 10),
                                                Text(name, style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
                                              ],
                                            ),
                                            onTap: () async {
                                              if (!isSelected) {
                                                 setState(() => _isSwitchingLanguage = true);
                                                 await ref.read(audioHandlerProvider).setAudioLanguage(url, name);
                                                 if (mounted) setState(() => _isSwitchingLanguage = false);
                                              }
                                            },
                                          );
                                        }).toList();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_isSwitchingLanguage)
                                            const SizedBox(
                                              width: 16, 
                                              height: 16, 
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                            )
                                          else
                                            const Icon(Ionicons.language, color: Colors.white, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            currentLanguage,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ),
                          )
                        : BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: IgnorePointer(
                                  ignoring: _isSwitchingLanguage,
                                  child: PopupMenuButton<String>(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    color: Colors.black.withOpacity(0.8), // Blurred background for menu too? Hard to do, use solid dark
                                    offset: const Offset(0, -50),
                                    tooltip: 'Select Language',
                                    itemBuilder: (context) {
                                        return availableLanguages.map((lang) {
                                          final name = lang['name'] as String;
                                          final url = lang['url'] as String;
                                          final isSelected = name == currentLanguage;
                                          
                                          return PopupMenuItem<String>(
                                            value: url,
                                            child: Row(
                                              children: [
                                                if (isSelected) 
                                                  const Icon(Icons.check, color: Colors.white, size: 16)
                                                else 
                                                  const SizedBox(width: 16),
                                                const SizedBox(width: 10),
                                                Text(name, style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
                                              ],
                                            ),
                                            onTap: () async {
                                              if (!isSelected) {
                                                 setState(() => _isSwitchingLanguage = true);
                                                 await ref.read(audioHandlerProvider).setAudioLanguage(url, name);
                                                 if (mounted) setState(() => _isSwitchingLanguage = false);
                                              }
                                            },
                                          );
                                        }).toList();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                           if (_isSwitchingLanguage)
                                            const SizedBox(
                                              width: 16, 
                                              height: 16, 
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                            )
                                          else
                                            const Icon(Ionicons.language, color: Colors.white, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            currentLanguage,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



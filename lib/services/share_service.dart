import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:muzo/services/audio_handler.dart';
import 'package:muzo/services/muzo_api_service.dart';

import 'package:muzo/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/main.dart'; // Just for container if needed

class ShareService {
  final AudioHandler _audioHandler;

  StreamSubscription? _intentDataStreamSubscription;

  ShareService(this._audioHandler);

  void init(BuildContext context) {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) return;

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              for (final file in value) {
                if (file.type == SharedMediaType.text ||
                    file.type == SharedMediaType.url) {
                  if (!context.mounted) return;
                  handleSharedText(context, file.path);
                } else {
                  // Fallback: sometimes path contains the URL even if type is not explicitly text/url?
                  // For now, let's assume path is the content.
                  // If it's a file path, _extractVideoId will likely return null.
                  if (!context.mounted) return;
                  handleSharedText(context, file.path);
                }
              }
            }
          },
          onError: (err) {
            debugPrint("getMediaStream error: $err");
          },
        );

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        for (final file in value) {
          // Same logic
          if (!context.mounted) return;
          handleSharedText(context, file.path);
        }
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }

  Future<void> handleSharedText(BuildContext context, String text) async {
    debugPrint('Shared text/url received: $text');

    // Use ProviderScope to get storage service since we are in a widget tree
    final storage = ProviderScope.containerOf(
      context,
    ).read(storageServiceProvider);
    final handleAppLinks = storage.handleAppLinks;
    final videoId = _extractVideoId(text);

    if (videoId != null && !handleAppLinks) {
      // Toggle is off - don't intercept it, just launch it externally
      debugPrint(
        'Deep link intercept is disabled. Redirecting to external browser.',
      );
      final uri = Uri.tryParse(text);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (videoId != null) {
      showGlassSnackBar(context, 'Fetching shared video...');

      // As per user request, fetch video details from the related API,
      // and take the first item as it typically matches the requested song with rich metadata.
      MuzoItem? video;
      try {
        final musicApiService = ProviderScope.containerOf(
          context,
        ).read(muzoApiServiceProvider);
        final related = await musicApiService.getUpNext(videoId);
        if (related.isNotEmpty) {
          // The first related item is usually the song itself
          video = related.first;
        }
      } catch (e) {
        debugPrint('Error fetching related for metadata: $e');
      }



      if (video != null) {
        _audioHandler.playVideo(video);
      } else {
        if (!context.mounted) return;
        showGlassSnackBar(context, 'Could not find video details');
        // Fallback: try playing with just ID
        final dummyResult = MuzoItem(
          videoId: videoId,
          title: 'Shared Video',
          artists: [MuzoArtist(name: 'Unknown', id: '')],
          thumbnails: [],
          duration: '0:00',
          resultType: 'video',
          isExplicit: false,
        );
        _audioHandler.playVideo(dummyResult);
      }
    } else {
      // showGlassSnackBar(context, 'No YouTube video found in shared text');
    }
  }

  String? _extractVideoId(String text) {
    // Regex for YouTube URLs
    // Supports:
    // youtube.com/watch?v=ID
    // youtu.be/ID
    // music.youtube.com/watch?v=ID
    // music.youtube.com/playlist?v=ID (sometimes shared this way)
    // youtube.com/shorts/ID

    final RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/|music\.youtube\.com\/(?:watch\?v=|playlist\?v=|.*[?&]v=))([^"&?\/\s]{11})',
      caseSensitive: false,
      multiLine: false,
    );

    final match = regExp.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }
}

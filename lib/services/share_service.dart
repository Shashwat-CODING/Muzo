import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:ytx/services/audio_handler.dart';
import 'package:ytx/services/youtube_api_service.dart';
import 'package:ytx/models/ytify_result.dart';
import 'package:ytx/widgets/glass_snackbar.dart';

class ShareService {
  final AudioHandler _audioHandler;
  final YouTubeApiService _apiService = YouTubeApiService();
  StreamSubscription? _intentDataStreamSubscription;

  ShareService(this._audioHandler);

  void init(BuildContext context) {
    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        for (final file in value) {
          if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
             _handleSharedText(context, file.path);
          } else {
            // Fallback: sometimes path contains the URL even if type is not explicitly text/url?
            // For now, let's assume path is the content.
            // If it's a file path, _extractVideoId will likely return null.
            _handleSharedText(context, file.path);
          }
        }
      }
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        for (final file in value) {
           // Same logic
           _handleSharedText(context, file.path);
        }
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }

  Future<void> _handleSharedText(BuildContext context, String text) async {
    debugPrint('Shared text received: $text');
    
    final videoId = _extractVideoId(text);
    if (videoId != null) {
      showGlassSnackBar(context, 'Fetching shared video...');
      
      // Fetch video details to get title, author, thumbnail
      final response = await _apiService.search(videoId, filter: 'videos');
      
      if (response.results.isNotEmpty) {
        // Ideally the first result is the video itself if we searched by ID
        final video = response.results.first;
        // Verify it matches the ID roughly or just trust the search
        // (Search by ID usually returns the exact video first)
        
        _audioHandler.playVideo(video);
      } else {
        showGlassSnackBar(context, 'Could not find video details');
        // Fallback: try playing with just ID if possible, but playVideo expects YtifyResult for history
        // We can construct a dummy result
        final dummyResult = YtifyResult(
          videoId: videoId,
          title: 'Shared Video',
          artists: [YtifyArtist(name: 'Unknown')],
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
    // youtube.com/shorts/ID
    
    final RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
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

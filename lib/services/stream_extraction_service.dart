import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter_new_pipe_extractor/flutter_new_pipe_extractor.dart';

class StreamExtractionService {
  /// Extracts the best audio stream URL using the fastest YoutubeExplode method with Android VR client
  /// Falls back to NewPipeExtractor if YoutubeExplode fails.
  static Future<String?> getStreamUrl(String videoId) async {
    // 1. YoutubeExplode (Android VR Client)
    final yt = YoutubeExplode();
    try {
      debugPrint('FastExtraction: Extracting stream for $videoId');
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );

      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        final bestAudio = audioStreams.withHighestBitrate();
        debugPrint('FastExtraction: Found stream - ${bestAudio.url}');
        return bestAudio.url.toString();
      } else {
        debugPrint('FastExtraction: No audio streams found via YoutubeExplode.');
      }
    } catch (e) {
      debugPrint("FastExtraction Error (YoutubeExplode): $e");
    } finally {
      yt.close();
    }

    // 2. NewPipeExtractor Fallback (Android only)
    if (Platform.isAndroid) {
      debugPrint('FastExtraction: Falling back to NewPipeExtractor...');
      try {
        final info = await NewPipeExtractor.getVideoInfo(
          'https://www.youtube.com/watch?v=$videoId',
        ).timeout(const Duration(seconds: 5));
        
        if (info.audioStreams.isNotEmpty) {
          final stream = info.audioStreams.reduce(
            (a, b) => a.bitrate > b.bitrate ? a : b,
          );
          if (stream.content.isNotEmpty) {
            debugPrint('FastExtraction: Stream URL via NewPipe: ${stream.content}');
            return stream.content;
          }
        }
      } catch (e) {
        debugPrint('FastExtraction: NewPipeExtractor failed: $e');
      }
    }

    debugPrint('FastExtraction: All primary extraction methods failed.');
    return null;
  }
}

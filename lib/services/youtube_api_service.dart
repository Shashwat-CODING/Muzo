import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/services/storage_service.dart';
import 'dart:convert';

class YtifySearchResponse {
  final List<YtifyResult> results;
  final String? continuationToken;

  YtifySearchResponse({required this.results, this.continuationToken});
}

class YouTubeApiService {
  final _yt = YoutubeExplode();
  final _client = http.Client();

  Future<void> dispose() async {
    _yt.close();
    _client.close();
  }

  Future<String?> getStreamUrl(
    String videoId, {
    String? title,
    String? artist,
    VoidCallback? onFallback,
  }) async {
    // 0. Web Platform Check: Bypass library entirely on web
    if (kIsWeb) {
      debugPrint('Web platform detected: bypassing package:youtube_explode_dart');
      return await _getFallbackStreamUrl(videoId, title, artist);
    }

    try {
      debugPrint('Extracting stream for videoId: $videoId...');
      
      // 1. Get the stream manifest (contains all available formats)
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.tv,
          YoutubeApiClient.androidVr,
        ],
      );
      
      // 2. Filter for audio-only streams
      final audioStreams = manifest.audioOnly;
      
      if (audioStreams.isEmpty) {
        debugPrint("No audio streams found for this video.");
        onFallback?.call();
        return await _getFallbackStreamUrl(videoId, title, artist);
      }

      // 3. Select the best stream 
      final bestStream = audioStreams.withHighestBitrate();
      
      // 4. Extract the direct URL
      final streamUrl = bestStream.url.toString();
      
      _logLong('Stream URL extracted: $streamUrl');
      return streamUrl;
    } catch (e) {
      debugPrint("Error extracting stream: $e");
      onFallback?.call();
      return await _getFallbackStreamUrl(videoId, title, artist);
    }
  }

  void _logLong(String text) {
    final pattern = RegExp('.{1,800}');
    pattern.allMatches(text).forEach((match) => debugPrint(match.group(0)));
  }

  Future<String?> _getFallbackStreamUrl(
    String videoId,
    String? title,
    String? artist,
  ) async {
    final invidiousInstances = [
      'inv-veltrix-3.zeabur.app',
      'inv-veltrix-2.zeabur.app',
      'inv-veltrix.zeabur.app',
    ];

    for (final instance in invidiousInstances) {
      try {
        debugPrint('Using Invidious instance: $instance for videoId: $videoId');
        final uri = Uri.parse('https://$instance/api/v1/videos/$videoId');

        final response = await http.get(uri);

        if (response.statusCode != 200) {
          debugPrint('Invidious ($instance) returned status: ${response.statusCode}');
          continue; // Try next instance
        }

        final data = jsonDecode(response.body);
        final adaptiveFormats = data['adaptiveFormats'] as List?;

        if (adaptiveFormats == null) continue;

        String? bestUrl;
        int bestBitrate = 0;

        for (final format in adaptiveFormats) {
          final type = format['type'] as String?;
          final url = format['url'] as String?;
          // bitrate can be string or int in JSON, safer to handle both or clean plain string
          final bitrateVal = format['bitrate'];
          int bitrate = 0;
          if (bitrateVal is int) {
            bitrate = bitrateVal;
          } else if (bitrateVal is String) {
            bitrate = int.tryParse(bitrateVal) ?? 0;
          }

          if (type != null && type.startsWith('audio/') && url != null) {
            if (bitrate > bestBitrate) {
              bestBitrate = bitrate;
              bestUrl = url;
            }
          }
        }

        if (bestUrl != null) {
          // Proxy logic: Replace host with CURRENT Invidious base URL
          try {
            final originalUri = Uri.parse(bestUrl);
            final proxiedUri = originalUri.replace(
              scheme: 'https',
              host: instance,
            );
            return proxiedUri.toString();
          } catch (e) {
            debugPrint("Error parsing/proxying URL: $e");
            return bestUrl; // Return original if proxying fails
          }
        }
      } catch (e) {
        debugPrint("Error in Invidious fallback ($instance): $e");
        continue; // Try next instance
      }
    }
    return null;
  }

  Future<YtifyResult?> _getFallbackVideoDetails(String videoId) async {
    final invidiousInstances = [
      'inv-veltrix-3.zeabur.app',
      'inv-veltrix-2.zeabur.app',
      'inv-veltrix.zeabur.app',
    ];

    for (final instance in invidiousInstances) {
      try {
        final uri = Uri.parse('https://$instance/api/v1/videos/$videoId');
        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          final title = data['title'] ?? 'Unknown Title';
          final author = data['author'] ?? 'Unknown Artist';
          final authorId = data['authorId'] ?? '';
          final lengthSeconds = data['lengthSeconds'] ?? 0;
          
          // Thumbnails
          String thumbnail = '';
          final thumbnails = data['videoThumbnails'] as List?;
          if (thumbnails != null && thumbnails.isNotEmpty) {
             // Try to find reasonable quality
             thumbnail = thumbnails.last['url'] ?? ''; 
          }

          final duration = Duration(seconds: lengthSeconds);
          String twoDigits(int n) => n.toString().padLeft(2, "0");
          final durationString = "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";

          return YtifyResult(
            videoId: videoId,
            title: title,
            artists: [YtifyArtist(name: author, id: authorId)],
            thumbnails: [YtifyThumbnail(url: thumbnail, width: 480, height: 360)],
            duration: durationString,
            resultType: 'video',
            isExplicit: false,
          );
        }
      } catch (e) {
        debugPrint('Error getting fallback details from $instance: $e');
        continue;
      }
    }
    return null;
  }

  Future<YtifySearchResponse> search(
    String query, {
    String filter = 'songs',
    String? continuationToken,
  }) async {
    try {
      Uri uri;
      final queryParams = {'q': query, 'filter': filter};
      if (continuationToken != null) queryParams['continuationToken'] = continuationToken;

      if (filter == 'videos' || filter == 'channels') {
        uri = Uri.parse('https://ytify-backend.vercel.app/api/yt_search').replace(queryParameters: queryParams);
      } else if (filter == 'albums') {
        uri = Uri.parse('https://ytify-backend.vercel.app/api/search').replace(queryParameters: queryParams);
      } else {
        uri = Uri.parse('https://heujjsnxhjptqmanwadg.supabase.co/functions/v1/hyper-task').replace(queryParameters: queryParams);
      }

      final response = await http.get(uri);
      if (response.statusCode != 200) return YtifySearchResponse(results: []);

      final data = jsonDecode(response.body);
      final resultsJson = data['results'] as List?;
      final token = data['continuationToken'] as String?;

      if (resultsJson == null) return YtifySearchResponse(results: []);

      final results = resultsJson.map((json) => YtifyResult.fromJson(json)).toList();
      return YtifySearchResponse(results: results, continuationToken: token);
    } catch (e) {
      return YtifySearchResponse(results: []);
    }
  }

  Future<List<YtifyResult>> getChannelVideos(String channelId) async {
    try {
      final uri = Uri.parse('https://ytify-backend.vercel.app/api/feed/channels=$channelId');
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => YtifyResult.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<YtifyResult>> getSubscriptionsFeed(List<String> channelIds) async {
    if (channelIds.isEmpty) return [];
    try {
      final ids = channelIds.join(',');
      final uri = Uri.parse('https://ytify-backend.vercel.app/api/feed/channels=$ids').replace(queryParameters: {'preview': '1'});
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => YtifyResult.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final uri = Uri.parse('https://ytify-backend.vercel.app/api/search/suggestions').replace(queryParameters: {'q': query, 'music': '1'});
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final suggestions = data['suggestions'] as List?;
      if (suggestions == null) return [];
      return suggestions.map((s) => s.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<YtifyResult>> getRelatedVideos(String videoId) async {
    try {
      final uri = Uri.parse('https://ytify-backend.vercel.app/api/related/$videoId');
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data['success'] != true) return [];
      final resultsJson = data['data'] as List?;
      if (resultsJson == null) return [];
      return resultsJson.map((json) => YtifyResult.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, List<YtifyResult>>> getTrendingContent() async {
    try {
      final uri = Uri.parse('https://ytify-backend.vercel.app/api/trending');
      final response = await http.get(uri);
      if (response.statusCode != 200) return {'songs': [], 'videos': [], 'playlists': []};
      final data = jsonDecode(response.body);
      if (data['success'] != true || data['data'] == null) return {'songs': [], 'videos': [], 'playlists': []};
      final content = data['data'];
      List<YtifyResult> parseList(String key, {String? forceType}) {
        final list = content[key] as List?;
        if (list == null) return [];
        return list.map((json) {
          final map = Map<String, dynamic>.from(json);
          if (forceType != null) map['resultType'] = forceType;
          return YtifyResult.fromJson(map);
        }).toList();
      }
      return {
        'songs': parseList('songs'),
        'videos': parseList('videos'),
        'playlists': parseList('playlists', forceType: 'playlist'),
      };
    } catch (e) {
      return {'songs': [], 'videos': [], 'playlists': []};
    }
  }

  Future<YtifyResult?> getVideoDetails(String videoId) async {
    // 0. Web Platform Check: Bypass library entirely on web
    if (kIsWeb) {
       return await _getFallbackVideoDetails(videoId);
    }
    try {
      final video = await _yt.videos.get(videoId);
      final thumbnails = [YtifyThumbnail(url: video.thumbnails.highResUrl, width: 480, height: 360)];
      final duration = video.duration ?? Duration.zero;
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      final durationString = "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
      return YtifyResult(
        videoId: video.id.value,
        title: video.title,
        artists: [YtifyArtist(name: video.author, id: video.channelId.value)],
        thumbnails: thumbnails,
        duration: durationString,
        resultType: 'video',
        isExplicit: false,
      );
    } catch (e) {
      // Also fallback if library fails on other platforms (optional but good consistency)
      return await _getFallbackVideoDetails(videoId);
    }
  }
}

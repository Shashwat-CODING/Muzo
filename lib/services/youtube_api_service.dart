import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzoapi/youtube_stream_provider.dart';

class YtifySearchResponse {
  final List<YtifyResult> results;
  final String? continuationToken;

  YtifySearchResponse({required this.results, this.continuationToken});
}

class YouTubeApiService {
  static const String _baseUrl = 'https://youtubei.googleapis.com/youtubei/v1/';
  static const String _apiKey = 'AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w';
  static const String _referer = 'https://www.youtube.com/';
  static const String _userAgent = 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Mobile Safari/537.36';
  static const String _clientName = 'ANDROID';
  static const String _clientVersion = '19.17.34';
  static const int _clientId = 3;

  final _ytHelper = InnerTube();

  Future<StreamInfo?> getStreamManifest(String videoId) async {
    try {
      return await _ytHelper.player(videoId);
    } catch (e) {
      debugPrint('Error fetching stream manifest: $e');
      return null;
    }
  }

  Future<String?> getStreamUrl(String videoId, {String? title, String? artist, VoidCallback? onFallback}) async {
    try {
      final url = Uri.parse('${_baseUrl}player?key=$_apiKey');
      final headers = {
        'X-Goog-Api-Format-Version': '1',
        'X-YouTube-Client-Name': _clientId.toString(),
        'X-YouTube-Client-Version': _clientVersion,
        'User-Agent': _userAgent,
        'Referer': _referer,
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'context': {
          'client': {
            'clientName': _clientName,
            'clientVersion': _clientVersion,
            'clientId': _clientId,
            'userAgent': _userAgent,
          }
        },
        'videoId': videoId,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        debugPrint('YouTube API Error: ${response.statusCode}');
        onFallback?.call();
        return await _getFallbackStreamUrl(videoId, title, artist);
      }

      final data = jsonDecode(response.body);
      
      final playabilityStatus = data['playabilityStatus'];
      if (playabilityStatus?['status'] != 'OK') {
        final reason = playabilityStatus?['reason'] ?? 'Unknown error';
        debugPrint('Video not playable: $reason');
        onFallback?.call();
        return await _getFallbackStreamUrl(videoId, title, artist);
      }

      final streamingData = data['streamingData'];
      if (streamingData == null) {
        debugPrint('No streaming data found for video: $videoId');
        onFallback?.call();
        return await _getFallbackStreamUrl(videoId, title, artist);
      }

      // Get formats and adaptiveFormats
      final formats = streamingData['formats'] as List<dynamic>?;
      final adaptiveFormats = streamingData['adaptiveFormats'] as List<dynamic>?;

      // Combine all formats
      final allFormats = <Map<String, dynamic>>[];
      if (formats != null) allFormats.addAll(formats.cast<Map<String, dynamic>>());
      if (adaptiveFormats != null) allFormats.addAll(adaptiveFormats.cast<Map<String, dynamic>>());

      debugPrint('Found ${allFormats.length} formats');

      // Find the best audio-only format
      String? bestAudioUrl;
      int bestBitrate = 0;

      for (final format in allFormats) {
        final mimeType = format['mimeType'] as String?;
        final url = format['url'] as String?;
        final bitrate = format['bitrate'] as int?;

        // Look for audio-only formats (audio/mp4, audio/webm, etc.)
        if (mimeType != null && 
            mimeType.startsWith('audio/') && 
            url != null && 
            bitrate != null) {
          if (bitrate > bestBitrate) {
            bestBitrate = bitrate;
            bestAudioUrl = url;
          }
        }
      }

      if (bestAudioUrl != null) {
        return bestAudioUrl;
      }

      debugPrint('No suitable audio stream found for video: $videoId');
      onFallback?.call();
      return await _getFallbackStreamUrl(videoId, title, artist);

    } catch (e, stackTrace) {
      debugPrint('Error fetching stream info for video: $videoId');
      debugPrint('Exception: $e');
      onFallback?.call();
      return await _getFallbackStreamUrl(videoId, title, artist);
    }
  }

  Future<String?> _getFallbackStreamUrl(String videoId, String? title, String? artist) async {
    try {
      // Access key and country code via singleton
      final apiKey = StorageService().rapidApiKey;
      final countryCode = StorageService().rapidApiCountryCode;
      
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('RapidAPI Key not set. Fallback disabled.');
        return null;
      }

      debugPrint('Attempting RapidAPI fallback for $videoId with cgeo=$countryCode');
      
      final uri = Uri.parse('https://yt-api.p.rapidapi.com/dl').replace(queryParameters: {
        'id': videoId,
        'cgeo': countryCode.isNotEmpty ? countryCode : 'IN',
      });

      final response = await http.get(uri, headers: {
        'x-rapidapi-host': 'yt-api.p.rapidapi.com',
        'x-rapidapi-key': apiKey,
      });

      if (response.statusCode != 200) {
        debugPrint('RapidAPI Error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') {
        debugPrint('RapidAPI Status: ${data['status']}');
        return null;
      }

      // Parse adaptiveFormats for best audio
      final adaptiveFormats = data['adaptiveFormats'] as List?;
      if (adaptiveFormats == null) return null;

      String? bestUrl;
      int bestBitrate = 0;

      for (final format in adaptiveFormats) {
        final mimeType = format['mimeType'] as String?;
        final bitrate = format['bitrate'] as int?;
        final url = format['url'] as String?;

        if (mimeType != null && mimeType.startsWith('audio/') && url != null && bitrate != null) {
           if (bitrate > bestBitrate) {
             bestBitrate = bitrate;
             bestUrl = url;
           }
        }
      }

      return bestUrl;
    } catch (e) {
      debugPrint('RapidAPI Exception: $e');
      return null;
    }
  }



  Future<YtifySearchResponse> search(String query, {String filter = 'songs', String? continuationToken}) async {
    try {
      Uri uri;
      final queryParams = {
        'q': query,
        'filter': filter,
      };
      
      if (continuationToken != null) {
        queryParams['continuationToken'] = continuationToken;
      }

      if (filter == 'videos' || filter == 'channels') {
        uri = Uri.parse('https://ytify-backend.vercel.app/api/yt_search').replace(queryParameters: queryParams);
      } else {
        uri = Uri.parse('https://heujjsnxhjptqmanwadg.supabase.co/functions/v1/hyper-task').replace(queryParameters: queryParams);
      }

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('Ytify Search Error: ${response.statusCode}');
        return YtifySearchResponse(results: []);
      }

      final data = jsonDecode(response.body);
      final resultsJson = data['results'] as List?;
      final token = data['continuationToken'] as String?;

      if (resultsJson == null) return YtifySearchResponse(results: []);

      final results = resultsJson.map((json) => YtifyResult.fromJson(json)).toList();
      return YtifySearchResponse(results: results, continuationToken: token);
    } catch (e) {
      debugPrint('Error searching: $e');
      return YtifySearchResponse(results: []);
    }
  }

  Future<List<YtifyResult>> getChannelVideos(String channelId) async {
    try {
      final uri = Uri.parse('https://ytify-backend.vercel.app/api/feed/channels=$channelId');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('Ytify Channel Videos Error: ${response.statusCode}');
        return [];
      }

      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => YtifyResult.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching channel videos: $e');
      return [];
    }
  }

  Future<List<YtifyResult>> getSubscriptionsFeed(List<String> channelIds) async {
    if (channelIds.isEmpty) return [];
    try {
      final ids = channelIds.join(',');
      final uri = Uri.parse('https://ytify-backend.vercel.app/api/feed/channels=$ids').replace(queryParameters: {
        'preview': '1',
      });
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('Ytify Subscriptions Feed Error: ${response.statusCode}');
        return [];
      }

      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => YtifyResult.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching subscriptions feed: $e');
      return [];
    }
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final uri = Uri.parse('https://heujjsnxhjptqmanwadg.supabase.co/functions/v1/ytmusic-search/suggestions').replace(queryParameters: {
        'q': query,
        'music': '1',
      });

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('Ytify Suggestions Error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      final suggestions = data['suggestions'] as List?;

      if (suggestions == null) return [];

      return suggestions.map((s) => s.toString()).toList();
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      return [];
    }
  }

  Future<List<YtifyResult>> getRelatedVideos(String videoId) async {
    try {
      final uri = Uri.parse('https://ytify-backend.vercel.app/api/related/$videoId');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('Ytify Related Videos Error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        return [];
      }

      final resultsJson = data['data'] as List?;
      if (resultsJson == null) return [];

      return resultsJson.map((json) => YtifyResult.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching related videos: $e');
      return [];
    }
  }
  Future<Map<String, List<YtifyResult>>> getTrendingContent() async {
    try {
      final uri = Uri.parse('https://ytify-backend.vercel.app/api/trending');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('Ytify Trending Error: ${response.statusCode}');
        return {'songs': [], 'videos': [], 'playlists': []};
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true || data['data'] == null) {
        return {'songs': [], 'videos': [], 'playlists': []};
      }

      final content = data['data'];
      
      List<YtifyResult> parseList(String key, {String? forceType}) {
        final list = content[key] as List?;
        if (list == null) return [];
        return list.map((json) {
          final map = Map<String, dynamic>.from(json);
          if (forceType != null) {
            map['resultType'] = forceType;
          }
          return YtifyResult.fromJson(map);
        }).toList();
      }

      return {
        'songs': parseList('songs'),
        'videos': parseList('videos'),
        'playlists': parseList('playlists', forceType: 'playlist'),
      };
    } catch (e) {
      debugPrint('Error fetching trending content: $e');
      return {'songs': [], 'videos': [], 'playlists': []};
    }
  }
  Future<YtifyResult?> getVideoDetails(String videoId) async {
    try {
      final url = Uri.parse('${_baseUrl}player?key=$_apiKey');
      final headers = {
        'X-Goog-Api-Format-Version': '1',
        'X-YouTube-Client-Name': _clientId.toString(),
        'X-YouTube-Client-Version': _clientVersion,
        'User-Agent': _userAgent,
        'Referer': _referer,
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'context': {
          'client': {
            'clientName': _clientName,
            'clientVersion': _clientVersion,
            'clientId': _clientId,
            'userAgent': _userAgent,
          }
        },
        'videoId': videoId,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        debugPrint('YouTube API Error (getVideoDetails): ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final videoDetails = data['videoDetails'];
      
      if (videoDetails == null) {
        debugPrint('No videoDetails found for: $videoId');
        return null;
      }

      final thumbnails = (videoDetails['thumbnail']?['thumbnails'] as List?)
          ?.map((t) => YtifyThumbnail(
                url: t['url'],
                width: t['width'] ?? 0,
                height: t['height'] ?? 0,
              ))
          .toList() ?? [];

      // Ensure we have at least one thumbnail
      if (thumbnails.isEmpty) {
        thumbnails.add(YtifyThumbnail(
          url: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
          width: 480,
          height: 360,
        ));
      }

      final durationSeconds = int.tryParse(videoDetails['lengthSeconds'] ?? '0') ?? 0;
      final duration = Duration(seconds: durationSeconds);
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
      String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
      final durationString = "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$twoDigitMinutes:$twoDigitSeconds";

      return YtifyResult(
        videoId: videoDetails['videoId'],
        title: videoDetails['title'] ?? 'Unknown Title',
        artists: [YtifyArtist(name: videoDetails['author'] ?? 'Unknown Artist', id: '')],
        thumbnails: thumbnails,
        duration: durationString,
        resultType: 'video',
        isExplicit: false,
      );
    } catch (e) {
      debugPrint('Error fetching video details: $e');
      return null;
    }
  }
}

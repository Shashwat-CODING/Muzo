import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:muzo/models/ytify_result.dart';
import 'dart:convert';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YtifySearchResponse {
  final List<YtifyResult> results;
  final String? continuationToken;

  YtifySearchResponse({required this.results, this.continuationToken});
}

class YouTubeApiService {
  bool _enableFallbackApi = false; // Flag to enable/disable Invidious fallback

  final _client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  // Singleton YoutubeExplode session — created once, reused for all requests.
  static final YoutubeExplode _yt = YoutubeExplode();

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  Future<void> dispose() async {
    _client.close();
    _yt.close();
  }

  Future<String?> getStreamUrl(
    String videoId, {
    String? title,
    String? artist,
    VoidCallback? onFallback,
  }) async {
    // 0. Web Platform Check: Bypass library entirely on web
    if (kIsWeb) {
      debugPrint('Web platform detected: bypassing ANDROID_VR client');
      if (_enableFallbackApi) {
        return await _getFallbackStreamUrl(videoId, title, artist);
      } else {
        throw Exception("Failed to extract stream on Web. Fallback is disabled.");
      }
    }

    // Direct API: try up to 2 times before falling back
    debugPrint('Extracting stream for videoId: $videoId (attempt 1)...');
    String? streamUrl = await _tryDirectApi(videoId);
    if (streamUrl == null) {
      debugPrint('Direct API attempt 1 failed, retrying...');
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('Direct API attempt 2...');
      streamUrl = await _tryDirectApi(videoId);
    }

    if (streamUrl != null) {
      _logLong('Stream URL extracted directly: $streamUrl');
      return streamUrl;
    }

    debugPrint('Both direct API attempts failed — trying YoutubeExplode...');
    onFallback?.call();

    // Fallback 1: YoutubeExplode (singleton session — no new instance created)
    for (int i = 1; i <= 2; i++) {
      debugPrint('YoutubeExplode attempt $i...');
      try {
        final provider = await StreamProvider.fetch(videoId, _yt);
        if (provider.playable) {
          final url = provider.highestBitrateMp4aAudio?.url ??
              provider.highestQualityAudio?.url ??
              provider.audioFormats?.first.url;
          if (url != null) {
            _logLong('Stream URL extracted via YoutubeExplode: $url');
            return url;
          }
        } else {
          debugPrint('YoutubeExplode status: ${provider.statusMSG}');
        }
      } catch (ye) {
        debugPrint('Error in YoutubeExplode fallback attempt $i: $ye');
      }
      if (i == 1) await Future.delayed(const Duration(milliseconds: 500));
    }

    // Fallback 2: Invidious Instances
    if (_enableFallbackApi) {
      debugPrint('Trying Invidious Fallback...');
      return await _getFallbackStreamUrl(videoId, title, artist);
    } else {
      debugPrint('Invidious Fallback is disabled.');
      throw Exception("Failed to extract stream. Consider signing in or check your connection.");
    }
  }



  /// Attempts a single direct YouTube player API POST call.
  /// Returns the best stream URL on success, or null on any failure.
  Future<String?> _tryDirectApi(String videoId) async {
    try {
      final url = Uri.parse('https://www.youtube.com/youtubei/v1/player');
      final body = {
        'context': {
          'client': {
            'clientName': 'ANDROID',
            'clientVersion': '19.09.37',
            'androidSdkVersion': 33,
            'userAgent':
                'com.google.android.youtube/19.09.37 (Linux; U; Android 13) gzip',
            'osName': 'Android',
            'osVersion': '13',
            'hl': 'en',
            'gl': 'US',
          }
        },
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      };

      final response = await _client.post(
        url.toString(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'com.google.android.youtube/19.09.37 (Linux; Android 13)',
          },
          validateStatus: (status) => true,
        ),
        data: body,
      );

      if (response.statusCode != 200) return null;

      final data = response.data as Map<String, dynamic>;
      if (data['playabilityStatus']?['status'] != 'OK') return null;

      final streamingData = data['streamingData'] as Map<String, dynamic>?;
      if (streamingData == null) return null;

      // Prefer muxed formats (audio+video) first
      final formats = streamingData['formats'] as List?;
      if (formats != null) {
        for (final fmt in formats) {
          final u = fmt['url'] as String?;
          if (u != null) return u;
        }
      }

      // Fall back to adaptive audio-only formats
      final adaptive = streamingData['adaptiveFormats'] as List?;
      if (adaptive != null) {
        for (final fmt in adaptive) {
          final u = fmt['url'] as String?;
          if (u != null) return u;
        }
      }

      return null;
    } catch (e) {
      debugPrint('_tryDirectApi error: $e');
      return null;
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
      'ubiquitous-rugelach-b30b3f.netlify.app',
      'super-duper-system.netlify.app',
      'crispy-octo-waddle.netlify.app',
      'www.gcx.co.in',
    ];

    for (final instance in invidiousInstances) {
      try {
        debugPrint(
            'Using Invidious instance: $instance for videoId: $videoId');
        final uri = Uri.parse('https://$instance/api/v1/videos/$videoId');

        final response = await _client.get(
          uri.toString(),
          options: Options(validateStatus: (status) => true),
        );

        if (response.statusCode != 200) {
          debugPrint(
              'Invidious ($instance) returned status: ${response.statusCode}');
          continue;
        }

        final data = response.data;
        final adaptiveFormats = data['adaptiveFormats'] as List?;

        if (adaptiveFormats == null) continue;

        String? bestUrl;
        int bestBitrate = 0;

        for (final format in adaptiveFormats) {
          final type =
              (format['mimeType'] ?? format['type']) as String?;
          final url = format['url'] as String?;
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
          try {
            final originalUri = Uri.parse(bestUrl);
            final proxiedUri = originalUri.replace(
              scheme: 'https',
              host: instance,
            );
            return proxiedUri.toString();
          } catch (e) {
            debugPrint("Error parsing/proxying URL: $e");
            return bestUrl;
          }
        }
      } catch (e) {
        debugPrint("Error in Invidious fallback ($instance): $e");
        continue;
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
        final uri =
            Uri.parse('https://$instance/api/v1/videos/$videoId');
        final response = await _client.get(
          uri.toString(),
          options: Options(validateStatus: (status) => true),
        );

        if (response.statusCode == 200) {
          final data = response.data;

          final title = data['title'] ?? 'Unknown Title';
          final author =
              data['channelTitle'] ?? data['author'] ?? 'Unknown Artist';
          final authorId = data['channelId'] ?? data['authorId'] ?? '';

          final lengthSecsRaw = data['lengthSeconds'];
          int lengthSeconds = 0;
          if (lengthSecsRaw is int) {
            lengthSeconds = lengthSecsRaw;
          } else if (lengthSecsRaw is String) {
            lengthSeconds = int.tryParse(lengthSecsRaw) ?? 0;
          }

          String thumbnail = '';
          final thumbnails =
              (data['thumbnail'] ?? data['videoThumbnails']) as List?;
          if (thumbnails != null && thumbnails.isNotEmpty) {
            final lastThumb = thumbnails.last;
            if (lastThumb is Map) {
              thumbnail = lastThumb['url'] ?? '';
            } else if (lastThumb is String) {
              thumbnail = lastThumb;
            }
          }

          final duration = Duration(seconds: lengthSeconds);
          String twoDigits(int n) => n.toString().padLeft(2, "0");
          final durationString =
              "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";

          return YtifyResult(
            videoId: videoId,
            title: title,
            artists: [YtifyArtist(name: author, id: authorId)],
            thumbnails: [
              YtifyThumbnail(url: thumbnail, width: 480, height: 360)
            ],
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
      if (continuationToken != null) {
        queryParams['continuationToken'] = continuationToken;
      }

      if (filter == 'videos' || filter == 'channels') {
        uri = Uri.parse('https://ytify-backend.zeabur.app/api/yt_search')
            .replace(queryParameters: queryParams);
      } else if (filter == 'albums') {
        uri = Uri.parse('https://ytify-backend.zeabur.app/api/search')
            .replace(queryParameters: queryParams);
      } else {
        // songs, playlists, etc. → use the correct ytmusic-search endpoint
        uri = Uri.parse(
                'https://heujjsnxhjptqmanwadg.supabase.co/functions/v1/ytmusic-search')
            .replace(queryParameters: queryParams);
      }

      debugPrint('YOUTUBE_API SEARCH Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(
          headers: _headers,
          validateStatus: (status) => true,
        ),
      );
      debugPrint('YOUTUBE_API SEARCH Response [${response.statusCode}]');
      debugPrint('YOUTUBE_API SEARCH RAW: ${response.data.toString().substring(0, (response.data.toString().length > 300) ? 300 : response.data.toString().length)}');
      if (response.statusCode != 200) {
        return YtifySearchResponse(results: []);
      }

      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final resultsJson = data['results'] as List?;
      final token = data['continuationToken'] as String?;

      if (resultsJson == null) {
        debugPrint('YOUTUBE_API SEARCH: no results key. Keys: ${(data as Map?)?.keys.toList()}');
        return YtifySearchResponse(results: []);
      }

      final results =
          resultsJson.map((json) => YtifyResult.fromJson(json)).toList();
      return YtifySearchResponse(results: results, continuationToken: token);
    } catch (e) {
      debugPrint('YOUTUBE_API SEARCH error: $e');
      return YtifySearchResponse(results: []);
    }
  }

  Future<List<YtifyResult>> getChannelVideos(String channelId) async {
    try {
      final uri = Uri.parse(
          'https://ytify-backend.zeabur.app/api/feed/channels=$channelId');
      debugPrint('YOUTUBE_API CHANNEL Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(headers: _headers, validateStatus: (status) => true),
      );
      if (response.statusCode != 200) return [];
      final List<dynamic> data = response.data is String ? jsonDecode(response.data) : response.data;
      return data.map((json) => YtifyResult.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<YtifyResult>> getSubscriptionsFeed(
      List<String> channelIds) async {
    if (channelIds.isEmpty) return [];
    try {
      final ids = channelIds.join(',');
      final uri = Uri.parse(
              'https://ytify-backend.zeabur.app/api/feed/channels=$ids')
          .replace(queryParameters: {'preview': '1'});
      debugPrint('YOUTUBE_API SUBSCRIPTIONS Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(headers: _headers, validateStatus: (status) => true),
      );
      if (response.statusCode != 200) return [];
      final List<dynamic> data = response.data is String ? jsonDecode(response.data) : response.data;
      return data.map((json) => YtifyResult.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final uri = Uri.parse(
              'https://ytify-backend.zeabur.app/api/search/suggestions')
          .replace(queryParameters: {'q': query, 'music': '1'});
      debugPrint('YOUTUBE_API SUGGESTIONS Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(headers: _headers, validateStatus: (status) => true),
      );
      if (response.statusCode != 200) return [];
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final suggestions = data['suggestions'] as List?;
      if (suggestions == null) return [];
      return suggestions.map((s) => s.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<YtifyResult>> getRelatedVideos(String videoId) async {
    try {
      final uri = Uri.parse(
          'https://ytify-backend.zeabur.app/api/related/$videoId');
      debugPrint('YOUTUBE_API RELATED Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(headers: _headers, validateStatus: (status) => true),
      );
      if (response.statusCode != 200) return [];
      final data = response.data is String ? jsonDecode(response.data) : response.data;
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
      final uri =
          Uri.parse('https://ytify-backend.zeabur.app/api/trending');
      debugPrint('YOUTUBE_API TRENDING Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(headers: _headers, validateStatus: (status) => true),
      );
      if (response.statusCode != 200) {
        return {'songs': [], 'videos': [], 'playlists': []};
      }
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      if (data['success'] != true || data['data'] == null) {
        return {'songs': [], 'videos': [], 'playlists': []};
      }
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
    return await _getFallbackVideoDetails(videoId);
  }
}

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  /// Fetches stream info using the provided [yt] singleton session.
  /// The caller is responsible for the lifecycle of [yt] — do NOT close it here.
  static Future<StreamProvider> fetch(String videoId, YoutubeExplode yt) async {
    try {
      final res = await yt.videos.streamsClient.getManifest(videoId);
      final audio = res.audioOnly;
      return StreamProvider(
          playable: true,
          statusMSG: 'OK',
          audioFormats: audio
              .map((e) => Audio(
                  itag: e.tag,
                  audioCodec:
                      e.audioCodec.contains('mp') ? Codec.mp4a : Codec.opus,
                  bitrate: e.bitrate.bitsPerSecond,
                  duration: 0,
                  url: e.url.toString(),
                  size: e.size.totalBytes))
              .toList());
    } catch (e) {
      if (e is SocketException) {
        return StreamProvider(playable: false, statusMSG: 'networkError');
      } else if (e is VideoUnplayableException) {
        return StreamProvider(
            playable: false, statusMSG: e.message);
      } else if (e is VideoRequiresPurchaseException) {
        return StreamProvider(
            playable: false, statusMSG: 'Song requires purchase');
      } else if (e is VideoUnavailableException) {
        return StreamProvider(playable: false, statusMSG: 'Song is unavailable');
      } else if (e is YoutubeExplodeException) {
        return StreamProvider(
            playable: false,
            statusMSG: e.message);
      } else {
        return StreamProvider(playable: false, statusMSG: 'Unknown error: $e');
      }
    }
  }

  Audio? get highestQualityAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 140,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateMp4aAudio =>
      audioFormats?.lastWhere((item) => item.itag == 140 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateOpusAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 250,
          orElse: () => audioFormats!.first);

  Audio? get lowQualityAudio =>
      audioFormats?.lastWhere((item) => item.itag == 249 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Map<String, dynamic> get hmStreamingData {
    return {
      "playable": playable,
      "statusMSG": statusMSG,
      "lowQualityAudio": lowQualityAudio?.toJson(),
      "highQualityAudio": highestQualityAudio?.toJson()
    };
  }
}

class Audio {
  final int itag;
  final Codec audioCodec;
  final int bitrate;
  final int duration;
  final int size;
  final String url;
  Audio(
      {required this.itag,
      required this.audioCodec,
      required this.bitrate,
      required this.duration,
      required this.url,
      required this.size});

  Map<String, dynamic> toJson() => {
        "itag": itag,
        "audioCodec": audioCodec.toString(),
        "bitrate": bitrate,
        "url": url,
        "approxDurationMs": duration,
        "size": size
      };

  factory Audio.fromJson(Map<String, dynamic> json) => Audio(
      audioCodec: (json["audioCodec"] as String).contains("mp4a")
          ? Codec.mp4a
          : Codec.opus,
      itag: json['itag'],
      duration: json["approxDurationMs"] ?? 0,
      bitrate: json["bitrate"] ?? 0,
      url: json['url'],
      size: json["size"] ?? 0);
}

enum Codec { mp4a, opus }
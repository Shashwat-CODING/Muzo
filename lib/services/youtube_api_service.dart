import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  final _client = http.Client();

  Future<void> dispose() async {
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
      debugPrint('Web platform detected: bypassing ANDROID_VR client');
      return await _getFallbackStreamUrl(videoId, title, artist);
    }

    try {
      debugPrint('Extracting stream for videoId: $videoId...');

      // FIX 1: Removed stale API key — keyless endpoint is more stable
      final url = Uri.parse(
        "https://www.youtube.com/youtubei/v1/player",
      );

      final body = {
        "context": {
          "client": {
            "clientName": "ANDROID",
            "clientVersion": "19.09.37",
            "androidSdkVersion": 33,
            "userAgent":
                "com.google.android.youtube/19.09.37 (Linux; U; Android 13) gzip",
            "osName": "Android",
            "osVersion": "13",
            // FIX 3: Added locale fields
            "hl": "en",
            "gl": "US",
          }
        },
        "videoId": videoId,
        "contentCheckOk": true,
        "racyCheckOk": true
      };

      final response = await _client.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "User-Agent":
              "com.google.android.youtube/19.09.37 (Linux; Android 13)",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception(
            "Failed to fetch stream details: ${response.statusCode}");
      }

      final data = jsonDecode(response.body);

      if (data["playabilityStatus"]?["status"] != "OK") {
        throw Exception("Video not playable: ${data["playabilityStatus"]}");
      }

      final streamingData = data["streamingData"];

      if (streamingData == null) {
        debugPrint(
            "streamingData is null. Full response: ${response.body}");
        throw Exception("No streamingData found.");
      }

      String? streamUrl;

      // Prefer direct formats first
      if (streamingData["formats"] != null) {
        for (var format in streamingData["formats"]) {
          if (format["url"] != null) {
            streamUrl = format["url"];
            break;
          }
        }
      }

      // Fallback to adaptiveFormats
      if (streamUrl == null && streamingData["adaptiveFormats"] != null) {
        for (var format in streamingData["adaptiveFormats"]) {
          if (format["url"] != null) {
            streamUrl = format["url"];
            break;
          }
        }
      }

      if (streamUrl != null) {
        // Pre-flight check to prevent ExoPlayer 403 crashes
        try {
          debugPrint('Pre-flight checking stream URL...');
          final checkResponse = await _client.get(
            Uri.parse(streamUrl),
            headers: {'Range': 'bytes=0-1'},
          );
          if (checkResponse.statusCode == 403) {
            throw Exception('Stream URL returned 403 Forbidden on pre-flight check');
          }
        } catch (e) {
          debugPrint('Pre-flight check failed: $e');
          throw Exception('Pre-flight check failed or forbidden: $e');
        }

        _logLong('Stream URL extracted and validated: $streamUrl');
        return streamUrl;
      } else {
        throw Exception(
            "No direct stream URL found — may require signature deciphering");
      }
    } catch (e) {
      debugPrint("Error extracting stream directly: $e");
      onFallback?.call();

      // Fallback 1: YoutubeExplode
      try {
        debugPrint("Trying YoutubeExplode Fallback...");
        final provider = await StreamProvider.fetch(videoId);
        if (provider.playable) {
          final url = provider.highestBitrateMp4aAudio?.url ??
              provider.highestQualityAudio?.url ??
              provider.audioFormats?.first.url;

          if (url != null) {
            _logLong('Stream URL extracted via YoutubeExplode: $url');
            return url;
          }
        } else {
          debugPrint("YoutubeExplode status: ${provider.statusMSG}");
        }
      } catch (ye) {
        debugPrint("Error in YoutubeExplode fallback: $ye");
      }

      // Fallback 2: Invidious Instances
      debugPrint("Trying Invidious Fallback...");
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

        final response = await http.get(uri);

        if (response.statusCode != 200) {
          debugPrint(
              'Invidious ($instance) returned status: ${response.statusCode}');
          continue;
        }

        final data = jsonDecode(response.body);
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
        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

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
        uri = Uri.parse('https://ytify-backend.vercel.app/api/yt_search')
            .replace(queryParameters: queryParams);
      } else if (filter == 'albums') {
        uri = Uri.parse('https://ytify-backend.vercel.app/api/search')
            .replace(queryParameters: queryParams);
      } else {
        uri = Uri.parse(
                'https://heujjsnxhjptqmanwadg.supabase.co/functions/v1/hyper-task')
            .replace(queryParameters: queryParams);
      }

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return YtifySearchResponse(results: []);
      }

      final data = jsonDecode(response.body);
      final resultsJson = data['results'] as List?;
      final token = data['continuationToken'] as String?;

      if (resultsJson == null) return YtifySearchResponse(results: []);

      final results =
          resultsJson.map((json) => YtifyResult.fromJson(json)).toList();
      return YtifySearchResponse(results: results, continuationToken: token);
    } catch (e) {
      return YtifySearchResponse(results: []);
    }
  }

  Future<List<YtifyResult>> getChannelVideos(String channelId) async {
    try {
      final uri = Uri.parse(
          'https://ytify-backend.vercel.app/api/feed/channels=$channelId');
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(response.body);
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
              'https://ytify-backend.vercel.app/api/feed/channels=$ids')
          .replace(queryParameters: {'preview': '1'});
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
      final uri = Uri.parse(
              'https://ytify-backend.vercel.app/api/search/suggestions')
          .replace(queryParameters: {'q': query, 'music': '1'});
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
      final uri = Uri.parse(
          'https://ytify-backend.vercel.app/api/related/$videoId');
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
      final uri =
          Uri.parse('https://ytify-backend.vercel.app/api/trending');
      final response = await http.get(uri);
      if (response.statusCode != 200) {
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

  static Future<StreamProvider> fetch(String videoId) async {
    final yt = YoutubeExplode();
    
    try {
      final res = await yt.videos.streamsClient.getManifest(videoId);
      final audio = res.audioOnly;
      return StreamProvider(
          playable: true,
          statusMSG: "OK",
          audioFormats: audio
              .map((e) => Audio(
                  itag: e.tag,
                  audioCodec:
                      e.audioCodec.contains('mp') ? Codec.mp4a : Codec.opus,
                  bitrate: e.bitrate.bitsPerSecond,
                  duration: 0, // Not available directly on stream info in latest package
                  loudnessDb: 0.0, // Not available directly in latest stream info
                  url: e.url.toString(),
                  size: e.size.totalBytes))
              .toList());
    } catch (e) {
      if (e is SocketException) {
        return StreamProvider(
          playable: false,
          statusMSG: "networkError",
        );
      } else if (e is VideoUnplayableException) {
        return StreamProvider(
          playable: false,
          statusMSG: e.message ?? "Song is unplayable",
        );
      } else if (e is VideoRequiresPurchaseException) {
        return StreamProvider(
          playable: false,
          statusMSG: "Song requires purchase",
        );
      } else if (e is VideoUnavailableException) {
        return StreamProvider(
          playable: false,
          statusMSG: "Song is unavailable",
        );
      } else if (e is YoutubeExplodeException) {
        return StreamProvider(
          playable: false,
          statusMSG: e.message ?? "YoutubeExplodeException",
        );
      } else {
        return StreamProvider(
          playable: false,
          statusMSG: "Unknown error occurred",
        );
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
  final double loudnessDb;
  final String url;
  Audio(
      {required this.itag,
      required this.audioCodec,
      required this.bitrate,
      required this.duration,
      required this.loudnessDb,
      required this.url,
      required this.size});

  Map<String, dynamic> toJson() => {
        "itag": itag,
        "audioCodec": audioCodec.toString(),
        "bitrate": bitrate,
        "loudnessDb": loudnessDb,
        "url": url,
        "approxDurationMs": duration,
        "size": size
      };

  factory Audio.fromJson(json) => Audio(
      audioCodec: (json["audioCodec"] as String).contains("mp4a")
          ? Codec.mp4a
          : Codec.opus,
      itag: json['itag'],
      duration: json["approxDurationMs"] ?? 0,
      bitrate: json["bitrate"] ?? 0,
      loudnessDb: (json['loudnessDb'])?.toDouble() ?? 0.0,
      url: json['url'],
      size: json["size"] ?? 0);
}

enum Codec { mp4a, opus }
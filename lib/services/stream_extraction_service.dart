import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:muzoapi/youtube_stream_provider.dart';

class StreamExtractionService {
  static final Map<String, bool> isSaavnCache = {};

  static String _cleanArtist(String artist) {
    String cleaned = artist;
    
    // Remove " - Topic" suffix common in YouTube uploads
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '');

    // Remove featuring info from artist name
    final featPattern = RegExp(
      r'\s*\b(?:feat\.?|ft\.?|featuring)\b.*$',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(featPattern, '');

    // Take only the first artist if there are separators like "," or "&" or "and"
    final primaryArtistPattern = RegExp(r'^([^,&]+)');
    final match = primaryArtistPattern.firstMatch(cleaned);
    if (match != null) {
      cleaned = match.group(1)!;
    }

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : artist;
  }

  static String _cleanTitle(String title, String artist) {
    String cleaned = title;
    
    // 1. Remove content inside brackets/parentheses that contain music video noise
    final bracketNoise = RegExp(
      r'\s*[([][^\])]*(?:video|audio|lyric|lyrics|mv|hd|4k|live|remix|official|music)[^\])]*[\])]',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(bracketNoise, '');

    // 2. Remove standalone noise phrases
    final standaloneNoise = RegExp(
      r'\s*\b(?:official video|official audio|music video|lyric video|lyrics|official|mv)\b',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(standaloneNoise, '');

    // 3. Remove featuring info (e.g. feat. / ft. / featuring ...)
    final featPattern = RegExp(
      r'\s*\b(?:feat\.?|ft\.?|featuring)\b.*$',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(featPattern, '');

    // 4. Remove artist prefix/suffix separated by a dash "-" if the artist name is present
    if (artist.isNotEmpty) {
      final cleanedArtist = _cleanArtist(artist);
      if (cleaned.contains('-')) {
        final parts = cleaned.split('-');
        final firstPart = parts[0].trim();
        if (firstPart.toLowerCase() == cleanedArtist.toLowerCase() || 
            cleanedArtist.toLowerCase().contains(firstPart.toLowerCase()) ||
            firstPart.toLowerCase().contains(cleanedArtist.toLowerCase())) {
          cleaned = parts.skip(1).join('-').trim();
        } else {
          final lastPart = parts.last.trim();
          if (lastPart.toLowerCase() == cleanedArtist.toLowerCase() ||
              cleanedArtist.toLowerCase().contains(lastPart.toLowerCase()) ||
              lastPart.toLowerCase().contains(cleanedArtist.toLowerCase())) {
            cleaned = parts.take(parts.length - 1).join('-').trim();
          }
        }
      }
    }

    // Clean up whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : title;
  }

  /// Fetches audio stream from the Saavn API first
  static Future<String?> getSaavnStreamUrl(String title, String artist, {int? durationSeconds}) async {
    try {
      final dio = Dio();

      final cleanTitle = _cleanTitle(title, artist);
      final cleanArtist = _cleanArtist(artist);

      String? durationString;
      if (durationSeconds != null && durationSeconds > 0) {
        final minutes = durationSeconds ~/ 60;
        final seconds = durationSeconds % 60;
        durationString = "$minutes:${seconds.toString().padLeft(2, '0')}";
      }

      final queryParams = {
        'title': cleanTitle,
        'artist': cleanArtist,
        if (durationString != null) 'duration': durationString,
      };
      debugPrint('SaavnExtraction: Requesting stream for "$cleanTitle" by "$cleanArtist" (${durationString ?? "unknown"})');
      
      final response = await dio.get<String>(
        'https://fast-saavn.vercel.app/',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => true,
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final path = response.data!.trim();
        if (path.isNotEmpty && !path.toLowerCase().contains('error') && !path.toLowerCase().contains('fail')) {
          final fullUrl = 'https://aac.saavncdn.com/${path}_320.mp4';
          debugPrint('SaavnExtraction: Found stream - $fullUrl');
          return fullUrl;
        }
      }
      debugPrint('SaavnExtraction: Empty or error response from Saavn API');
    } catch (e) {
      debugPrint('SaavnExtraction Error: $e');
    }
    return null;
  }

  /// Race Saavn and InnerTube to find the fastest stream URL
  static Future<String?> _raceFastExtractions({
    required String videoId,
    required String? title,
    required String? artist,
    required int? durationSeconds,
  }) async {
    final completer = Completer<String?>();
    int completedCount = 0;
    const totalCount = 2;
    final stopwatch = Stopwatch()..start();

    debugPrint('StreamExtraction: Starting race [Saavn vs InnerTube] for $videoId');

    void handleSuccess(String? url, bool isSaavn) {
      if (completer.isCompleted) return;
      final providerName = isSaavn ? "Saavn" : "InnerTube";
      if (url != null) {
        isSaavnCache[videoId] = isSaavn;
        debugPrint('StreamExtraction: [Race Winner] $providerName won the race in ${stopwatch.elapsedMilliseconds}ms');
        completer.complete(url);
      } else {
        debugPrint('StreamExtraction: [Race Status] $providerName completed with no stream in ${stopwatch.elapsedMilliseconds}ms');
        completedCount++;
        if (completedCount >= totalCount) {
          debugPrint('StreamExtraction: [Race Over] Both Saavn and InnerTube failed to resolve a stream in ${stopwatch.elapsedMilliseconds}ms');
          completer.complete(null);
        }
      }
    }

    // Task 1: Saavn Extraction
    if (title != null && artist != null) {
      debugPrint('StreamExtraction: [Saavn] Dispatching fetch for "$title" by "$artist"');
      getSaavnStreamUrl(title, artist, durationSeconds: durationSeconds).then((url) {
        handleSuccess(url, true);
      }).catchError((e) {
        debugPrint('StreamExtraction: [Saavn] Threw error: $e');
        handleSuccess(null, true);
      });
    } else {
      debugPrint('StreamExtraction: [Saavn] Skipping (missing title/artist)');
      completedCount++;
    }

    // Task 2: InnerTube Extraction
    debugPrint('StreamExtraction: [InnerTube] Dispatching fetch for videoId: $videoId');
    _getYoutubeStreamUrlViaInnerTube(videoId).then((url) {
      handleSuccess(url, false);
    }).catchError((e) {
      debugPrint('StreamExtraction: [InnerTube] Threw error: $e');
      handleSuccess(null, false);
    });

    return completer.future;
  }

  static Future<String?> _getYoutubeStreamUrlViaInnerTube(String videoId) async {
    try {
      debugPrint('StreamExtraction: [InnerTube] Querying player endpoint for videoId: $videoId');
      final yt = CustomInnerTube();
      final streamInfo = await yt.player(videoId);
      if (streamInfo.audioStreams.isNotEmpty) {
        final sortedStreams = streamInfo.audioStreams.toList()
          ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

        int qualityIndex = 0; // Default: high
        try {
          if (Hive.isBoxOpen('settings')) {
            qualityIndex = Hive.box('settings').get('audioQuality', defaultValue: 0);
          } else {
            final box = await Hive.openBox('settings');
            qualityIndex = box.get('audioQuality', defaultValue: 0);
          }
        } catch (e) {
          debugPrint('StreamExtraction: [InnerTube] Error reading audio quality from Hive: $e');
        }

        AudioStream selectedStream;
        if (qualityIndex == 0) {
          // High quality
          selectedStream = sortedStreams.first;
        } else if (qualityIndex == 2) {
          // Low quality
          selectedStream = sortedStreams.last;
        } else {
          // Medium quality: closest to 128 kbps
          selectedStream = sortedStreams.first;
          double minDiff = double.infinity;
          for (final stream in sortedStreams) {
            final diff = (stream.bitrate - 128000.0).abs();
            if (diff < minDiff) {
              minDiff = diff;
              selectedStream = stream;
            }
          }
        }
        debugPrint('StreamExtraction: [InnerTube] Selected stream: ${selectedStream.bitrate} bps, mime: ${selectedStream.mimeType}');
        return selectedStream.url;
      } else {
        debugPrint('StreamExtraction: [InnerTube] No audio streams returned by InnerTube player');
      }
    } catch (e) {
      debugPrint('StreamExtraction: [InnerTube] Extraction Error: $e');
    }
    return null;
  }

  /// Extracts the best audio stream URL, checking Saavn and InnerTube in parallel first,
  /// then falling back to YoutubeExplode on failure/error.
  static Future<String?> getStreamUrl(
    String videoId, {
    String? title,
    String? artist,
    int? durationSeconds,
  }) async {
    final overallStopwatch = Stopwatch()..start();
    debugPrint('StreamExtraction: --- getStreamUrl started for $videoId ---');
    
    // 1. Race Saavn and InnerTube
    final fastUrl = await _raceFastExtractions(
      videoId: videoId,
      title: title,
      artist: artist,
      durationSeconds: durationSeconds,
    );

    if (fastUrl != null) {
      debugPrint('StreamExtraction: Fast extraction succeeded in ${overallStopwatch.elapsedMilliseconds}ms (isSaavn: ${isSaavnCache[videoId]})');
      return fastUrl;
    }

    debugPrint('StreamExtraction: Fast extraction failed after ${overallStopwatch.elapsedMilliseconds}ms. Falling back to YoutubeExplode...');

    isSaavnCache[videoId] = false;

    // 2. YoutubeExplode (Android VR Client) fallback
    final yt = YoutubeExplode();
    try {
      debugPrint('FastExtraction: Extracting stream for $videoId');
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );

      Iterable<AudioOnlyStreamInfo> audioStreams = manifest.audioOnly;
      if (Platform.isMacOS || Platform.isIOS) {
        final mp4Streams = audioStreams.where((s) => s.container == StreamContainer.mp4);
        if (mp4Streams.isNotEmpty) {
          audioStreams = mp4Streams;
        }
      }

      if (audioStreams.isNotEmpty) {
        AudioOnlyStreamInfo selectedStream;
        final sortedStreams = audioStreams.toList()
          ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        
        var qualityIndex = 0; // Default: high
        try {
          if (Hive.isBoxOpen('settings')) {
            qualityIndex = Hive.box('settings').get('audioQuality', defaultValue: 0);
          } else {
            final box = await Hive.openBox('settings');
            qualityIndex = box.get('audioQuality', defaultValue: 0);
          }
        } catch (e) {
          debugPrint('Error reading audio quality from Hive: $e');
        }

        if (qualityIndex == 0) {
          // High quality
          selectedStream = sortedStreams.first;
        } else if (qualityIndex == 2) {
          // Low quality
          selectedStream = sortedStreams.last;
        } else {
          // Medium quality: closest to 128 kbps
          selectedStream = sortedStreams.first;
          double minDiff = double.infinity;
          for (final stream in sortedStreams) {
            final diff = (stream.bitrate.kiloBitsPerSecond - 128.0).abs();
            if (diff < minDiff) {
              minDiff = diff;
              selectedStream = stream;
            }
          }
        }

        debugPrint('StreamExtraction: [YoutubeExplode] Found stream (quality index $qualityIndex) - ${selectedStream.url}');
        debugPrint('StreamExtraction: --- getStreamUrl completed successfully in ${overallStopwatch.elapsedMilliseconds}ms ---');
        return selectedStream.url.toString();
      } else {
        debugPrint('StreamExtraction: [YoutubeExplode] No audio streams found.');
      }
    } catch (e) {
      debugPrint("StreamExtraction: [YoutubeExplode] Error: $e");
    } finally {
      yt.close();
    }

    debugPrint('StreamExtraction: --- getStreamUrl failed completely in ${overallStopwatch.elapsedMilliseconds}ms ---');
    return null;
  }
}

// Custom InnerTube subclass to resolve the player API issues
class CustomInnerTube extends InnerTube {
  CustomInnerTube({super.options});

  @override
  String get baseUrl => 'https://www.youtube.com/youtubei/v1/';

  @override
  Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      'User-Agent': 'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    };
  }

  @override
  Map<String, dynamic> getContextPayload() {
    return {
      'context': {
        'client': {
          'clientName': 'ANDROID_VR',
          'clientVersion': '1.60.19',
          'deviceModel': 'Quest 3',
          'deviceMake': 'Oculus',
          'osVersion': '12L',
          'osName': 'Android',
          'androidSdkVersion': '32',
          'hl': 'en',
          'timeZone': 'UTC',
          'utcOffsetMinutes': 0,
        }
      },
    };
  }

  @override
  Future<Map<String, dynamic>> makeRequest(
      String endpoint, Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint?prettyPrint=false');
      final response = await http.post(
        uri,
        headers: getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 400) {
        throw Exception('HTTP error! status: ${response.statusCode}');
      }

      return jsonDecode(response.body);
    } catch (error) {
      throw Exception('YouTube API Error: $error');
    }
  }
}

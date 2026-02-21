import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single syllable/word within a karaoke lyric line
class KaraokeSyllable {
  final Duration time;
  final Duration duration;
  final String text;
  const KaraokeSyllable({required this.time, required this.duration, required this.text});
}

/// A complete lyric line with optional word-level timing for karaoke
class KaraokeLine {
  final Duration lineStart;
  final String fullText;
  final List<KaraokeSyllable> syllables;
  const KaraokeLine({required this.lineStart, required this.fullText, required this.syllables});
}

class Lyrics {
  final int id;
  final String name;
  final String trackName;
  final String artistName;
  final String albumName;
  final int duration;
  final bool instrumental;
  final String plainLyrics;
  final String syncedLyrics;
  /// Non-null when Atomix returns type:Word — enables karaoke word highlighting
  final List<KaraokeLine>? karaokeLines;

  Lyrics({
    required this.id,
    required this.name,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.instrumental,
    required this.plainLyrics,
    required this.syncedLyrics,
    this.karaokeLines,
  });

  factory Lyrics.fromJson(Map<String, dynamic> json) {
    return Lyrics(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      trackName: json['trackName'] ?? '',
      artistName: json['artistName'] ?? '',
      albumName: json['albumName'] ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      instrumental: json['instrumental'] ?? false,
      plainLyrics: json['plainLyrics'] ?? '',
      syncedLyrics: json['syncedLyrics'] ?? '',
    );
  }
}

final lyricsServiceProvider = Provider((ref) => LyricsService());

class LyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';

  Future<Lyrics?> fetchLyrics(
    String trackName,
    String artistName,
    int duration,
  ) async {
    final cleanTrack = _cleanTitle(trackName);
    final cleanArtist = _cleanTitle(artistName);

    // 1. Try Atomix Lyrics API primary
    try {
      final atomixUri = Uri.parse('https://lyricsplus.atomix.one/v2/lyrics/get').replace(
        queryParameters: {'title': cleanTrack, 'artist': cleanArtist, 'duration': duration.toString()},
      );

      debugPrint('LyricsService: Requesting Atomix GET $atomixUri');
      final atomixRes = await http.get(atomixUri).timeout(const Duration(seconds: 10));

      if (atomixRes.statusCode == 200) {
        final atomixData = json.decode(atomixRes.body);
        final String responseType = atomixData['type'] ?? '';
        // Handle both 'Line' (line-level) and 'Word' (word-level syllable) responses
        final bool isSupported = (responseType == 'Line' || responseType == 'Word') &&
            atomixData['lyrics'] != null;

        if (isSupported) {
          final List<dynamic> lines = atomixData['lyrics'];
          
          final StringBuffer syncedBuffer = StringBuffer();
          final StringBuffer plainBuffer = StringBuffer();
          final List<KaraokeLine>? karaokeLines = responseType == 'Word' ? [] : null;

          for (var line in lines) {
            final int rawMs = line['time'] ?? 0;
            // No offset — use raw timestamps from API
            final String text = (line['text'] as String? ?? '').trim();
            if (text.isEmpty) continue;

            final lineDuration = Duration(milliseconds: rawMs);
            final minutes = lineDuration.inMinutes.toString().padLeft(2, '0');
            final seconds = (lineDuration.inSeconds % 60).toString().padLeft(2, '0');
            final hundredths = ((lineDuration.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');

            syncedBuffer.writeln('[$minutes:$seconds.$hundredths] $text');
            plainBuffer.writeln(text);

            // For Word-type: parse syllable-level data into KaraokeLine
            if (responseType == 'Word') {
              final List<dynamic> syllabi = (line['syllabus'] as List<dynamic>?) ?? [];
              final List<KaraokeSyllable> syllables = syllabi.map((s) {
                return KaraokeSyllable(
                  time: Duration(milliseconds: (s['time'] as num?)?.toInt() ?? rawMs),
                  duration: Duration(milliseconds: (s['duration'] as num?)?.toInt() ?? 300),
                  text: s['text'] as String? ?? '',
                );
              }).toList();
              karaokeLines!.add(KaraokeLine(
                lineStart: Duration(milliseconds: rawMs),
                fullText: text,
                syllables: syllables.isEmpty
                    ? [KaraokeSyllable(time: Duration(milliseconds: rawMs), duration: const Duration(milliseconds: 2000), text: text)]
                    : syllables,
              ));
            }
          }

          if (plainBuffer.isNotEmpty) {
             debugPrint('LyricsService: Found lyrics via Atomix API (type: $responseType)');
             return Lyrics(
               id: 0,
               name: cleanTrack,
               trackName: cleanTrack,
               artistName: cleanArtist,
               albumName: '',
               duration: duration,
               instrumental: false,
               plainLyrics: plainBuffer.toString(),
               syncedLyrics: syncedBuffer.toString(),
               karaokeLines: karaokeLines,
             );
          }
        }
      }
    } catch (e) {
      debugPrint('LyricsService: Error in Atomix GET: $e');
    }

    // 2. Fallback to LRCLIB Try exact match with cleaned metadata
    try {
      final uri = Uri.parse('$_baseUrl/get').replace(
        queryParameters: {'track_name': cleanTrack, 'artist_name': cleanArtist},
      );

      debugPrint('LyricsService: Requesting LRCLIB GET $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('LyricsService: LRCLIB GET Response ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['plainLyrics'] != null || data['syncedLyrics'] != null) {
          debugPrint('LyricsService: Found exact match via LRCLIB GET');
          return Lyrics.fromJson(data);
        }
      } else if (response.statusCode == 404) {
        // Fallback to search
        debugPrint('LyricsService: LRCLIB GET failed (404), falling back to SEARCH');
        return _searchLyrics(cleanTrack, cleanArtist, duration);
      }

      return null;
    } catch (e) {
      debugPrint('LyricsService: Error in LRCLIB GET: $e');
      // Last resort try search on error too
      return _searchLyrics(cleanTrack, cleanArtist, duration);
    }
  }

  Future<Lyrics?> _searchLyrics(
    String track,
    String artist,
    int duration,
  ) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/search',
      ).replace(queryParameters: {'track_name': track, 'artist_name': artist});
      debugPrint('LyricsService: Searching $uri');

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        debugPrint('LyricsService: Search returned ${list.length} results');

        if (list.isEmpty) return null;

        // Find best match based on duration
        Lyrics? bestMatch;
        int minDiff = 1000000;

        for (var item in list) {
          final l = Lyrics.fromJson(item);
          final diff = (l.duration - duration).abs();

          // Check if it has lyrics
          if (l.plainLyrics.isEmpty && l.syncedLyrics.isEmpty) continue;

          // Allow up to 3 seconds difference for "perfect" match, otherwise find closest
          if (diff < minDiff) {
            minDiff = diff;
            bestMatch = l;
          }
        }

        // Only return if within acceptable range (e.g. 5 seconds), otherwise it might be wrong song
        if (minDiff <= 5 && bestMatch != null) {
          debugPrint(
            'LyricsService: Found best match "${bestMatch.trackName}" with diff ${minDiff}s',
          );
          return bestMatch;
        } else {
          debugPrint(
            'LyricsService: No match within duration tolerance (Best diff: ${minDiff}s)',
          );
        }
      } else {
        debugPrint(
          'LyricsService: Search failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('LyricsService: Search Error: $e');
    }
    return null;
  }

  String _cleanTitle(String text) {
    debugPrint('LyricsService: Cleaning title: "$text"');
    if (text.isEmpty) return text;

    try {
      // Remove common patterns
      var clean = text;

      // Remove (Official Video), [Official Audio], etc.
      // Using standard Dart RegExp constructor for case insensitivity
      final videoPattern = RegExp(
        r'\s*[\(\[](official|video|audio|lyrics|lyric|hd|hq|4k|mv|music video|full audio)[\)\]]',
        caseSensitive: false,
      );
      clean = clean.replaceAll(videoPattern, '');

      // Remove "ft.", "feat."
      final featPattern = RegExp(
        r'\s+(ft\.|feat\.|featuring)\s+',
        caseSensitive: false,
      );
      if (featPattern.hasMatch(clean)) {
        clean = clean.split(featPattern).first;
      }

      // Remove " - Topic" from artist strings
      clean = clean.replaceAll(' - Topic', '');

      final result = clean.trim();
      debugPrint('LyricsService: Cleaned title: "$result"');
      return result;
    } catch (e) {
      debugPrint('LyricsService: Error cleaning title "$text": $e');
      return text; // Return original if cleaning fails
    }
  }
}

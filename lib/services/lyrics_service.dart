import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  factory Lyrics.fromJson(Map<String, dynamic> json) {
    // Check if essential fields are present, if not consider it invalid/empty
    if (json['plainLyrics'] == null && json['syncedLyrics'] == null) {
      // Return empty or handle as needed, but for now populating with defaults
      // The service might check this.
    }
    
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

  Future<Lyrics?> fetchLyrics(String trackName, String artistName, int duration) async {
    try {
      final uri = Uri.parse('$_baseUrl/get').replace(queryParameters: {
        'track_name': trackName,
        'artist_name': artistName,
      });

      debugPrint('LyricsService: Requesting $uri');

      final response = await http.get(uri);
      
      debugPrint('LyricsService: Response Code: ${response.statusCode}');
      debugPrint('LyricsService: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['plainLyrics'] == null && data['syncedLyrics'] == null) {
          return null;
        }
        return Lyrics.fromJson(data);
      } else {
        // Try searching if direct get fails? Or just return null as per "user choice response of api"
        // The user specifically asked to use `get` endpoint with specific parameters.
        return null;
      }
    } catch (e) {
      debugPrint('LyricsService: Error: $e');
      return null;
    }
  }
}

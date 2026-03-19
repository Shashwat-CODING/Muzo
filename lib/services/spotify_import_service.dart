import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/services/storage_service.dart';

final spotifyImportServiceProvider = Provider<SpotifyImportService>((ref) {
  final storageService = ref.read(storageServiceProvider);
  return SpotifyImportService(storageService);
});

class SpotifyImportProgress {
  final int total;
  final int current;
  final String status;
  final bool isComplete;
  final bool hasError;
  final String? errorMessage;

  SpotifyImportProgress({
    this.total = 0,
    this.current = 0,
    this.status = '',
    this.isComplete = false,
    this.hasError = false,
    this.errorMessage,
  });

  SpotifyImportProgress copyWith({
    int? total,
    int? current,
    String? status,
    bool? isComplete,
    bool? hasError,
    String? errorMessage,
  }) {
    return SpotifyImportProgress(
      total: total ?? this.total,
      current: current ?? this.current,
      status: status ?? this.status,
      isComplete: isComplete ?? this.isComplete,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SpotifyImportService {
  final StorageService _storageService;

  SpotifyImportService(this._storageService);

  String _extractPlaylistId(String input) {
    // e.g. https://open.spotify.com/playlist/6RMdpfAlmWhyHXXDHnJru6?si=...
    if (input.contains('spotify.com/playlist/')) {
      final parts = input.split('spotify.com/playlist/');
      if (parts.length > 1) {
        final idPart = parts[1].split('?').first;
        return idPart.trim();
      }
    }
    return input.trim(); // Assume it's already an ID
  }

  Future<Map<String, dynamic>?> fetchSpotifyPlaylist(String urlOrId) async {
    final playlistId = _extractPlaylistId(urlOrId);
    if (playlistId.isEmpty) return null;

    try {
      final uri = Uri.parse('https://dawn-violet-2368.shashwat-coding.workers.dev/api/data/spotify/playlist/$playlistId');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Spotify API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching Spotify playlist: $e');
    }
    return null;
  }

  Future<MuzoItem?> resolveToYTM(String name, String artist) async {
    try {
      final uri = Uri.parse('https://dawn-violet-2368.shashwat-coding.workers.dev/api/find/track')
          .replace(queryParameters: {'name': name, 'artist': artist});
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['videoId'] != null) {
          // It's a match, map to MuzoItem JSON format and parse
          data['resultType'] = 'song';
          return MuzoItem.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('Error resolving track to YTM: $e');
    }
    return null;
  }

  Stream<SpotifyImportProgress> importPlaylist(String urlOrId) async* {
    var progress = SpotifyImportProgress(status: 'Fetching Spotify playlist...');
    yield progress;

    try {
      final playlistData = await fetchSpotifyPlaylist(urlOrId);
      
      if (playlistData == null || playlistData['playlist'] == null) {
        yield progress.copyWith(
          hasError: true, 
          isComplete: true, 
          errorMessage: 'Failed to fetch playlist details. Check the URL or ID.'
        );
        return;
      }

      final playListInfo = playlistData['playlist'];
      var playlistName = playListInfo['name']?.toString() ?? 'Imported Spotify Playlist';
      
      final List<dynamic> tracks = playlistData['tracks'] ?? [];
      if (tracks.isEmpty) {
        yield progress.copyWith(
          hasError: true, 
          isComplete: true, 
          errorMessage: 'The Spotify playlist is empty.'
        );
        return;
      }

      // Check if playlist already exists, append (1) etc if it does
      final existingNames = _storageService.getPlaylistNames();
      String finalName = playlistName;
      int counter = 1;
      while (existingNames.contains(finalName)) {
        finalName = '$playlistName ($counter)';
        counter++;
      }

      yield progress.copyWith(total: tracks.length, status: 'Creating playlist "$finalName"...');
      
      // Create playlist locally using StorageService
      await _storageService.createPlaylist(finalName);
      
      int imported = 0;
      for (var track in tracks) {
        final title = track['title']?.toString() ?? '';
        final artists = track['artists']?.toString() ?? '';
        
        yield progress.copyWith(
          current: imported, 
          status: 'Finding match for $title...'
        );

        final muzoItem = await resolveToYTM(title, artists);
        if (muzoItem != null) {
          await _storageService.addToPlaylist(finalName, muzoItem);
        }
        
        imported++;
        yield progress.copyWith(
          current: imported,
          status: 'Imported $imported/${tracks.length}',
        );
      }
      
      yield progress.copyWith(
        current: imported,
        isComplete: true,
        status: 'Import complete!'
      );
    } catch (e) {
      yield progress.copyWith(
        hasError: true,
        isComplete: true,
        errorMessage: 'An unexpected error occurred: $e'
      );
    }
  }
}

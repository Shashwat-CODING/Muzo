import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:muzo/models/ytify_result.dart';

import 'package:muzo/models/artist_details.dart';
import 'package:muzo/models/album_details.dart';

class YtifyApiService {
  static const String _baseUrl =
      'https://heujjsnxhjptqmanwadg.supabase.co/functions/v1/ytmusic-search';
  static const String _ytSearchBaseUrl =
      'https://ytify-backend.vercel.app/api/yt_search';
  static const String _artistBaseUrl =
      'https://ytify-backend.vercel.app/api/artist';
  static const String _playlistBaseUrl =
      'https://ytify-backend.vercel.app/api/playlist';
  static const String _albumBaseUrl =
      'https://ytify-backend.vercel.app/api/album';
  static const String _searchBaseUrl =
      'https://ytify-backend.vercel.app/api/search';
  static const String _suggestionsBaseUrl =
      'https://ytify-backend.vercel.app/api/search/suggestions';

  Future<AlbumDetails?> getAlbumDetails(String albumId) async {
    try {
      final uri = Uri.parse('$_albumBaseUrl/$albumId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final albumDetails = AlbumDetails.fromJson(data);

        // If playlistId is available, fetch rich track data from playlist endpoint
        if (albumDetails.playlistId != null &&
            albumDetails.playlistId!.isNotEmpty) {
          try {
            final playlistDetails = await getPlaylistDetails(
              albumDetails.playlistId!,
            );
            if (playlistDetails != null && playlistDetails.tracks.isNotEmpty) {
              // Return album details with rich track data from playlist
              return AlbumDetails(
                id: albumDetails.id,
                playlistId: albumDetails.playlistId,
                title: albumDetails.title,
                artist: albumDetails.artist,
                year: albumDetails.year,
                thumbnail: albumDetails.thumbnail,
                tracks: playlistDetails.tracks,
                type: albumDetails.type,
              );
            }
          } catch (e) {
            debugPrint(
              'Failed to fetch playlist tracks, using album tracks: $e',
            );
          }
        }

        return albumDetails;
      } else {
        debugPrint(
          'Ytify Album API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching album details: $e');
    }
    return null;
  }

  Future<List<YtifyResult>> search(
    String query, {
    String filter = 'songs',
  }) async {
    try {
      Uri uri;
      if (filter == 'videos') {
        uri = Uri.parse('$_ytSearchBaseUrl?q=$query&filter=$filter');
      } else if (filter == 'albums') {
        uri = Uri.parse('$_searchBaseUrl?q=$query&filter=albums');
      } else {
        uri = Uri.parse('$_baseUrl?q=$query&filter=$filter');
      }
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results != null) {
          return results.map((e) => YtifyResult.fromJson(e)).toList();
        }
      } else {
        debugPrint(
          'Ytify API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error searching Ytify: $e');
    }
    return [];
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.isEmpty) return [];
    try {
      final uri = Uri.parse('$_suggestionsBaseUrl?q=$query&music=1');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestions = data['suggestions'] as List?;
        if (suggestions != null) {
          return suggestions.cast<String>();
        }
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
    return [];
  }

  Future<ArtistDetails?> getArtistDetails(String browseId) async {
    try {
      final uri = Uri.parse('$_artistBaseUrl/$browseId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ArtistDetails.fromJson(data);
      } else {
        debugPrint(
          'Ytify Artist API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching artist details: $e');
    }
    return null;
  }

  Future<PlaylistDetails?> getPlaylistDetails(String playlistId) async {
    try {
      final uri = Uri.parse('$_playlistBaseUrl/$playlistId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PlaylistDetails.fromJson(data);
      } else {
        debugPrint(
          'Ytify Playlist API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching playlist details: $e');
    }
    return null;
  }

  Future<List<YtifyResult>> getExploreFeed() async {
    // Using "newest" as query to simulate explore feed as requested
    // We can fetch a mix of filters if needed, but for now let's just fetch songs/videos
    // Or maybe just one call with a generic query if the API supports it without filter?
    // The user said "remove all filter and in explore page show few results from all filters with query as newest"
    // The API seems to require a filter based on the examples, but let's try calling for each and combining.

    // Actually, the user said "remove all filter" which implies maybe no filter param?
    // But the examples show specific filters.
    // "for explore page show few results from all filters with query as newest"

    List<YtifyResult> combinedResults = [];

    try {
      final songs = await search('newest', filter: 'songs');
      final videos = await search('newest', filter: 'videos');

      combinedResults.addAll(songs.take(5));
      combinedResults.addAll(videos.take(5));

      // Shuffle to mix them up? Or just list them.
      return combinedResults;
    } catch (e) {
      debugPrint('Error fetching explore feed: $e');
      return [];
    }
  }
}

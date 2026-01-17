import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/models/user_data.dart';
import 'package:muzo/services/auth_service.dart';
import 'package:muzo/services/storage_service.dart';

final musicApiServiceProvider = Provider<MusicApiService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return MusicApiService(storage);
});

class MusicApiService {
  final StorageService _storage;
  late final AuthService _auth;

  MusicApiService(this._storage) {
    _auth = AuthService(_storage);
  }

  static const String _baseUrl = 'https://veltrixcode-ytify.hf.space/api';

  Map<String, String> get _headers {
    final token = _storage.authToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _retryWithRefresh(
    Future<http.Response> Function() request,
  ) async {
    var response = await request();

    if (response.statusCode == 403) {
      debugPrint('Received 403, attempting token refresh...');
      final newToken = await _auth.refreshToken();
      if (newToken != null) {
        debugPrint('Token refreshed, retrying request...');
        response = await request();
      }
    }

    return response;
  }

  // --- User Data ---

  Future<UserData> getUserData() async {
    final response = await _retryWithRefresh(
      () => http.get(Uri.parse('$_baseUrl/user/data'), headers: _headers),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserData.fromJson(data);
    } else {
      throw Exception('Failed to load user data');
    }
  }

  // --- History ---

  Future<List<YtifyResult>> getHistory() async {
    final response = await _retryWithRefresh(
      () => http.get(Uri.parse('$_baseUrl/history'), headers: _headers),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['history'];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load history');
    }
  }

  Future<void> addToHistory(YtifyResult song) async {
    final response = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$_baseUrl/history'),
        headers: _headers,
        body: jsonEncode(song.toJson()),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add to history');
    }
  }

  Future<void> removeFromHistory(String videoId) async {
    final response = await _retryWithRefresh(
      () => http.delete(
        Uri.parse('$_baseUrl/history/$videoId'),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove from history');
    }
  }

  Future<void> clearHistory() async {
    final response = await _retryWithRefresh(
      () => http.delete(Uri.parse('$_baseUrl/history'), headers: _headers),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to clear history');
    }
  }

  // --- Favorites ---

  Future<List<YtifyResult>> getFavorites() async {
    final response = await _retryWithRefresh(
      () => http.get(Uri.parse('$_baseUrl/favorites'), headers: _headers),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['favorites'];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load favorites');
    }
  }

  Future<void> addToFavorites(YtifyResult song) async {
    final response = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$_baseUrl/favorites'),
        headers: _headers,
        body: jsonEncode(song.toJson()),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add to favorites');
    }
  }

  Future<void> removeFromFavorites(String videoId) async {
    final response = await _retryWithRefresh(
      () => http.delete(
        Uri.parse('$_baseUrl/favorites/$videoId'),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove from favorites');
    }
  }

  // --- Playlists ---

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final response = await _retryWithRefresh(
      () => http.get(Uri.parse('$_baseUrl/playlists'), headers: _headers),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['playlists']);
    } else {
      throw Exception('Failed to load playlists');
    }
  }

  Future<List<YtifyResult>> getPlaylistSongs(String playlistName) async {
    final response = await _retryWithRefresh(
      () => http.get(
        Uri.parse('$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}'),
        headers: _headers,
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['playlist'];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load playlist songs');
    }
  }

  Future<void> addToPlaylist(String playlistName, YtifyResult song) async {
    final response = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}'),
        headers: _headers,
        body: jsonEncode(song.toJson()),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add to playlist');
    }
  }

  Future<void> deletePlaylist(String playlistName) async {
    final response = await _retryWithRefresh(
      () => http.delete(
        Uri.parse('$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}'),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete playlist');
    }
  }

  Future<void> removeSongFromPlaylist(
    String playlistName,
    String videoId,
  ) async {
    final response = await _retryWithRefresh(
      () => http.delete(
        Uri.parse(
          '$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}/songs/$videoId',
        ),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove song from playlist');
    }
  }

  // --- Subscriptions ---

  Future<List<YtifyResult>> getSubscriptions() async {
    final response = await _retryWithRefresh(
      () => http.get(Uri.parse('$_baseUrl/subscriptions'), headers: _headers),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['subscriptions'];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load subscriptions');
    }
  }

  Future<void> addSubscription(YtifyResult channel) async {
    final response = await _retryWithRefresh(
      () => http.post(
        Uri.parse('$_baseUrl/subscriptions'),
        headers: _headers,
        body: jsonEncode(channel.toJson()),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to subscribe');
    }
  }

  Future<void> removeSubscription(String browseId) async {
    final response = await _retryWithRefresh(
      () => http.delete(
        Uri.parse('$_baseUrl/subscriptions/$browseId'),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to unsubscribe');
    }
  }

  Future<List<YtifyResult>> getUpNext(String videoId) async {
    try {
      final uri = Uri.parse(
        'https://heujjsnxhjptqmanwadg.supabase.co/functions/v1/hyper-task?videoId=$videoId',
      );
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('UpNext API Error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) return [];

      final List<dynamic> list = data['upNext'];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching Up Next: $e');
      return [];
    }
  }
}

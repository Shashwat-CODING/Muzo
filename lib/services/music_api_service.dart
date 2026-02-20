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

  Future<http.Response> _authRequest(
    Future<http.Response> Function() request,
  ) async {
    final response = await request().timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      debugPrint('Token invalid or expired. Logging out.');
      await _auth.logout();
      // Throw exception so UI layers can react and push to login
      throw Exception('Session expired');
    }
    return response;
  }

  // --- User Data ---

  Future<UserData> getUserData() async {
    final response = await _authRequest(
      () => http.get(Uri.parse('$_baseUrl/user/data'), headers: _headers),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return UserData.fromJson(json);
    } else {
      throw Exception('Failed to load user data');
    }
  }



  Future<List<YtifyResult>> getHistory({int page = 1}) async {
    final response = await _authRequest(
      () => http.get(Uri.parse('$_baseUrl/history?page=$page'), headers: _headers),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['data'] ?? [];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load history');
    }
  }

  Future<void> addToHistory(YtifyResult song) async {
    final response = await _authRequest(
      () => http.post(
        Uri.parse('$_baseUrl/history'),
        headers: _headers,
        body: jsonEncode({
          'videoId': song.videoId,
          'title': song.title,
          'artist': song.artists?.map((a) => a.name).join(', ') ?? song.videoType ?? 'Unknown',
          'thumbnail': song.thumbnails.isNotEmpty ? song.thumbnails.last.url : '',
        }),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add to history');
    }
  }

  Future<void> removeFromHistory(String videoId) async {
    final response = await _authRequest(
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
    final response = await _authRequest(
      () => http.delete(Uri.parse('$_baseUrl/history'), headers: _headers),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to clear history');
    }
  }

  // --- Favorites ---

  Future<List<YtifyResult>> getFavorites({int page = 1}) async {
    final response = await _authRequest(
      () => http.get(Uri.parse('$_baseUrl/favorites?page=$page'), headers: _headers),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['data'] ?? [];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load favorites');
    }
  }

  Future<void> addToFavorites(YtifyResult song) async {
    final response = await _authRequest(
      () => http.post(
        Uri.parse('$_baseUrl/favorites'),
        headers: _headers,
        body: jsonEncode({
          'videoId': song.videoId,
          'title': song.title,
          'artist': song.artists?.map((a) => a.name).join(', ') ?? song.videoType ?? 'Unknown',
          'thumbnail': song.thumbnails.isNotEmpty ? song.thumbnails.last.url : '',
        }),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add to favorites');
    }
  }

  Future<void> removeFromFavorites(String videoId) async {
    final response = await _authRequest(
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

  Future<List<Map<String, dynamic>>> getPlaylists({int page = 1}) async {
    final response = await _authRequest(
      () => http.get(Uri.parse('$_baseUrl/playlists?page=$page'), headers: _headers),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(json['data'] ?? []);
    } else {
      throw Exception('Failed to load playlists');
    }
  }

  Future<void> createPlaylist(String name) async {
    final response = await _authRequest(
      () => http.post(
        Uri.parse('$_baseUrl/playlists'),
        headers: _headers,
        body: jsonEncode({'title': name}), // Using title as per convention
      ),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to create playlist');
    }
  }

  Future<List<YtifyResult>> getPlaylistSongs(String playlistId, {int page = 1}) async {
    final response = await _authRequest(
      () => http.get(
        Uri.parse('$_baseUrl/playlists/$playlistId/songs?page=$page'),
        headers: _headers,
      ),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List<dynamic> list = json['data'] ?? [];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load playlist songs');
    }
  }

  Future<void> addToPlaylist(String playlistName, YtifyResult song) async {
    final response = await _authRequest(
      () => http.post(
        Uri.parse('$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}'),
        headers: _headers,
        body: jsonEncode({
          'videoId': song.videoId,
          'title': song.title,
          'artist': song.artists?.map((a) => a.name).join(', ') ?? song.videoType ?? 'Unknown',
          'thumbnail': song.thumbnails.isNotEmpty ? song.thumbnails.last.url : '',
        }),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add to playlist');
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    final response = await _authRequest(
      () => http.delete(
        Uri.parse('$_baseUrl/playlists/$playlistId'),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete playlist');
    }
  }

  Future<void> removeSongFromPlaylist(
    String playlistId,
    String videoId,
  ) async {
    final response = await _authRequest(
      () => http.delete(
        Uri.parse(
          '$_baseUrl/playlists/$playlistId/songs/$videoId',
        ),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove song from playlist');
    }
  }

  // --- Subscriptions ---

  Future<List<YtifyResult>> getSubscriptions({int page = 1}) async {
    final response = await _authRequest(
      () => http.get(Uri.parse('$_baseUrl/subscriptions?page=$page'), headers: _headers),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List<dynamic> list = json['data'] ?? [];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load subscriptions');
    }
  }

  Future<void> addSubscription(YtifyResult channel) async {
    final response = await _authRequest(
      () => http.post(
        Uri.parse('$_baseUrl/subscriptions'),
        headers: _headers,
        body: jsonEncode({
          'channelId': channel.videoId, // Assuming videoId holds channelId for channels
          'channelName': channel.title,
          'thumbnail': channel.thumbnails.isNotEmpty ? channel.thumbnails.last.url : '',
        }),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to subscribe');
    }
  }

  Future<void> removeSubscription(String channelId) async {
    final response = await _authRequest(
      () => http.delete(
        Uri.parse('$_baseUrl/subscriptions/$channelId'),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to unsubscribe');
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
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
  final Dio _client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

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

  Future<Response<T>> _retryWithRefresh<T>(
    Future<Response<T>> Function() request, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Dio timeout is set on _client, but we use Future.timeout for the whole op
    var response = await request().timeout(timeout);

    if (response.statusCode == 403) {
      debugPrint('Received 403, attempting token refresh...');
      final newToken = await _auth.refreshToken();
      if (newToken != null) {
        debugPrint('Token refreshed, retrying request...');
        response = await request().timeout(timeout);
      }
    }

    return response;
  }

  // --- User Data ---

  Future<UserData> getUserData() async {
    // /user/data can be slow on cold-start, give it a longer timeout via the param
    final response = await _retryWithRefresh(
      () => _client.get(
        '$_baseUrl/user/data',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
      timeout: const Duration(seconds: 200),
    );

    if (response.statusCode == 200) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return UserData.fromJson(data);
    } else {
      throw Exception('Failed to load user data');
    }
  }

  // --- History ---

  Future<List<YtifyResult>> getHistory() async {
    final response = await _retryWithRefresh(
      () => _client.get(
        '$_baseUrl/history',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final List<dynamic> list = data['history'];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load history');
    }
  }

  Future<void> addToHistory(YtifyResult song) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        '$_baseUrl/history',
        options: Options(headers: _headers, validateStatus: (status) => true),
        data: song.toJson(),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add to history');
    }
  }

  Future<void> removeFromHistory(String videoId) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        '$_baseUrl/history/$videoId',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove from history');
    }
  }

  Future<void> clearHistory() async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        '$_baseUrl/history',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to clear history');
    }
  }

  // --- Favorites ---

  Future<List<YtifyResult>> getFavorites() async {
    final response = await _retryWithRefresh(
      () => _client.get(
        '$_baseUrl/favorites',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final List<dynamic> list = data['favorites'];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load favorites');
    }
  }

  Future<void> addToFavorites(YtifyResult song) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        '$_baseUrl/favorites',
        options: Options(headers: _headers, validateStatus: (status) => true),
        data: song.toJson(),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add to favorites');
    }
  }

  Future<void> removeFromFavorites(String videoId) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        '$_baseUrl/favorites/$videoId',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove from favorites');
    }
  }

  // --- Playlists ---

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final response = await _retryWithRefresh(
      () => _client.get(
        '$_baseUrl/playlists',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return List<Map<String, dynamic>>.from(data['playlists']);
    } else {
      throw Exception('Failed to load playlists');
    }
  }

  Future<List<YtifyResult>> getPlaylistSongs(String playlistName) async {
    final response = await _retryWithRefresh(
      () => _client.get(
        '$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final List<dynamic> list = data['playlist'];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load playlist songs');
    }
  }

  Future<void> addToPlaylist(String playlistName, YtifyResult song) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        '$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}',
        options: Options(headers: _headers, validateStatus: (status) => true),
        data: song.toJson(),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add to playlist');
    }
  }

  Future<void> createPlaylist(String name) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        '$_baseUrl/playlists',
        options: Options(headers: _headers, validateStatus: (status) => true),
        data: {'name': name},
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create playlist');
    }
  }

  Future<void> deletePlaylist(String playlistName) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        '$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}',
        options: Options(headers: _headers, validateStatus: (status) => true),
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
      () => _client.delete(
        '$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}/songs/$videoId',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove song from playlist');
    }
  }

  // --- Subscriptions ---

  Future<List<YtifyResult>> getSubscriptions() async {
    final response = await _retryWithRefresh(
      () => _client.get(
        '$_baseUrl/subscriptions',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      final List<dynamic> list = data['subscriptions'];
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load subscriptions');
    }
  }

  Future<void> addSubscription(YtifyResult channel) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        '$_baseUrl/subscriptions',
        options: Options(headers: _headers, validateStatus: (status) => true),
        data: channel.toJson(),
      ),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to subscribe');
    }
  }

  Future<void> removeSubscription(String browseId) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        '$_baseUrl/subscriptions/$browseId',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to unsubscribe');
    }
  }

  Future<List<YtifyResult>> getUpNext(String videoId) async {
    try {
      final uri = 'https://heujjsnxhjptqmanwadg.supabase.co/functions/v1/hyper-task?videoId=$videoId';
      debugPrint('UPNEXT API Request: $uri');
      final response = await _client.get(
        uri, 
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          validateStatus: (status) => true,
        ),
      );
      debugPrint('UPNEXT API Response [${response.statusCode}]');
      debugPrint('UPNEXT RAW DATA: ${response.data.toString().substring(0, (response.data.toString().length > 300) ? 300 : response.data.toString().length)}');

      if (response.statusCode != 200) {
        debugPrint('UpNext API Error: ${response.statusCode}');
        return [];
      }

      final data = response.data is String ? jsonDecode(response.data) : response.data;
      debugPrint('UPNEXT data keys: ${(data as Map).keys.toList()}');
      if (data['success'] != true) {
        debugPrint('UPNEXT: success != true, data: $data');
        return [];
      }

      final List<dynamic>? list = data['upNext'] as List?;
      if (list == null) {
        debugPrint('UPNEXT: upNext key is null');
        return [];
      }
      return list.map((e) => YtifyResult.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching Up Next: $e');
      return [];
    }
  }
}

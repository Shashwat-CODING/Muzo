import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/models/user_data.dart';
import 'package:muzo/models/artist_details.dart';
import 'package:muzo/models/album_details.dart';
import 'package:muzo/services/auth_service.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/utils/api_constants.dart';

final muzoApiServiceProvider = Provider<MuzoApiService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return MuzoApiService(storage);
});

class MuzoSearchResponse {
  final List<MuzoItem> results;
  final String? continuationToken;

  MuzoSearchResponse({required this.results, this.continuationToken});
}

class MuzoApiService {
  final StorageService _storage;
  late final AuthService _auth;
  final Dio _client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  MuzoApiService(this._storage) {
    _auth = AuthService(_storage);
  }

  static const String _baseUrl = ApiConstants.mainApiBaseUrl;

  Map<String, String> get _headers {
    final token = _storage.authToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static const Map<String, String> _ytHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  void dispose() {
    _client.close();
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

  Future<User> getProfile() async {
    final response = await _retryWithRefresh(
      () => _client.get(
        '$_baseUrl/user/profile',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return User.fromJson(data['user'] ?? data);
    } else {
      throw Exception('Failed to load profile');
    }
  }

  Future<User> updateProfile({
    String? username,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final response = await _retryWithRefresh(
      () => _client.put(
        '$_baseUrl/user/profile',
        options: Options(headers: _headers, validateStatus: (status) => true),
        data: {
          if (username != null) 'username': username,
          if (email != null) 'email': email,
          if (currentPassword != null) 'currentPassword': currentPassword,
          if (newPassword != null) 'newPassword': newPassword,
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return User.fromJson(data['user'] ?? data);
    } else {
      final error = response.data is Map ? (response.data['error'] ?? response.data['message']) : 'Update failed';
      throw Exception(error);
    }
  }

  Future<String> updateAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });

    final response = await _retryWithRefresh(
      () => _client.put(
        '$_baseUrl/user/avatar',
        options: Options(
          headers: {
            ..._headers,
            'Content-Type': 'multipart/form-data',
          },
          validateStatus: (status) => true,
        ),
        data: formData,
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;
      return data['avatar'];
    } else {
      final error = response.data is Map ? (response.data['error'] ?? response.data['message']) : 'Avatar upload failed';
      throw Exception(error);
    }
  }

  // --- History ---

  Future<void> addToHistory(MuzoItem song) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        '$_baseUrl/history',
        options: Options(headers: _headers, validateStatus: (status) => true),
        data: song.toJson(),
      ),
    );

    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
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

    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
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

    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
      throw Exception('Failed to clear history');
    }
  }

  // --- Favorites ---

  Future<void> addToFavorites(MuzoItem song) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        '$_baseUrl/favorites',
        options: Options(headers: _headers, validateStatus: (status) => true),
        data: song.toJson(),
      ),
    );

    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
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

    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
      throw Exception('Failed to remove from favorites');
    }
  }

  // --- Playlists ---

  Future<void> addToPlaylist(String playlistName, MuzoItem song) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        '$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}',
        options: Options(headers: _headers, validateStatus: (status) => true),
        data: song.toJson(),
      ),
    );

    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
      throw Exception('Failed to add to playlist');
    }
  }

  Future<void> deletePlaylist(String playlistName) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        '$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}',
        options: Options(headers: _headers, validateStatus: (status) => true),
      ),
    );

    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
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

    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
      throw Exception('Failed to remove song from playlist');
    }
  }

  // --- Subscriptions ---

  Future<void> addSubscription(Channel channel) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        '$_baseUrl/subscriptions',
        options: Options(headers: _headers, validateStatus: (status) => true),
        data: channel.toJson(),
      ),
    );

    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
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

    if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300) {
      throw Exception('Failed to unsubscribe');
    }
  }

  Future<List<MuzoItem>> getUpNext(String videoId) async {
    try {
      final uri = '${ApiConstants.extendedWorkerBaseUrl}/api/related?videoId=$videoId';
      debugPrint('UPNEXT API Request: $uri');
      final response = await _client.get(
        uri, 
        options: Options(
          headers: _ytHeaders,
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

      final List<dynamic>? list = data['songs'] as List?;
      if (list == null) {
        debugPrint('UPNEXT: songs key is null');
        return [];
      }
      return list.map((e) => MuzoItem.fromJson(Map<String, dynamic>.from(e)..putIfAbsent('resultType', () => 'song'))).toList();
    } catch (e) {
      debugPrint('Error fetching Up Next: $e');
      return [];
    }
  }
  
  // --- Search & Related (from YouTubeApiService) ---

  Future<MuzoSearchResponse> search(
    String query, {
    String filter = 'songs',
    String? continuationToken,
  }) async {
    try {
      Uri uri;
      final queryParams = {'q': query};

      // If filter is explicitly 'all', don't send the filter parameter so we get categorized results
      if (filter != 'all') {
        queryParams['filter'] = filter;
      }

      if (continuationToken != null) {
        queryParams['continuationToken'] = continuationToken;
      }

      // Route all searches through the vpn-cracked worker with query/filter params
      // Use /api/yt_search specifically for videos filter
      final endpointPath = filter == 'videos' ? '/api/yt_search' : '/api/search';
      
      uri = Uri.parse('${ApiConstants.extendedWorkerBaseUrl}$endpointPath')
          .replace(queryParameters: queryParams);

      debugPrint('YOUTUBE_API SEARCH Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(headers: _ytHeaders, validateStatus: (status) => true),
      );
      debugPrint('YOUTUBE_API SEARCH Response [${response.statusCode}]');
      debugPrint(
        'YOUTUBE_API SEARCH RAW: ${response.data.toString().substring(0, (response.data.toString().length > 300) ? 300 : response.data.toString().length)}',
      );
      if (response.statusCode != 200) {
        return MuzoSearchResponse(results: []);
      }

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      final resultsJson = data['results'] as List?;
      final token = data['continuationToken'] as String?;

      if (resultsJson == null) {
        debugPrint(
          'YOUTUBE_API SEARCH: no results key. Keys: ${(data as Map?)?.keys.toList()}',
        );
        return MuzoSearchResponse(results: []);
      }

      final results = resultsJson
          .where((e) => e is Map)
          .map((json) => MuzoItem.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      return MuzoSearchResponse(results: results, continuationToken: token);
    } catch (e) {
      debugPrint('YOUTUBE_API SEARCH error: $e');
      return MuzoSearchResponse(results: []);
    }
  }

  Future<List<MuzoItem>> getChannelVideos(String channelId) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.extendedWorkerBaseUrl}/api/feed/channels=$channelId',
      );
      debugPrint('YOUTUBE_API CHANNEL Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(headers: _ytHeaders, validateStatus: (status) => true),
      );
      if (response.statusCode != 200) return [];
      final List<dynamic> data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      return data
          .where((e) => e is Map)
          .map((json) => MuzoItem.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<MuzoItem>> getSubscriptionsFeed(
    List<String> channelIds,
  ) async {
    if (channelIds.isEmpty) return [];
    try {
      final ids = channelIds.join(',');
      final uri = Uri.parse(
        '${ApiConstants.extendedWorkerBaseUrl}/api/feed/channels=$ids',
      ).replace(queryParameters: {'preview': '1'});
      debugPrint('YOUTUBE_API SUBSCRIPTIONS Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(headers: _ytHeaders, validateStatus: (status) => true),
      );
      if (response.statusCode != 200) return [];
      final List<dynamic> data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      return data
          .where((e) => e is Map)
          .map((json) => MuzoItem.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.extendedWorkerBaseUrl}/api/search/suggestions',
      ).replace(queryParameters: {'q': query, 'music': '1'});
      debugPrint('YOUTUBE_API SUGGESTIONS Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(headers: _ytHeaders, validateStatus: (status) => true),
      );
      if (response.statusCode != 200) return [];
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      final suggestions = data['suggestions'] as List?;
      if (suggestions == null) return [];
      return suggestions.map((s) => s.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, List<MuzoItem>>> getTrendingContent() async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.extendedWorkerBaseUrl}/api/trending',
      );
      debugPrint('YOUTUBE_API TRENDING Request: $uri');
      final response = await _client.get(
        uri.toString(),
        options: Options(headers: _ytHeaders, validateStatus: (status) => true),
      );
      if (response.statusCode != 200) {
        return {'songs': [], 'videos': [], 'playlists': []};
      }
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      if (data['success'] != true || data['data'] == null) {
        return {'songs': [], 'videos': [], 'playlists': []};
      }
      final content = data['data'];

      List<MuzoItem> parseList(String key, {String? forceType}) {
        final list = content[key] as List?;
        if (list == null) return [];
        return list.where((e) => e is Map).map((json) {
          final map = Map<String, dynamic>.from(json);
          if (forceType != null) map['resultType'] = forceType;
          return MuzoItem.fromJson(map);
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

  // --- Artist & Album Details (from YtifyApiService) ---

  Future<AlbumDetails?> getAlbumDetails(String albumId) async {
    try {
      final uri = Uri.parse('${ApiConstants.extendedWorkerBaseUrl}/api/album/$albumId');
      debugPrint('YTIFY ALBUM API Request: $uri');
      final response = await http.get(uri, headers: _ytHeaders);
      debugPrint('YTIFY ALBUM API Response [${response.statusCode}]');

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
          'Muzo Album API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching album details: $e');
    }
    return null;
  }

  Future<ArtistDetails?> getArtistDetails(String browseId) async {
    try {
      final uri = Uri.parse('${ApiConstants.extendedWorkerBaseUrl}/api/artist/$browseId');
      debugPrint('YTIFY ARTIST API Request: $uri');
      final response = await http.get(uri, headers: _ytHeaders);
      debugPrint('YTIFY ARTIST API Response [${response.statusCode}]');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ArtistDetails.fromJson(data);
      } else {
        debugPrint(
          'Muzo Artist API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching artist details: $e');
    }
    return null;
  }

  Future<PlaylistDetails?> getPlaylistDetails(String playlistId) async {
    try {
      final uri = Uri.parse('${ApiConstants.extendedWorkerBaseUrl}/api/playlist/$playlistId');
      debugPrint('YTIFY PLAYLIST API Request: $uri');
      final response = await http.get(uri, headers: _ytHeaders);
      debugPrint('YTIFY PLAYLIST API Response [${response.statusCode}]');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Sometimes the top level structure might have data under 'data' or similar, but the previous test worked as follows:
        return PlaylistDetails.fromJson(data);
      } else {
        debugPrint(
          'Muzo Playlist API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching playlist details: $e');
    }
    return null;
  }
}
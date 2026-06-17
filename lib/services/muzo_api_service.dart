import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/models/user_data.dart';
import 'package:muzo/models/artist_details.dart';
import 'package:muzo/models/album_details.dart';
import 'package:muzo/services/auth_service.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/utils/api_constants.dart';
import 'package:muzo/models/user_track.dart';

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
  final http.Client _client = http.Client();

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

  Future<http.Response> _retryWithRefresh(
    Future<http.Response> Function() request, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
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
    final response = await _retryWithRefresh(
      () => _client.get(
        Uri.parse('$_baseUrl/user/data'),
        headers: _headers,
      ),
      timeout: const Duration(seconds: 200),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserData.fromJson(data);
    } else {
      throw Exception('Failed to load user data');
    }
  }

  Future<User> getProfile() async {
    final response = await _retryWithRefresh(
      () => _client.get(
        Uri.parse('$_baseUrl/user/profile'),
        headers: _headers,
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
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
        Uri.parse('$_baseUrl/user/profile'),
        headers: _headers,
        body: jsonEncode({
          if (username != null) 'username': username,
          if (email != null) 'email': email,
          if (currentPassword != null) 'currentPassword': currentPassword,
          if (newPassword != null) 'newPassword': newPassword,
        }),
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data['user'] ?? data);
    } else {
      dynamic errorMsg = 'Update failed';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['error'] ?? data['message'] ?? 'Update failed';
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  Future<String> updateAvatar(String filePath) async {
    final uri = Uri.parse('$_baseUrl/user/avatar');
    final request = http.MultipartRequest('PUT', uri);
    request.headers.addAll(_headers);
    request.files.add(await http.MultipartFile.fromPath('image', filePath));

    final response = await _retryWithRefresh(() async {
      final streamedResponse = await request.send();
      return http.Response.fromStream(streamedResponse);
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['avatar'];
    } else {
      dynamic errorMsg = 'Avatar upload failed';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['error'] ?? data['message'] ?? 'Avatar upload failed';
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  // --- History ---

  Future<void> addToHistory(MuzoItem song) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        Uri.parse('$_baseUrl/history'),
        headers: _headers,
        body: jsonEncode(song.toJson()),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to add to history');
    }
  }

  Future<void> removeFromHistory(String videoId) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        Uri.parse('$_baseUrl/history/$videoId'),
        headers: _headers,
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to remove from history');
    }
  }

  Future<void> clearHistory() async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        Uri.parse('$_baseUrl/history'),
        headers: _headers,
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to clear history');
    }
  }

  // --- Favorites ---

  Future<void> addToFavorites(MuzoItem song) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        Uri.parse('$_baseUrl/favorites'),
        headers: _headers,
        body: jsonEncode(song.toJson()),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to add to favorites');
    }
  }

  Future<void> removeFromFavorites(String videoId) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        Uri.parse('$_baseUrl/favorites/$videoId'),
        headers: _headers,
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to remove from favorites');
    }
  }

  // --- Playlists ---

  Future<void> addToPlaylist(String playlistName, MuzoItem song) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        Uri.parse('$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}'),
        headers: _headers,
        body: jsonEncode(song.toJson()),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to add to playlist');
    }
  }

  Future<void> deletePlaylist(String playlistName) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        Uri.parse('$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}'),
        headers: _headers,
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete playlist');
    }
  }

  Future<void> removeSongFromPlaylist(
    String playlistName,
    String videoId,
  ) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        Uri.parse('$_baseUrl/playlists/${Uri.encodeComponent(playlistName)}/songs/$videoId'),
        headers: _headers,
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to remove song from playlist');
    }
  }

  // --- Subscriptions ---

  Future<void> addSubscription(Channel channel) async {
    final response = await _retryWithRefresh(
      () => _client.post(
        Uri.parse('$_baseUrl/subscriptions'),
        headers: _headers,
        body: jsonEncode(channel.toJson()),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to subscribe');
    }
  }

  Future<void> removeSubscription(String browseId) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        Uri.parse('$_baseUrl/subscriptions/$browseId'),
        headers: _headers,
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to unsubscribe');
    }
  }

  Future<List<MuzoItem>> getTopOnMuzo() async {
    try {
      final uri = Uri.parse('https://veltrixcode-ytify.hf.space/api/trending');
      debugPrint('TOP ON MUZO Request: $uri');
      final response = await _client.get(
        uri,
        headers: _ytHeaders,
      );
      debugPrint('TOP ON MUZO Response [${response.statusCode}]');

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      final List? trendingList = data['trending'] as List?;
      if (trendingList == null) {
        return [];
      }

      return trendingList.where((e) => e is Map).map((json) {
        final map = Map<String, dynamic>.from(json);
        final String durationStr = map['duration'] != null ? map['duration'].toString() : '';
        int? durationSecs;
        if (map['duration'] is int) {
          durationSecs = map['duration'] as int;
        }
        return MuzoItem(
          title: map['title'] ?? 'Unknown Title',
          thumbnails: [
            MuzoThumbnail(
              url: map['thumbnail'] ?? '',
              width: 0,
              height: 0,
            ),
          ],
          resultType: 'song',
          isExplicit: false,
          videoId: map['videoId']?.toString(),
          channelName: map['channelName']?.toString(),
          artists: [
            MuzoArtist(
              name: map['channelName'] ?? 'Unknown Artist',
              id: '',
            ),
          ],
          duration: durationStr.isNotEmpty ? durationStr : null,
          durationSeconds: durationSecs,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching Top on Muzo: $e');
      return [];
    }
  }

  Future<List<MuzoItem>> getQuickPicks(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];
    try {
      final ids = videoIds.join(',');
      final uri = Uri.parse('https://nodejs-2588-3000.prg1.zerops.app/api/feed?ids=$ids&minScore=3');
      debugPrint('QUICK PICKS API Request: $uri');
      final response = await _client.get(
        uri,
        headers: _ytHeaders,
      );
      debugPrint('QUICK PICKS API Response [${response.statusCode}]');

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      
      final feedList = data['feed'] as List?;
      if (feedList == null) {
        return [];
      }

      return feedList
          .where((e) => e is Map)
          .map((json) => MuzoItem.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching quick picks: $e');
      return [];
    }
  }

  Future<List<MuzoItem>> getUpNext(String videoId) async {
    try {
      final uri = Uri.parse('${ApiConstants.extendedWorkerBaseUrl}/api/related?videoId=$videoId');
      debugPrint('UPNEXT API Request: $uri');
      final response = await _client.get(
        uri, 
        headers: _ytHeaders,
      );
      debugPrint('UPNEXT API Response [${response.statusCode}]');
      debugPrint('UPNEXT RAW DATA: ${response.body.substring(0, (response.body.length > 300) ? 300 : response.body.length)}');

      if (response.statusCode != 200) {
        debugPrint('UpNext API Error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
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
        uri,
        headers: _ytHeaders,
      );
      debugPrint('YOUTUBE_API SEARCH Response [${response.statusCode}]');
      debugPrint(
        'YOUTUBE_API SEARCH RAW: ${response.body.substring(0, (response.body.length > 300) ? 300 : response.body.length)}',
      );
      if (response.statusCode != 200) {
        return MuzoSearchResponse(results: []);
      }

      final data = jsonDecode(response.body);
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
        uri,
        headers: _ytHeaders,
      );
      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(response.body);
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
        uri,
        headers: _ytHeaders,
      );
      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(response.body);
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
        uri,
        headers: _ytHeaders,
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
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
        uri,
        headers: _ytHeaders,
      );
      if (response.statusCode != 200) {
        return {'songs': [], 'videos': [], 'playlists': []};
      }
      final data = jsonDecode(response.body);
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

        if (albumDetails.playlistId != null &&
            albumDetails.playlistId!.isNotEmpty) {
          try {
            final playlistDetails = await getPlaylistDetails(
              albumDetails.playlistId!,
            );
            if (playlistDetails != null && playlistDetails.tracks.isNotEmpty) {
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

  // --- User Tracks ---

  Future<List<UserTrack>> getUserTracks() async {
    final response = await _retryWithRefresh(
      () => _client.get(
        Uri.parse('$_baseUrl/tracks'),
        headers: _headers,
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['tracks'] ?? [];
      return list.map((e) => UserTrack.fromJson(Map<String, dynamic>.from(e))).toList();
    } else {
      dynamic errorMsg = 'Failed to load user tracks';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['error'] ?? data['message'] ?? 'Failed to load user tracks';
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  Future<UserTrack> uploadTrack({
    required String audioPath,
    String? thumbnailPath,
    required String title,
    String? description,
    bool? isPublic,
  }) async {
    final uri = Uri.parse('$_baseUrl/tracks');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_headers);
    request.fields['title'] = title;
    if (description != null) {
      request.fields['description'] = description;
    }
    if (isPublic != null) {
      request.fields['is_public'] = isPublic ? 'true' : 'false';
    }
    request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      final ext = thumbnailPath.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg', // safe default
      };
      request.files.add(await http.MultipartFile.fromPath(
        'thumbnail',
        thumbnailPath,
        contentType: MediaType.parse(mimeType),
      ));
    }

    final response = await _retryWithRefresh(() async {
      final streamedResponse = await request.send();
      return http.Response.fromStream(streamedResponse);
    });

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return UserTrack.fromJson(data['track']);
    } else {
      dynamic errorMsg = 'Upload failed';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['error'] ?? data['message'] ?? 'Upload failed';
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  Future<UserTrack> updateTrack(int id, {String? title, String? description, bool? isPublic}) async {
    final response = await _retryWithRefresh(
      () => _client.patch(
        Uri.parse('$_baseUrl/tracks/$id'),
        headers: _headers,
        body: jsonEncode({
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (isPublic != null) 'is_public': isPublic,
        }),
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return UserTrack.fromJson(data['track']);
    } else {
      dynamic errorMsg = 'Update failed';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['error'] ?? data['message'] ?? 'Update failed';
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  Future<void> deleteTrack(int id) async {
    final response = await _retryWithRefresh(
      () => _client.delete(
        Uri.parse('$_baseUrl/tracks/$id'),
        headers: _headers,
      ),
    );

    if (response.statusCode != 200) {
      dynamic errorMsg = 'Delete failed';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['error'] ?? data['message'] ?? 'Delete failed';
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  Future<Map<String, dynamic>> getCommunityFeed({
    int limit = 50,
    int offset = 0,
    String? search,
  }) async {
    final searchParam = search != null && search.trim().isNotEmpty
        ? '&search=${Uri.encodeComponent(search.trim())}'
        : '';
    final uri = Uri.parse('$_baseUrl/community?limit=$limit&offset=$offset$searchParam');
    
    debugPrint('COMMUNITY API Request: $uri');
    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
    );
    debugPrint('COMMUNITY API Response [${response.statusCode}]');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> tracksJson = data['tracks'] ?? [];
      final list = tracksJson.map((json) {
        final uploader = json['uploader'] as Map?;
        final uploaderName = uploader?['username']?.toString() ?? 'Unknown';
        final uploaderAvatar = uploader?['avatar']?.toString() ?? '';
        return MuzoItem(
          title: json['title']?.toString() ?? 'Untitled',
          thumbnails: json['thumbnail_url'] != null && json['thumbnail_url'].toString().isNotEmpty
              ? [MuzoThumbnail(url: json['thumbnail_url'].toString(), width: 0, height: 0)]
              : [],
          resultType: 'user_track',
          isExplicit: false,
          videoId: 'user_track_${json['id']}',
          description: json['description']?.toString(),
          channelName: uploaderName,
          artists: [MuzoArtist(name: uploaderName, id: uploaderAvatar)],
          audioUrl: json['audio_url']?.toString(),
        );
      }).toList();

      return {
        'tracks': list,
        'hasMore': data['hasMore'] as bool? ?? false,
        'total': data['total'] as int? ?? 0,
      };
    } else {
      dynamic errorMsg = 'Failed to load community tracks';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['error'] ?? data['message'] ?? 'Failed to load community tracks';
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }
}
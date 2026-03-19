import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/models/user_data.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/services/ytm_home.dart';
import 'package:http/http.dart' as http;

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  static const String _settingsBoxName = 'settings';
  static const String _downloadsBoxName = 'downloads';
  static const String _artistImagesBoxName = 'artist_images';
  static const String _userAvatarBoxName = 'user_avatar';
  static const String _historyBoxName = 'history_cache';
  static const String _homeBoxName = 'home_cache';
  static const String _favoritesBoxName = 'favorites_cache';
  static const String _subscriptionsBoxName = 'subscriptions_cache';
  static const String _playlistsBoxName = 'playlists_cache';

  MuzoApiService? _apiInstance;
  MuzoApiService get _api {
    _apiInstance ??= MuzoApiService(this);
    return _apiInstance!;
  }

  // In-memory state with Notifiers
  final ValueNotifier<List<MuzoItem>> _historyNotifier = ValueNotifier([]);
  final ValueNotifier<List<MuzoItem>> _favoritesNotifier = ValueNotifier([]);
  final ValueNotifier<List<Channel>> _subscriptionsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Playlist>> _playlistsNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_settingsBoxName);
    await Hive.openBox(_downloadsBoxName);
    await Hive.openBox(_artistImagesBoxName);
    await Hive.openBox(_userAvatarBoxName);
    await Hive.openBox(_historyBoxName);
    await Hive.openBox(_homeBoxName);

    // Load cached history
    final historyBox = Hive.box(_historyBoxName);
    final cachedHistory = historyBox.get('list');
    if (cachedHistory != null) {
      try {
        _historyNotifier.value = (cachedHistory as List)
            .map((e) => MuzoItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading cached history: $e');
      }
    }

    // Load cached favorites
    await Hive.openBox(_favoritesBoxName);
    final favoritesBox = Hive.box(_favoritesBoxName);
    final cachedFavorites = favoritesBox.get('list');
    if (cachedFavorites != null) {
      try {
        _favoritesNotifier.value = (cachedFavorites as List)
            .map((e) => MuzoItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading cached favorites: $e');
      }
    }

    // Load cached subscriptions
    await Hive.openBox(_subscriptionsBoxName);
    final subscriptionsBox = Hive.box(_subscriptionsBoxName);
    final cachedSubscriptions = subscriptionsBox.get('list');
    if (cachedSubscriptions != null) {
      try {
        _subscriptionsNotifier.value = (cachedSubscriptions as List)
            .map((e) => Channel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading cached subscriptions: $e');
      }
    }

    // Load cached playlists
    await Hive.openBox(_playlistsBoxName);
    final playlistsBox = Hive.box(_playlistsBoxName);
    final cachedPlaylists = playlistsBox.get('list');
    if (cachedPlaylists != null) {
      try {
        _playlistsNotifier.value = (cachedPlaylists as List)
            .map((e) => Playlist.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading cached playlists: $e');
      }
    }

    // API is now lazily initialized
    debugPrint('StorageService initialized');
  }

  Future<void> refreshAll({bool silent = false}) async {
    if (!silent) isLoadingNotifier.value = true;

    try {
      final userData = await _api.getUserData();

      // Update User Info
      await setUserInfo(
        userData.user.username,
        userData.user.email,
        avatarUrl: userData.user.avatar,
      );

      // Update History
      _historyNotifier.value = userData.history;
      _saveHistoryToCache(userData.history);

      // Update Favorites
      _favoritesNotifier.value = userData.favorites;
      _saveFavoritesToCache(userData.favorites);

      // Update Subscriptions
      _subscriptionsNotifier.value = userData.subscriptions;
      _saveSubscriptionsToCache(userData.subscriptions);

      // Update Playlists
      _playlistsNotifier.value = userData.playlists;
      _savePlaylistsToCache(userData.playlists);
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      // Fallback to individual calls if consolidated fails?
      // Or just log error. The requirement implies replacing it.
      // We can keep individual calls as fallback if we wanted resilience, but let's stick to the plan.
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  // Listenables for UI
  ValueListenable<List<MuzoItem>> get historyListenable => _historyNotifier;
  ValueListenable<List<MuzoItem>> get favoritesListenable =>
      _favoritesNotifier;
  ValueListenable<List<Channel>> get subscriptionsListenable =>
      _subscriptionsNotifier;
  ValueListenable<List<Playlist>> get playlistsListenable =>
      _playlistsNotifier;

  // Synchronous getters for current state
  List<MuzoItem> getHistory() => _historyNotifier.value;
  List<MuzoItem> getFavorites() => _favoritesNotifier.value;
  List<Channel> getSubscriptions() => _subscriptionsNotifier.value;
  List<String> getPlaylistNames() => _playlistsNotifier.value.map((p) => p.name).toList();
  List<MuzoItem> getPlaylistSongs(String name) {
    try {
      return _playlistsNotifier.value.firstWhere((p) => p.name == name).songs;
    } catch (e) {
      return [];
    }
  }

  // History
  Future<void> addToHistory(MuzoItem result) async {
    // Optimistic update
    final current = List<MuzoItem>.from(_historyNotifier.value);
    current.insert(0, result);
    _historyNotifier.value = current;
    _saveHistoryToCache(current);

    try {
      await _api.addToHistory(result);
    } catch (e) {
      debugPrint('Error adding to history API: $e');
      // We don't set errorNotifier here to avoid spamming user on every song play
    }
  }


  Future<void> removeFromHistory(String videoId) async {
    isLoadingNotifier.value = true;
    // Optimistic update
    final current = List<MuzoItem>.from(_historyNotifier.value);
    current.removeWhere((item) => item.videoId == videoId);
    _historyNotifier.value = current;
    _saveHistoryToCache(current);

    try {
      await _api.removeFromHistory(videoId);
    } catch (e) {
      errorNotifier.value = 'Failed to remove from history: $e';
      // Revert optimistic update?
      // For history, maybe not strictly necessary to revert as it's less critical,
      // but strictly speaking we should.
      // However, fetching the item back is hard without knowing what it was exactly (we removed it).
      // We could keep a reference to the removed item.
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  Future<void> clearHistory() async {
    isLoadingNotifier.value = true;
    try {
      await _api.clearHistory();
      _historyNotifier.value = [];
      _saveHistoryToCache([]);
    } catch (e) {
      errorNotifier.value = 'Failed to clear history: $e';
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  // Playlists

  Future<void> createPlaylist(String name) async {
    // Playlists are auto-created by the API when a song is added.
    // Just update local state optimistically.
    final current = List<Playlist>.from(_playlistsNotifier.value);
    if (!current.any((p) => p.name == name)) {
      current.add(Playlist(
        id: 0,
        name: name,
        createdAt: DateTime.now().toIso8601String(),
        songCount: 0,
        songs: [],
      ));
      _playlistsNotifier.value = current;
      _savePlaylistsToCache(current);
    }
  }

  Future<void> deletePlaylist(String name) async {
    isLoadingNotifier.value = true;
    try {
      await _api.deletePlaylist(name);
      final current = List<Playlist>.from(_playlistsNotifier.value);
      current.removeWhere((p) => p.name == name);
      _playlistsNotifier.value = current;
      _savePlaylistsToCache(current);
    } catch (e) {
      errorNotifier.value = 'Failed to delete playlist: $e';
    } finally {
      isLoadingNotifier.value = false;
    }
  }


  Future<void> addToPlaylist(String name, MuzoItem result) async {
    final current = List<Playlist>.from(_playlistsNotifier.value);
    final playlistIndex = current.indexWhere((p) => p.name == name);

    if (playlistIndex != -1) {
      final playlist = current[playlistIndex];
      final songs = List<MuzoItem>.from(playlist.songs);

      if (!songs.any((s) => s.videoId == result.videoId)) {
        isLoadingNotifier.value = true;
        try {
          await _api.addToPlaylist(name, result);
          songs.add(result);
          current[playlistIndex] = Playlist(
            id: playlist.id,
            name: playlist.name,
            createdAt: playlist.createdAt,
            songCount: songs.length,
            songs: songs,
          );
          _playlistsNotifier.value = current;
          _savePlaylistsToCache(current);
        } catch (e) {
          errorNotifier.value = 'Failed to add to playlist: $e';
        } finally {
          isLoadingNotifier.value = false;
        }
      }
    }
  }

  Future<void> removeFromPlaylist(String name, String videoId) async {
    final current = List<Playlist>.from(_playlistsNotifier.value);
    final playlistIndex = current.indexWhere((p) => p.name == name);

    if (playlistIndex != -1) {
      final playlist = current[playlistIndex];
      final songs = List<MuzoItem>.from(playlist.songs);

      // Optimistic
      songs.removeWhere((s) => s.videoId == videoId);
      current[playlistIndex] = Playlist(
        id: playlist.id,
        name: playlist.name,
        createdAt: playlist.createdAt,
        songCount: songs.length,
        songs: songs,
      );
      _playlistsNotifier.value = current;
      _savePlaylistsToCache(current);

      isLoadingNotifier.value = true;
      try {
        await _api.removeSongFromPlaylist(name, videoId);
      } catch (e) {
        errorNotifier.value = 'Failed to remove from playlist: $e';
      } finally {
        isLoadingNotifier.value = false;
      }
    }
  }

  // Favorites
  bool isFavorite(String videoId) {
    return _favoritesNotifier.value.any((s) => s.videoId == videoId);
  }

  Future<void> toggleFavorite(MuzoItem result) async {
    isLoadingNotifier.value = true;
    final current = List<MuzoItem>.from(_favoritesNotifier.value);
    final index = current.indexWhere((s) => s.videoId == result.videoId);

    try {
      if (index != -1) {
        // Remove
        await _api.removeFromFavorites(result.videoId!);
        current.removeAt(index);
        _favoritesNotifier.value = current;
      } else {
        // Add
        await _api.addToFavorites(result);
        current.insert(0, result);
        _favoritesNotifier.value = current;
      }
    } catch (e) {
      errorNotifier.value = 'Failed to update favorites: $e';
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  // Downloads (Local only)
  Box get _downloadsBox => Hive.box(_downloadsBoxName);
  ValueListenable<Box> get downloadsListenable => _downloadsBox.listenable();

  List<Map<String, dynamic>> getDownloads() {
    final dynamic data = _downloadsBox.get('list');
    if (data == null) return [];

    try {
      final List<dynamic> jsonList = data;
      return jsonList.map((json) => Map<String, dynamic>.from(json)).toList();
    } catch (e) {
      return [];
    }
  }

  bool isDownloaded(String videoId) {
    final downloads = getDownloads();
    return downloads.any((d) => d['videoId'] == videoId);
  }

  String? getDownloadPath(String videoId) {
    final downloads = getDownloads();
    final item = downloads.firstWhere(
      (d) => d['videoId'] == videoId,
      orElse: () => {},
    );
    return item.isNotEmpty ? item['path'] : null;
  }

  Future<void> addDownload(MuzoItem result, String path) async {
    final downloads = getDownloads();
    if (!downloads.any((d) => d['videoId'] == result.videoId)) {
      downloads.insert(0, {
        'videoId': result.videoId,
        'result': result.toJson(),
        'path': path,
        'timestamp': DateTime.now().toIso8601String(),
      });
      await _downloadsBox.put('list', downloads);
    }
  }

  Future<void> removeDownload(String videoId) async {
    final downloads = getDownloads();
    downloads.removeWhere((d) => d['videoId'] == videoId);
    await _downloadsBox.put('list', downloads);
  }

  // Subscriptions
  bool isSubscribed(String channelId) {
    return _subscriptionsNotifier.value.any(
      (s) => s.channelId == channelId || s.name == channelId,
    );
  }

  Future<void> toggleSubscription(Channel channel) async {
    isLoadingNotifier.value = true;
    final current = List<Channel>.from(_subscriptionsNotifier.value);
    final index = current.indexWhere(
      (s) => s.channelId == channel.channelId || s.name == channel.name,
    );

    try {
      if (index != -1) {
        // Unsubscribe — use channelId or name as the identifier
        final id = channel.channelId ?? channel.name;
        await _api.removeSubscription(id);
        current.removeAt(index);
        _subscriptionsNotifier.value = current;
      } else {
        // Subscribe
        await _api.addSubscription(channel);
        current.insert(0, channel);
        _subscriptionsNotifier.value = current;
      }
      _saveSubscriptionsToCache(current);
    } catch (e) {
      errorNotifier.value = 'Failed to update subscription: $e';
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  // Artist Images (Local Cache)
  Box get _artistImagesBox => Hive.box(_artistImagesBoxName);
  ValueListenable<Box> get artistImagesListenable =>
      _artistImagesBox.listenable();

  String? getArtistImage(String artistId) {
    return _artistImagesBox.get(artistId);
  }

  Future<void> setArtistImage(String artistId, String url) async {
    await _artistImagesBox.put(artistId, url);
  }

  final _fetchingArtists = <String>{};

  Future<void> fetchAndCacheArtistImage(String artistId) async {
    if (_fetchingArtists.contains(artistId)) return;
    if (getArtistImage(artistId) != null) return;

    _fetchingArtists.add(artistId);

    try {
      final apiService = _api;
      final details = await apiService.getArtistDetails(artistId);
      if (details != null && details.artistAvatar.isNotEmpty) {
        await setArtistImage(artistId, details.artistAvatar);
      } else {
        await setArtistImage(artistId, 'INVALID_ARTIST');
      }
    } catch (e) {
      debugPrint('Error fetching artist image for $artistId: $e');
    } finally {
      _fetchingArtists.remove(artistId);
    }
  }

  // Settings
  Box get _settingsBox => Hive.box(_settingsBoxName);
  ValueListenable<Box> get settingsListenable => _settingsBox.listenable();

  String? get rapidApiKey => _settingsBox.get('rapidApiKey');

  Future<void> setRapidApiKey(String? value) async {
    if (value == null || value.isEmpty) {
      await _settingsBox.delete('rapidApiKey');
    } else {
      await _settingsBox.put('rapidApiKey', value);
    }
  }

  String get rapidApiCountryCode =>
      _settingsBox.get('rapidApiCountryCode', defaultValue: 'IN');
  Future<void> setRapidApiCountryCode(String code) =>
      _settingsBox.put('rapidApiCountryCode', code);

  // User Info
  String? get username => _settingsBox.get('username');
  String? get email => _settingsBox.get('email');
  String? get avatarUrl => _settingsBox.get('avatarUrl');
  String? get authToken => _settingsBox.get('authToken');

  Future<void> setUserInfo(
    String username,
    String email, {
    String? avatarUrl,
  }) async {
    await _settingsBox.put('username', username);
    await _settingsBox.put('email', email);
    if (avatarUrl != null) {
      await _settingsBox.put('avatarUrl', avatarUrl);
      // Fetch avatar if it's a new URL or not cached
      fetchAndCacheUserAvatar();
    }
  }

  Future<void> setAuthToken(String token) async {
    await _settingsBox.put('authToken', token);
    // Refresh data when token is set (login). We don't await this so it doesn't block the UI.
    refreshAll();
  }

  Future<void> clearUserSession() async {
    await _settingsBox.delete('username');
    await _settingsBox.delete('email');
    await _settingsBox.delete('avatarUrl');
    await _settingsBox.delete('authToken');
    await _userAvatarBox.delete('avatar_svg');
    // Clear in-memory state
    _playlistsNotifier.value = [];
    _subscriptionsNotifier.value = [];
  }

  // User Avatar (Local Cache)
  Box get _userAvatarBox => Hive.box(_userAvatarBoxName);
  ValueListenable<Box> get userAvatarListenable => _userAvatarBox.listenable();

  String? getUserAvatar() {
    return _userAvatarBox.get('avatar_svg');
  }

  Future<void> fetchAndCacheUserAvatar() async {
    final user = username;
    final urlOverride = avatarUrl;
    if (user == null && urlOverride == null) return;

    final url = urlOverride ?? 'https://api.dicebear.com/9.x/rings/svg?seed=$user';
    
    // Only fetch and cache if it's an SVG (DiceBear or explicitly .svg)
    if (url.contains('dicebear') || url.contains('.svg')) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          await _userAvatarBox.put('avatar_svg', response.body);
        } else {
          debugPrint('Failed to fetch avatar: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error fetching user avatar: $e');
      }
    } else {
      // If it's a regular image format (JPG, PNG, etc.), clear the SVG cache
      // to ensure the UI falls back to network image correctly.
      await _userAvatarBox.delete('avatar_svg');
    }
  }

  // Auto Queue Setting
  bool get isAutoQueueEnabled =>
      _settingsBox.get('isAutoQueueEnabled', defaultValue: true);
  Future<void> setAutoQueueEnabled(bool value) =>
      _settingsBox.put('isAutoQueueEnabled', value);

  // Lofi Settings
  double get lofiSpeed => _settingsBox.get('lofiSpeed', defaultValue: 0.85);
  Future<void> setLofiSpeed(double value) async {
    await _settingsBox.put('lofiSpeed', value);
  }

  double get lofiPitch => _settingsBox.get('lofiPitch', defaultValue: 0.85);
  Future<void> setLofiPitch(double value) async {
    await _settingsBox.put('lofiPitch', value);
  }

  // App Font
  String get appFontFamily => _settingsBox.get('appFontFamily', defaultValue: 'Outfit');
  Future<void> setAppFontFamily(String value) =>
      _settingsBox.put('appFontFamily', value);

  // App Links
  bool get handleAppLinks => _settingsBox.get('handleAppLinks', defaultValue: true);
  Future<void> setHandleAppLinks(bool value) async {
    await _settingsBox.put('handleAppLinks', value);
  }

  // YTM Home Page Sections
  bool get showYtmHome => _settingsBox.get('showYtmHome', defaultValue: true);
  Future<void> setShowYtmHome(bool value) async {
    await _settingsBox.put('showYtmHome', value);
  }

  // Spotify Import Announcement
  bool get hasSeenSpotifyAnnouncement => _settingsBox.get('hasSeenSpotifyAnnouncement', defaultValue: false);
  Future<void> setHasSeenSpotifyAnnouncement(bool value) async {
    await _settingsBox.put('hasSeenSpotifyAnnouncement', value);
  }

  // Cache Helpers
  Future<void> _saveHistoryToCache(List<MuzoItem> history) async {
    try {
      final box = Hive.box(_historyBoxName);
      await box.put('list', history.map((e) => e.toCacheJson()).toList());
    } catch (e) {
      debugPrint('Error saving history cache: $e');
    }
  }

  Future<void> _saveFavoritesToCache(List<MuzoItem> favorites) async {
    try {
      final box = Hive.box(_favoritesBoxName);
      await box.put('list', favorites.map((e) => e.toCacheJson()).toList());
    } catch (e) {
      debugPrint('Error saving favorites cache: $e');
    }
  }

  Future<void> _saveSubscriptionsToCache(
    List<Channel> subscriptions,
  ) async {
    try {
      final box = Hive.box(_subscriptionsBoxName);
      await box.put('list', subscriptions.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error saving subscriptions cache: $e');
    }
  }

  Future<void> _savePlaylistsToCache(
    List<Playlist> playlists,
  ) async {
    try {
      final box = Hive.box(_playlistsBoxName);
      await box.put('list', playlists.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error saving playlists cache: $e');
    }
  }

  // Home Screen Cache
  Box get _homeBox => Hive.box(_homeBoxName);

  List<HomeSection> getHomeCache() {
    final cached = _homeBox.get('sections');
    if (cached != null) {
      try {
        return (cached as List)
            .map((e) => HomeSection.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading home cache: $e');
      }
    }
    return [];
  }

  Future<void> setHomeCache(List<HomeSection> sections) async {
    try {
      await _homeBox.put('sections', sections.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error saving home cache: $e');
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ytx/models/ytify_result.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  static const String _historyBoxName = 'history';
  static const String _playlistsBoxName = 'playlists';
  static const String _settingsBoxName = 'settings';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_historyBoxName);
    await Hive.openBox(_playlistsBoxName);
    await Hive.openBox(_settingsBoxName);
    await _initFavorites();
    await _initDownloads();
    await _initSubscriptions();
  }

  Box get _historyBox => Hive.box(_historyBoxName);
  Box get _playlistsBox => Hive.box(_playlistsBoxName);

  ValueListenable<Box> get historyListenable => _historyBox.listenable();
  ValueListenable<Box> get playlistsListenable => _playlistsBox.listenable();

  // History
  Future<void> addToHistory(YtifyResult result) async {
    // Avoid duplicates: remove if exists, then add to front
    final history = getHistory();
    history.removeWhere((item) => item.videoId == result.videoId);
    history.insert(0, result);
    
    // Limit history size (e.g., 50)
    if (history.length > 50) {
      history.removeLast();
    }

    final jsonList = history.map((item) => item.toJson()).toList();
    await _historyBox.put('list', jsonList);
  }

  List<YtifyResult> getHistory() {
    final dynamic data = _historyBox.get('list');
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = data;
      return jsonList.map((json) => YtifyResult.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      print('Error parsing history: $e');
      return [];
    }
  }

  Future<void> removeFromHistory(String videoId) async {
    final history = getHistory();
    history.removeWhere((item) => item.videoId == videoId);
    final jsonList = history.map((item) => item.toJson()).toList();
    await _historyBox.put('list', jsonList);
  }

  Future<void> clearHistory() async {
    await _historyBox.delete('list');
  }

  // Playlists
  // Structure: Map<String, List<YtifyResult>> where key is playlist name
  
  List<String> getPlaylistNames() {
    return _playlistsBox.keys.cast<String>().toList();
  }

  Future<void> createPlaylist(String name) async {
    if (!_playlistsBox.containsKey(name)) {
      await _playlistsBox.put(name, []);
    }
  }

  Future<void> deletePlaylist(String name) async {
    await _playlistsBox.delete(name);
  }

  List<YtifyResult> getPlaylistSongs(String name) {
    final dynamic data = _playlistsBox.get(name);
    if (data == null) return [];

    try {
      final List<dynamic> jsonList = data;
      return jsonList.map((json) => YtifyResult.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addToPlaylist(String name, YtifyResult result) async {
    final songs = getPlaylistSongs(name);
    // Check for duplicates
    if (!songs.any((s) => s.videoId == result.videoId)) {
      songs.add(result);
      final jsonList = songs.map((item) => item.toJson()).toList();
      await _playlistsBox.put(name, jsonList);
    }
  }

  Future<void> removeFromPlaylist(String name, String videoId) async {
    final songs = getPlaylistSongs(name);
    songs.removeWhere((s) => s.videoId == videoId);
    final jsonList = songs.map((item) => item.toJson()).toList();
    await _playlistsBox.put(name, jsonList);
  }

  // Favorites
  static const String _favoritesBoxName = 'favorites';
  Box get _favoritesBox => Hive.box(_favoritesBoxName);
  ValueListenable<Box> get favoritesListenable => _favoritesBox.listenable();

  Future<void> _initFavorites() async {
    await Hive.openBox(_favoritesBoxName);
  }

  List<YtifyResult> getFavorites() {
    final dynamic data = _favoritesBox.get('list');
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = data;
      return jsonList.map((json) => YtifyResult.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      return [];
    }
  }

  bool isFavorite(String videoId) {
    final favorites = getFavorites();
    return favorites.any((s) => s.videoId == videoId);
  }

  Future<void> toggleFavorite(YtifyResult result) async {
    final favorites = getFavorites();
    final index = favorites.indexWhere((s) => s.videoId == result.videoId);
    
    if (index != -1) {
      favorites.removeAt(index);
    } else {
      favorites.insert(0, result);
    }
    
    final jsonList = favorites.map((item) => item.toJson()).toList();
    await _favoritesBox.put('list', jsonList);
  }

  // Downloads
  static const String _downloadsBoxName = 'downloads';
  Box get _downloadsBox => Hive.box(_downloadsBoxName);
  ValueListenable<Box> get downloadsListenable => _downloadsBox.listenable();

  Future<void> _initDownloads() async {
    await Hive.openBox(_downloadsBoxName);
  }

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
    final item = downloads.firstWhere((d) => d['videoId'] == videoId, orElse: () => {});
    return item.isNotEmpty ? item['path'] : null;
  }

  Future<void> addDownload(YtifyResult result, String path) async {
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
  static const String _subscriptionsBoxName = 'subscriptions';
  Box get _subscriptionsBox => Hive.box(_subscriptionsBoxName);
  ValueListenable<Box> get subscriptionsListenable => _subscriptionsBox.listenable();

  Future<void> _initSubscriptions() async {
    await Hive.openBox(_subscriptionsBoxName);
  }

  List<YtifyResult> getSubscriptions() {
    final dynamic data = _subscriptionsBox.get('list');
    if (data == null) return [];
    
    try {
      final List<dynamic> jsonList = data;
      return jsonList.map((json) => YtifyResult.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      return [];
    }
  }

  bool isSubscribed(String channelId) {
    final subscriptions = getSubscriptions();
    return subscriptions.any((s) => s.browseId == channelId);
  }

  Future<void> toggleSubscription(YtifyResult channel) async {
    final subscriptions = getSubscriptions();
    final index = subscriptions.indexWhere((s) => s.browseId == channel.browseId);
    
    if (index != -1) {
      subscriptions.removeAt(index);
    } else {
      subscriptions.insert(0, channel);
    }
    
    final jsonList = subscriptions.map((item) => item.toJson()).toList();
    await _subscriptionsBox.put('list', jsonList);
  }

  // Settings
  Box get _settingsBox => Hive.box(_settingsBoxName);
  ValueListenable<Box> get settingsListenable => _settingsBox.listenable();

  bool get autoQueueEnabled => _settingsBox.get('autoQueueEnabled', defaultValue: true);

  Future<void> setAutoQueueEnabled(bool value) async {
    await _settingsBox.put('autoQueueEnabled', value);
  }

  String? get rapidApiKey => _settingsBox.get('rapidApiKey');

  Future<void> setRapidApiKey(String? value) async {
    if (value == null || value.isEmpty) {
      await _settingsBox.delete('rapidApiKey');
    } else {
      await _settingsBox.put('rapidApiKey', value);
    }
  }

  String get rapidApiCountryCode => _settingsBox.get('rapidApiCountryCode', defaultValue: 'IN');
  Future<void> setRapidApiCountryCode(String code) => _settingsBox.put('rapidApiCountryCode', code);
}


import 'package:muzo/models/ytify_result.dart';

class UserData {
  final User user;
  final Stats stats;
  final List<YtifyResult> history;
  final List<YtifyResult> favorites;
  final List<YtifyResult> subscriptions;
  final List<Playlist> playlists;

  UserData({
    required this.user,
    required this.stats,
    required this.history,
    required this.favorites,
    required this.subscriptions,
    required this.playlists,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      user: User.fromJson(json['user'] ?? {}),
      stats: Stats.fromJson(json['stats'] ?? {}),
      history:
          (json['history'] as List?)
              ?.map((e) => YtifyResult.fromJson(e))
              .toList() ??
          [],
      favorites:
          (json['favorites'] as List?)
              ?.map((e) => YtifyResult.fromJson(e))
              .toList() ??
          [],
      subscriptions:
          (json['subscriptions'] as List?)
              ?.map((e) => YtifyResult.fromJson(e))
              .toList() ??
          [],
      playlists:
          (json['playlists'] as List?)
              ?.map((e) => Playlist.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class User {
  final int id;
  final String username;
  final String email;

  User({required this.id, required this.username, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
    );
  }
}

class Stats {
  final int historyCount;
  final int favoritesCount;
  final int subscriptionsCount;
  final int playlistsCount;
  final int totalPlaylistSongs;

  Stats({
    required this.historyCount,
    required this.favoritesCount,
    required this.subscriptionsCount,
    required this.playlistsCount,
    required this.totalPlaylistSongs,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      historyCount: json['history_count'] ?? 0,
      favoritesCount: json['favorites_count'] ?? 0,
      subscriptionsCount: json['subscriptions_count'] ?? 0,
      playlistsCount: json['playlists_count'] ?? 0,
      totalPlaylistSongs: json['total_playlist_songs'] ?? 0,
    );
  }
}

class Playlist {
  final int id;
  final String name;
  final String createdAt;
  final int songCount;
  final List<YtifyResult> songs;

  Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.songCount,
    required this.songs,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      createdAt: json['created_at'] ?? '',
      songCount: json['song_count'] ?? 0,
      songs:
          (json['songs'] as List?)
              ?.map((e) => YtifyResult.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created_at': createdAt,
    'song_count': songCount,
    'songs': songs.map((e) => e.toJson()).toList(),
  };
}

import 'package:muzo/models/muzo_item.dart';

// Channel schema returned by the subscriptions endpoint
class Channel {
  final String name;
  final String? channelId;
  final String? avatar;

  Channel({required this.name, this.channelId, this.avatar});

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      name: json['name']?.toString() ?? '',
      channelId: json['channelId']?.toString(),
      avatar: json['avatar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'channelId': channelId,
    'avatar': avatar,
  };
}

class UserData {
  final User user;
  final Stats stats;
  final List<MuzoItem> history;
  final List<MuzoItem> favorites;
  final List<Channel> subscriptions;
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
    List<MuzoItem> parseUniqueResults(String key) {
      final list = (json[key] as List?)?.map((e) => MuzoItem.fromJson(Map<String, dynamic>.from(e))).toList() ?? [];
      final seen = <String>{};
      final unique = <MuzoItem>[];
      for (var item in list) {
        if (item.videoId != null && !seen.contains(item.videoId)) {
          seen.add(item.videoId!);
          unique.add(item);
        }
      }
      return unique;
    }

    List<Channel> parseUniqueChannels(String key) {
      final list = (json[key] as List?)?.map((e) => Channel.fromJson(Map<String, dynamic>.from(e))).toList() ?? [];
      final seen = <String>{};
      final unique = <Channel>[];
      for (var item in list) {
        if (item.channelId != null && !seen.contains(item.channelId)) {
          seen.add(item.channelId!);
          unique.add(item);
        }
      }
      return unique;
    }

    return UserData(
      user: User.fromJson(json['user'] ?? {}),
      stats: Stats.fromJson(json['stats'] ?? {}),
      history: (json['history'] as List?)?.map((e) => MuzoItem.fromJson(Map<String, dynamic>.from(e))).toList() ?? [],
      favorites: parseUniqueResults('favorites'),
      subscriptions: parseUniqueChannels('subscriptions'),
      playlists:
          (json['playlists'] as List?)?.map((e) => Playlist.fromJson(Map<String, dynamic>.from(e))).toList() ?? [],
    );
  }
}

class User {
  final int id;
  final String username;
  final String email;
  final String? avatar;
  final bool hasPassword;
  final bool hasGoogle;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
    this.hasPassword = false,
    this.hasGoogle = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      hasPassword: json['has_password'] ?? false,
      hasGoogle: json['has_google'] ?? false,
    );
  }
}

class Stats {
  final int historyCount;
  final int favoritesCount;
  final int subscriptionsCount;
  final int playlistsCount;

  Stats({
    required this.historyCount,
    required this.favoritesCount,
    required this.subscriptionsCount,
    required this.playlistsCount,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      historyCount: json['history_count'] ?? 0,
      favoritesCount: json['favorites_count'] ?? 0,
      subscriptionsCount: json['subscriptions_count'] ?? 0,
      playlistsCount: json['playlists_count'] ?? 0,
    );
  }
}

class Playlist {
  final int id;
  final String name;
  final String createdAt;
  final int songCount;
  final List<MuzoItem> songs;

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
      name: json['name']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      songCount: json['song_count'] ?? 0,
      songs:
          (json['songs'] as List?)?.map((e) => MuzoItem.fromJson(Map<String, dynamic>.from(e))).toList() ?? [],
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

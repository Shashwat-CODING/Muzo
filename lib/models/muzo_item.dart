class MuzoItem {
  final String title;
  final List<MuzoThumbnail> thumbnails;
  final String resultType;
  final bool isExplicit;
  final String? videoId;
  final String? browseId;
  final String? duration;
  final int? durationSeconds;
  final String? videoType;
  final List<MuzoArtist>? artists;
  
  String get displayArtist {
    if (artists != null && artists!.isNotEmpty) {
      return artists!.map((a) => a.name).join(', ');
    }
    if (channelName != null && channelName!.isNotEmpty) {
      return channelName!;
    }
    if (videoType != null && videoType!.isNotEmpty) {
      return videoType!;
    }
    return 'Unknown';
  }

  final MuzoAlbum? album;
  final String? subscriberCount;
  final String? videoCount;
  final String? description;
  final String? views;
  final String? uploaded;
  final String? category;
  final String? channelName;
  final String? addedAt;
  final dynamic dbId;

  MuzoItem({
    required this.title,
    required this.thumbnails,
    required this.resultType,
    required this.isExplicit,
    this.videoId,
    this.browseId,
    this.duration,
    this.durationSeconds,
    this.videoType,
    this.artists,
    this.album,
    this.views,
    this.subscriberCount,
    this.videoCount,
    this.description,
    this.uploaded,
    this.category,
    this.channelName,
    this.addedAt,
    this.dbId,
  });

  factory MuzoItem.fromJson(Map<String, dynamic> json) {
    String type = json['resultType']?.toString() ?? json['type']?.toString() ?? '';

    // Fallback logic for resultType
    if (type.isEmpty || type == 'unknown') {
      if (json['videoType'] != null) {
        type = 'video';
      } else if (json['duration'] != null) {
        type =
            'video'; // Most likely a video if it has a duration and no other type
      }
    }

    // Handle thumbnails: could be a list or a single string (for channels)
    List<MuzoThumbnail> parsedThumbnails = [];
    if (json['thumbnails'] is List) {
      parsedThumbnails = (json['thumbnails'] as List)
          .map((t) {
            if (t is Map) {
              return MuzoThumbnail.fromJson(Map<String, dynamic>.from(t));
            }
            if (t is String) {
              return MuzoThumbnail(
                url: t.startsWith('//') ? 'https:$t' : t,
                width: 0,
                height: 0,
              );
            }
            return null;
          })
          .whereType<MuzoThumbnail>()
          .toList();
    } else if (json['thumbnail'] is String) {
      String thumbUrl = json['thumbnail'];
      if (thumbUrl.startsWith('//')) {
        thumbUrl = 'https:$thumbUrl';
      }
      parsedThumbnails = [MuzoThumbnail(url: thumbUrl, width: 0, height: 0)];
    } else if (json['thumbnails'] == null &&
        (json['videoId'] != null || json['id'] != null)) {
      // Generate thumbnail from video ID if missing
      final vid = json['videoId'] ?? json['id'];
      parsedThumbnails = [
        MuzoThumbnail(
          url: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
          width: 480,
          height: 360,
        ),
      ];
    }

    // Duration can be a plain string ("3:32") or an object ({"seconds": 212, "label": "3:32"})
    final rawDuration = json['duration'];
    final String? durationLabel = rawDuration is Map
        ? (rawDuration['label'] ?? rawDuration['text'])?.toString()
        : rawDuration?.toString();

    int? seconds = json['duration_seconds'];
    if (seconds == null && rawDuration is Map && rawDuration['seconds'] != null) {
      seconds = rawDuration['seconds'] as int?;
    }
    if (seconds == null && durationLabel != null) {
      final parts = durationLabel.split(':');
      if (parts.length == 2) {
        seconds = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      } else if (parts.length == 3) {
        seconds = (int.tryParse(parts[0]) ?? 0) * 3600 +
            (int.tryParse(parts[1]) ?? 0) * 60 +
            (int.tryParse(parts[2]) ?? 0);
      }
    }

    return MuzoItem(
      title: json['title']?.toString() ?? '',
      thumbnails: parsedThumbnails,
      resultType: type,
      isExplicit: json['isExplicit'] ?? false,
      videoId: (json['videoId'] ?? json['id'])?.toString(),
      browseId: (json['browseId'] ?? json['channelId'] ?? json['authorId'])?.toString(),
      duration: durationLabel,
      durationSeconds: seconds,
      videoType: json['videoType']?.toString(),
      artists:
          (json['artists'] as List?)
              ?.map((a) {
                if (a is Map) {
                  return MuzoArtist.fromJson(Map<String, dynamic>.from(a));
                }
                if (a is String) return MuzoArtist(name: a, id: null);
                return null;
              })
              .whereType<MuzoArtist>()
              .toList() ??
          (json['channel'] != null
              ? [
                  MuzoArtist(
                    name: json['channel']['name'] ?? '',
                    id: json['channel']['id'],
                  ),
                ]
              : (json['author'] != null
                    ? [MuzoArtist(name: json['author'], id: json['authorId'])]
                    : (json['artist'] != null
                          ? [MuzoArtist(name: json['artist'], id: null)]
                          : null))),
      album: json['album'] is Map
          ? MuzoAlbum.fromJson(Map<String, dynamic>.from(json['album']))
          : (json['album'] is String
                ? MuzoAlbum(name: json['album'], id: '')
                : null),
      views: json['views'] is Map
          ? (json['views']['short'] ?? json['views']['text'])?.toString()
          : json['views']?.toString(),
      subscriberCount: json['subscriberCount']?.toString(),
      videoCount: json['videoCount']?.toString(),
      description: json['description']?.toString(),
      uploaded: json['uploaded']?.toString(),
      category: json['category']?.toString(),
      channelName: json['channelName']?.toString(),
      addedAt: json['added_at']?.toString(),
      dbId: json['db_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'thumbnails': thumbnails.map((t) => t.toJson()).toList(),
      'resultType': resultType,
      'isExplicit': isExplicit,
      'videoId': videoId,
      'browseId': browseId,
      'duration': duration,
      'duration_seconds': durationSeconds,
      'videoType': videoType,
      'artists': artists?.map((a) => a.toJson()).toList(),
      'album': album?.toJson(),
      'views': views,
      'subscriberCount': subscriberCount,
      'videoCount': videoCount,
      'description': description,
      'uploaded': uploaded,
      'category': category,
      'channelName': channelName,
      'added_at': addedAt,
      'db_id': dbId,
    };
  }

  Map<String, dynamic> toCacheJson() {
    return toJson();
  }

  MuzoItem copyWith({
    String? title,
    List<MuzoThumbnail>? thumbnails,
    String? resultType,
    bool? isExplicit,
    String? videoId,
    String? browseId,
    String? duration,
    int? durationSeconds,
    String? videoType,
    List<MuzoArtist>? artists,
    MuzoAlbum? album,
    String? views,
    String? subscriberCount,
    String? videoCount,
    String? description,
    String? uploaded,
    String? category,
    String? channelName,
  }) {
    return MuzoItem(
      title: title ?? this.title,
      thumbnails: thumbnails ?? this.thumbnails,
      resultType: resultType ?? this.resultType,
      isExplicit: isExplicit ?? this.isExplicit,
      videoId: videoId ?? this.videoId,
      browseId: browseId ?? this.browseId,
      duration: duration ?? this.duration,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      videoType: videoType ?? this.videoType,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      views: views ?? this.views,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      videoCount: videoCount ?? this.videoCount,
      description: description ?? this.description,
      uploaded: uploaded ?? this.uploaded,
      category: category ?? this.category,
      channelName: channelName ?? this.channelName,
      addedAt: addedAt ?? this.addedAt,
      dbId: dbId ?? this.dbId,
    );
  }
}

class MuzoThumbnail {
  final String url;
  final int width;
  final int height;

  MuzoThumbnail({
    required this.url,
    required this.width,
    required this.height,
  });

  factory MuzoThumbnail.fromJson(Map<String, dynamic> json) {
    String url = json['url']?.toString() ?? '';
    // Replace low resolution pattern with higher resolution
    if (url.contains('=w120-h120-l90-rj')) {
      url = url.replaceAll('=w120-h120-l90-rj', '=w220-h220');
    }
    return MuzoThumbnail(
      url: url,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'width': width, 'height': height};
  }
}

class MuzoArtist {
  final String name;
  final String? id;

  MuzoArtist({required this.name, this.id});

  factory MuzoArtist.fromJson(Map<String, dynamic> json) {
    return MuzoArtist(
      name: json['name']?.toString() ?? '',
      id: json['id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'id': id};
  }
}

class MuzoAlbum {
  final String name;
  final String id;

  MuzoAlbum({required this.name, required this.id});

  factory MuzoAlbum.fromJson(Map<String, dynamic> json) {
    return MuzoAlbum(
      name: json['name']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'id': id};
  }
}

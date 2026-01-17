class YtifyResult {
  final String title;
  final List<YtifyThumbnail> thumbnails;
  final String resultType;
  final bool isExplicit;
  final String? videoId;
  final String? browseId;
  final String? duration;
  final int? durationSeconds;
  final String? videoType;
  final List<YtifyArtist>? artists;
  final YtifyAlbum? album;
  final String? subscriberCount;
  final String? videoCount;
  final String? description;
  final String? views;
  final String? uploaded;

  YtifyResult({
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
  });

  factory YtifyResult.fromJson(Map<String, dynamic> json) {
    String type = json['resultType'] ?? json['type'] ?? '';

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
    List<YtifyThumbnail> parsedThumbnails = [];
    if (json['thumbnails'] is List) {
      parsedThumbnails = (json['thumbnails'] as List)
          .map((t) {
            if (t is Map) {
              return YtifyThumbnail.fromJson(Map<String, dynamic>.from(t));
            }
            if (t is String) {
              return YtifyThumbnail(
                url: t.startsWith('//') ? 'https:$t' : t,
                width: 0,
                height: 0,
              );
            }
            return null;
          })
          .whereType<YtifyThumbnail>()
          .toList();
    } else if (json['thumbnail'] is String) {
      String thumbUrl = json['thumbnail'];
      if (thumbUrl.startsWith('//')) {
        thumbUrl = 'https:$thumbUrl';
      }
      parsedThumbnails = [YtifyThumbnail(url: thumbUrl, width: 0, height: 0)];
    } else if (json['thumbnails'] == null &&
        (json['videoId'] != null || json['id'] != null)) {
      // Generate thumbnail from video ID if missing
      final vid = json['videoId'] ?? json['id'];
      parsedThumbnails = [
        YtifyThumbnail(
          url: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
          width: 480,
          height: 360,
        ),
      ];
    }

    int? seconds = json['duration_seconds'];
    if (seconds == null && json['duration'] is String) {
      final parts = (json['duration'] as String).split(':');
      if (parts.length == 2) {
        seconds =
            (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      } else if (parts.length == 3) {
        seconds =
            (int.tryParse(parts[0]) ?? 0) * 3600 +
            (int.tryParse(parts[1]) ?? 0) * 60 +
            (int.tryParse(parts[2]) ?? 0);
      }
    }

    return YtifyResult(
      title: json['title'] ?? '',
      thumbnails: parsedThumbnails,
      resultType: type,
      isExplicit: json['isExplicit'] ?? false,
      videoId: json['videoId'] ?? json['id'], // Handle both videoId and id
      browseId: json['browseId'] ?? json['channelId'] ?? json['authorId'],
      duration: json['duration'],
      durationSeconds: seconds,
      videoType: json['videoType'],
      artists:
          (json['artists'] as List?)
              ?.map((a) {
                if (a is Map) {
                  return YtifyArtist.fromJson(Map<String, dynamic>.from(a));
                }
                if (a is String) return YtifyArtist(name: a, id: null);
                return null;
              })
              .whereType<YtifyArtist>()
              .toList() ??
          (json['channel'] != null
              ? [
                  YtifyArtist(
                    name: json['channel']['name'] ?? '',
                    id: json['channel']['id'],
                  ),
                ]
              : (json['author'] != null
                    ? [YtifyArtist(name: json['author'], id: json['authorId'])]
                    : (json['artist'] != null
                          ? [YtifyArtist(name: json['artist'], id: null)]
                          : null))),
      album: json['album'] is Map
          ? YtifyAlbum.fromJson(Map<String, dynamic>.from(json['album']))
          : (json['album'] is String
                ? YtifyAlbum(name: json['album'], id: '')
                : null),
      views: json['views'] is Map
          ? json['views']['short'] ?? json['views']['text']
          : json['views']?.toString(),
      subscriberCount: json['subscriberCount'],
      videoCount: json['videoCount'],
      description: json['description'],
      uploaded: json['uploaded']?.toString(),
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
    };
  }

  YtifyResult copyWith({
    String? title,
    List<YtifyThumbnail>? thumbnails,
    String? resultType,
    bool? isExplicit,
    String? videoId,
    String? browseId,
    String? duration,
    int? durationSeconds,
    String? videoType,
    List<YtifyArtist>? artists,
    YtifyAlbum? album,
    String? views,
    String? subscriberCount,
    String? videoCount,
    String? description,
    String? uploaded,
  }) {
    return YtifyResult(
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
    );
  }
}

class YtifyThumbnail {
  final String url;
  final int width;
  final int height;

  YtifyThumbnail({
    required this.url,
    required this.width,
    required this.height,
  });

  factory YtifyThumbnail.fromJson(Map<String, dynamic> json) {
    String url = json['url'] ?? '';
    // Replace low resolution pattern with higher resolution
    if (url.contains('=w120-h120-l90-rj')) {
      url = url.replaceAll('=w120-h120-l90-rj', '=w220-h220');
    }
    return YtifyThumbnail(
      url: url,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'width': width, 'height': height};
  }
}

class YtifyArtist {
  final String name;
  final String? id;

  YtifyArtist({required this.name, this.id});

  factory YtifyArtist.fromJson(Map<String, dynamic> json) {
    return YtifyArtist(name: json['name'] ?? '', id: json['id']);
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'id': id};
  }
}

class YtifyAlbum {
  final String name;
  final String id;

  YtifyAlbum({required this.name, required this.id});

  factory YtifyAlbum.fromJson(Map<String, dynamic> json) {
    return YtifyAlbum(name: json['name'] ?? '', id: json['id'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'id': id};
  }
}

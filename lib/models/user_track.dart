import 'package:muzo/models/muzo_item.dart';

class UserTrack {
  final int id;
  final int userId;
  final String title;
  final String? description;
  final String audioUrl;
  final String audioFilename;
  final String? thumbnailUrl;
  final String? thumbFilename;
  final int? fileSize;
  final bool isPublic;
  final String uploadedAt;

  UserTrack({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.audioUrl,
    required this.audioFilename,
    this.thumbnailUrl,
    this.thumbFilename,
    this.fileSize,
    required this.isPublic,
    required this.uploadedAt,
  });

  factory UserTrack.fromJson(Map<String, dynamic> json) {
    return UserTrack(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      audioUrl: json['audio_url'] as String,
      audioFilename: json['audio_filename'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      thumbFilename: json['thumb_filename'] as String?,
      fileSize: json['file_size'] as int?,
      isPublic: json['is_public'] == 1 || json['is_public'] == true || json['is_public'] == 'true',
      uploadedAt: json['uploaded_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'audio_url': audioUrl,
      'audio_filename': audioFilename,
      'thumbnail_url': thumbnailUrl,
      'thumb_filename': thumbFilename,
      'file_size': fileSize,
      'is_public': isPublic ? 1 : 0,
      'uploaded_at': uploadedAt,
    };
  }
}

extension UserTrackExtension on UserTrack {
  MuzoItem toMuzoItem() {
    return MuzoItem(
      title: title,
      thumbnails: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
          ? [MuzoThumbnail(url: thumbnailUrl!, width: 0, height: 0)]
          : [],
      resultType: 'user_track',
      isExplicit: false,
      videoId: 'user_track_$id',
      description: description,
      artists: [MuzoArtist(name: 'My Uploads', id: null)],
      audioUrl: audioUrl,
    );
  }
}

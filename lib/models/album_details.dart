import 'package:muzo/models/muzo_item.dart';

class AlbumDetails {
  final String id;
  final String? playlistId;
  final String title;
  final String artist;
  final String year;
  final String thumbnail;
  final List<MuzoItem> tracks;
  final String type;

  AlbumDetails({
    required this.id,
    this.playlistId,
    required this.title,
    required this.artist,
    required this.year,
    required this.thumbnail,
    required this.tracks,
    required this.type,
  });

  factory AlbumDetails.fromJson(Map<String, dynamic> json) {
    String thumb = json['thumbnail']?.toString() ?? '';
    // Promote resolution if needed
    if (thumb.contains('=w544-h544')) {
      // It's already good, but let's just ensure we keep it valid
    } else if (thumb.contains('w120-h120')) {
      thumb = thumb.replaceAll('w120-h120', 'w544-h544');
    }

    final tracksList =
        (json['tracks'] as List?)?.map((t) {
          // Backfill thumbnail from album if missing
          final trackMap = Map<String, dynamic>.from(t);
          if (trackMap['thumbnail'] == null ||
              trackMap['thumbnail']?.toString().isEmpty == true) {
            trackMap['thumbnail'] = thumb;
          }

          // Map to MuzoItem structure
          return MuzoItem.fromJson(trackMap);
        }).toList() ??
        [];

    return AlbumDetails(
      id: json['id']?.toString() ?? '',
      playlistId: json['playlistId']?.toString(),
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
      thumbnail: thumb,
      tracks: tracksList,
      type: json['type']?.toString() ?? 'album',
    );
  }
}

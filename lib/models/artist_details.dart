import 'package:muzo/models/muzo_item.dart';

class ArtistDetails {
  final String artistName;
  final String artistAvatar;
  final String playlistId;
  final List<RecommendedArtist> recommendedArtists;
  final List<FeaturedPlaylist> featuredOnPlaylists;

  ArtistDetails({
    required this.artistName,
    required this.artistAvatar,
    required this.playlistId,
    required this.recommendedArtists,
    required this.featuredOnPlaylists,
  });

  factory ArtistDetails.fromJson(Map<String, dynamic> json) {
    return ArtistDetails(
      artistName: json['artistName']?.toString() ?? '',
      artistAvatar: json['artistAvatar']?.toString() ?? '',
      playlistId: json['playlistId']?.toString() ?? '',
      recommendedArtists:
          (json['recommendedArtists'] as List?)
              ?.map((e) => RecommendedArtist.fromJson(e))
              .toList() ??
          [],
      featuredOnPlaylists:
          (json['featuredOnPlaylists'] as List?)
              ?.map((e) => FeaturedPlaylist.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class RecommendedArtist {
  final String name;
  final String browseId;
  final String thumbnail;

  RecommendedArtist({
    required this.name,
    required this.browseId,
    required this.thumbnail,
  });

  factory RecommendedArtist.fromJson(Map<String, dynamic> json) {
    return RecommendedArtist(
      name: json['name']?.toString() ?? '',
      browseId: json['browseId']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
    );
  }
}

class FeaturedPlaylist {
  final String title;
  final String browseId;
  final String thumbnail;

  FeaturedPlaylist({
    required this.title,
    required this.browseId,
    required this.thumbnail,
  });

  factory FeaturedPlaylist.fromJson(Map<String, dynamic> json) {
    return FeaturedPlaylist(
      title: json['title']?.toString() ?? '',
      browseId: json['browseId']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
    );
  }
}

class PlaylistDetails {
  final String id;
  final String title;
  final String author;
  final String thumbnail;
  final List<MuzoItem> tracks;

  PlaylistDetails({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnail,
    required this.tracks,
  });

  factory PlaylistDetails.fromJson(Map<String, dynamic> json) {
    return PlaylistDetails(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      tracks:
          (json['tracks'] as List?)?.map((e) {
            final artistString = e['artist']?.toString() ?? '';
            final artists = artistString
                .split(', ')
                .map((name) => MuzoArtist(name: name))
                .toList();

            return MuzoItem(
              title: e['title']?.toString() ?? '',
              thumbnails: [
                MuzoThumbnail(
                  url: e['thumbnail']?.toString() ?? '',
                  width: 120,
                  height: 120,
                ),
              ],
              resultType: 'video',
              isExplicit: false,
              videoId: e['videoId']?.toString(),
              browseId: null,
              duration: e['duration']?.toString(),
              artists: artists,
              album: e['album'] != null && e['album'].toString().isNotEmpty
                  ? MuzoAlbum(name: e['album']?.toString() ?? '', id: '')
                  : null,
            );
          }).toList() ??
          [],
    );
  }
}

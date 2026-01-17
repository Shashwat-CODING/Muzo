import 'package:muzo/models/ytify_result.dart';

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
      artistName: json['artistName'] ?? '',
      artistAvatar: json['artistAvatar'] ?? '',
      playlistId: json['playlistId'] ?? '',
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
      name: json['name'] ?? '',
      browseId: json['browseId'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
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
      title: json['title'] ?? '',
      browseId: json['browseId'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
    );
  }
}

class PlaylistDetails {
  final String id;
  final String title;
  final String author;
  final String thumbnail;
  final List<YtifyResult> tracks;

  PlaylistDetails({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnail,
    required this.tracks,
  });

  factory PlaylistDetails.fromJson(Map<String, dynamic> json) {
    return PlaylistDetails(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      tracks:
          (json['tracks'] as List?)?.map((e) {
            // Map the track JSON to YtifyResult
            // The track JSON has 'videoId' which maps to 'videoId' in YtifyResult
            // 'artist' is a string in track JSON, but List<YtifyArtist> in YtifyResult.
            // We need to parse the artist string or just put it as one artist.

            final artistString = e['artist'] as String? ?? '';
            final artists = artistString
                .split(', ')
                .map((name) => YtifyArtist(name: name))
                .toList();

            return YtifyResult(
              title: e['title'] ?? '',
              thumbnails: [
                YtifyThumbnail(
                  url: e['thumbnail'] ?? '',
                  width: 120, // Default from example
                  height: 120,
                ),
              ],
              resultType: 'video', // Tracks are videos/songs
              isExplicit: false, // Not provided in track JSON
              videoId: e['videoId'],
              browseId: null,
              duration: e['duration'],
              artists: artists,
              album: e['album'] != null && e['album'].toString().isNotEmpty
                  ? YtifyAlbum(name: e['album'], id: '')
                  : null,
            );
          }).toList() ??
          [],
    );
  }
}

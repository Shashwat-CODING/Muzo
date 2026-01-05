import 'dart:convert';
import 'package:dio/dio.dart';

const String domain = "https://music.youtube.com/";
const String baseUrl = '${domain}youtubei/v1/';
const String fixedParams = '?prettyPrint=false&alt=json&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
const String userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36';

class YouTubeMusicHomeService {
  final Dio _dio = Dio();
  String? _visitorId;
  
  final Map<String, String> _headers = {
    'user-agent': userAgent,
    'accept': '*/*',
    'accept-encoding': 'gzip, deflate',
    'content-type': 'application/json',
    'content-encoding': 'gzip',
    'origin': domain,
    'cookie': 'CONSENT=YES+1',
  };

  Map<String, dynamic> _getContext() {
    final date = DateTime.now();
    final clientVersion = "1.${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}.01.00";
    final signatureTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 86400;
    
    return {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': clientVersion,
          'hl': 'en',
        },
        'user': {}
      },
      'playbackContext': {
        'contentPlaybackContext': {'signatureTimestamp': signatureTimestamp},
      },
    };
  }

  Future<void> initialize() async {
    final visitorId = await _generateVisitorId();
    _visitorId = visitorId;
    if (visitorId != null) {
      _headers['X-Goog-Visitor-Id'] = visitorId;
    }
  }

  Future<String?> _generateVisitorId() async {
    try {
      final response = await _dio.get(domain, options: Options(headers: _headers));
      final reg = RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;');
      final matches = reg.firstMatch(response.data.toString());
      
      if (matches != null) {
        final ytcfg = json.decode(matches.group(1).toString());
        return ytcfg['VISITOR_DATA']?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Response> _sendRequest(String action, Map<dynamic, dynamic> data) async {
    try {
      final response = await _dio.post(
        '$baseUrl$action$fixedParams',
        options: Options(headers: _headers),
        data: data,
      );
      
      if (response.statusCode == 200) {
        return response;
      }
      throw Exception('Request failed with status: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Network Error: ${e.message}');
    }
  }

  /// Fetch YouTube Music home page data
  Future<List<HomeSection>> getHome({int limit = 4}) async {
    final data = Map<String, dynamic>.from(_getContext());
    data['browseId'] = 'FEmusic_home';
    
    final response = await _sendRequest('browse', data);
    final results = _nav(response.data, [
      'contents',
      'singleColumnBrowseResultsRenderer',
      'tabs',
      0,
      'tabRenderer',
      'content',
      'sectionListRenderer',
      'contents'
    ]);
    
    if (results == null) return [];
    
    return _parseHomeSections(results);
  }

  List<HomeSection> _parseHomeSections(List<dynamic> sections) {
    final List<HomeSection> homeSections = [];
    
    for (var section in sections) {
      if (section.containsKey('musicCarouselShelfRenderer')) {
        final shelf = section['musicCarouselShelfRenderer'];
        final title = _nav(shelf, ['header', 'musicCarouselShelfBasicHeaderRenderer', 'title', 'runs', 0, 'text']);
        final contents = shelf['contents'] ?? [];
        
        final items = contents.map<HomeItem?>((item) {
          if (item.containsKey('musicTwoRowItemRenderer')) {
            return _parseMusicItem(item['musicTwoRowItemRenderer']);
          } else if (item.containsKey('musicResponsiveListItemRenderer')) {
            return _parseResponsiveItem(item['musicResponsiveListItemRenderer']);
          }
          return null;
        }).whereType<HomeItem>().toList();
        
        if (title != null && items.isNotEmpty) {
          homeSections.add(HomeSection(title: title, items: items));
        }
      }
    }
    
    return homeSections;
  }

  HomeItem? _parseMusicItem(Map<String, dynamic> data) {
    try {
      final title = _nav(data, ['title', 'runs', 0, 'text']);
      final subtitle = _nav(data, ['subtitle', 'runs', 0, 'text']);
      final thumbnails = _nav(data, ['thumbnailRenderer', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails']);
      final browseId = _nav(data, ['title', 'runs', 0, 'navigationEndpoint', 'browseEndpoint', 'browseId']);
      final videoId = _nav(data, ['navigationEndpoint', 'watchEndpoint', 'videoId']);
      final playlistId = _nav(data, ['navigationEndpoint', 'watchEndpoint', 'playlistId']) ??
                         _nav(data, ['navigationEndpoint', 'watchPlaylistEndpoint', 'playlistId']);
      
      String? type;
      if (browseId != null) {
        if (browseId.startsWith('MPRE')) type = 'album';
        else if (browseId.startsWith('UC')) type = 'artist';
        else if (browseId.startsWith('VL')) type = 'playlist';
      }
      
      return HomeItem(
        title: title ?? 'Unknown',
        subtitle: subtitle,
        thumbnails: thumbnails is List ? List<Map<String, dynamic>>.from(thumbnails) : [],
        browseId: browseId,
        videoId: videoId,
        playlistId: playlistId,
        type: type,
      );
    } catch (e) {
      return null;
    }
  }

  HomeItem? _parseResponsiveItem(Map<String, dynamic> data) {
    try {
      final title = _getFlexColumnText(data, 0);
      final subtitle = _getFlexColumnText(data, 1);
      final thumbnails = _nav(data, ['thumbnail', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails']);
      final videoId = _nav(data, ['flexColumns', 0, 'musicResponsiveListItemFlexColumnRenderer', 'text', 'runs', 0, 'navigationEndpoint', 'watchEndpoint', 'videoId']);
      final playlistId = _nav(data, ['flexColumns', 0, 'musicResponsiveListItemFlexColumnRenderer', 'text', 'runs', 0, 'navigationEndpoint', 'watchEndpoint', 'playlistId']) ??
                         _nav(data, ['flexColumns', 0, 'musicResponsiveListItemFlexColumnRenderer', 'text', 'runs', 0, 'navigationEndpoint', 'watchPlaylistEndpoint', 'playlistId']);
      
      String type = 'song';
      if (videoId == null && playlistId != null) {
        type = 'playlist';
      }

      return HomeItem(
        title: title ?? 'Unknown',
        subtitle: subtitle,
        thumbnails: thumbnails is List ? List<Map<String, dynamic>>.from(thumbnails) : [],
        videoId: videoId,
        playlistId: playlistId,
        type: type,
      );
    } catch (e) {
      return null;
    }
  }

  String? _getFlexColumnText(Map<String, dynamic> data, int index) {
    try {
      final flexColumns = data['flexColumns'];
      if (flexColumns == null || flexColumns.length <= index) return null;
      
      return _nav(flexColumns[index], [
        'musicResponsiveListItemFlexColumnRenderer',
        'text',
        'runs',
        0,
        'text'
      ]);
    } catch (e) {
      return null;
    }
  }

  dynamic _nav(dynamic root, List items) {
    try {
      dynamic result = root;
      for (final item in items) {
        if (result == null) return null;
        result = result[item];
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _dio.close();
  }
}

// Models
class HomeSection {
  final String title;
  final List<HomeItem> items;

  HomeSection({required this.title, required this.items});

  Map<String, dynamic> toJson() => {
    'title': title,
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    return HomeSection(
      title: json['title'] ?? '',
      items: (json['items'] as List?)
              ?.map((item) => HomeItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class HomeItem {
  final String title;
  final String? subtitle;
  final List<Map<String, dynamic>> thumbnails;
  final String? browseId;
  final String? videoId;
  final String? playlistId;
  final String? type;

  HomeItem({
    required this.title,
    this.subtitle,
    required this.thumbnails,
    this.browseId,
    this.videoId,
    this.playlistId,
    this.type,
  });

  String? get thumbnailUrl {
    if (thumbnails.isEmpty) return null;
    String url = thumbnails.last['url'];
    // High-res replacement logic similar to player
    if (url.contains('w120-h120')) {
      return url.replaceAll('w120-h120', 'w544-h544');
    }
    return url;
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'thumbnails': thumbnails,
    'browseId': browseId,
    'videoId': videoId,
    'playlistId': playlistId,
    'type': type,
    'thumbnailUrl': thumbnailUrl, // Not used in fromJson, strictly derived
  };

  factory HomeItem.fromJson(Map<String, dynamic> json) {
    return HomeItem(
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      thumbnails: (json['thumbnails'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      browseId: json['browseId'],
      videoId: json['videoId'],
      playlistId: json['playlistId'],
      type: json['type'],
    );
  }
}

// Usage Example:
// 
// final service = YouTubeMusicHomeService();
// await service.initialize();
// final homeSections = await service.getHome(limit: 10);
// 
// for (var section in homeSections) {
//   print('Section: ${section.title}');
//   for (var item in section.items) {
//     print('  - ${item.title} (${item.type})');
//   }
// }
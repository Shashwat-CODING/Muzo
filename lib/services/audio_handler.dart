import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/stream_extraction_service.dart';

class AudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final StorageService _storage;
  late final MuzoApiService _apiService = MuzoApiService(_storage);
  late final MuzoApiService _musicApiService = _apiService;

  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    children: [],
  );

  String? _lastHistoryId;
  bool _isInitialLoading = false;

  final ValueNotifier<bool> isLoadingStream = ValueNotifier(false);

  AudioPlayer get player => _player;
  ConcatenatingAudioSource get playlist => _playlist;

  final ValueNotifier<bool> isLofiModeNotifier = ValueNotifier(false);

  static const platform = MethodChannel('com.shashwat.muzo/audio_effects');

  double _userVolume = 1.0;
  
  // Stream subscriptions for proper cleanup
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<int?>? _androidAudioSessionIdSubscription;
  StreamSubscription<SequenceState?>? _sequenceStateSubscription;
  StreamSubscription<int?>? _currentIndexSubscription;
  
  double get userVolume => _userVolume;

  Future<void> setVolume(double volume) async {
    _userVolume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_userVolume);
  }

  AudioHandler(this._storage) {
    _init();
  }

  Future<void> toggleLofiMode() async {
    isLofiModeNotifier.value = !isLofiModeNotifier.value;
    await updateLofiSettings();
  }

  Future<void> updateLofiSettings() async {
    final enable = isLofiModeNotifier.value;

    if (enable) {
      await _player.setSpeed(_storage.lofiSpeed);
      await _player.setPitch(_storage.lofiPitch);
    } else {
      await _player.setSpeed(1.0);
      await _player.setPitch(1.0);
    }

    if (Platform.isAndroid) {
      final sessionId = _player.androidAudioSessionId;
      if (sessionId != null) {
        await _applyReverb(sessionId, enable);
      }
    }
  }

  Future<void> _init() async {
    // Configure audio session for optimal music playback quality
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
    } catch (e) {
      debugPrint("Error configuring AudioSession: $e");
    }

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering) {
        isLoadingStream.value = true;
      } else if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle) {
        isLoadingStream.value = false;
      }

      if (state.playing && state.processingState == ProcessingState.ready) {
        final index = _player.currentIndex;
        final sequence = _player.sequenceState?.sequence;
        if (index != null && sequence != null && index < sequence.length) {
          final source = sequence[index];
          final tag = source.tag;
          if (tag is MediaItem && tag.id != _lastHistoryId) {
            _lastHistoryId = tag.id;
            final result = MuzoItem(
              videoId: tag.id,
              title: tag.title,
              artists: [MuzoArtist(name: tag.artist ?? '', id: '')],
              thumbnails: [
                MuzoThumbnail(
                  url: tag.artUri?.toString() ?? '',
                  width: 0,
                  height: 0,
                ),
              ],
              resultType: tag.extras?['resultType'] ?? 'song',
              durationSeconds: tag.duration?.inSeconds,
              isExplicit: false,
              audioUrl: tag.extras?['audioUrl'],
            );
            _storage.addToHistory(result);
          } else if (tag is MuzoItem && tag.videoId != _lastHistoryId) {
            _lastHistoryId = tag.videoId;
            _storage.addToHistory(tag);
          }
        }

        if (_isInitialLoading) {
          _isInitialLoading = false;
        }

        if (sequence != null && index != null) {
          if (sequence.isEmpty || (index >= sequence.length - 1)) {
            if (_storage.isAutoQueueEnabled) {
              _handleAutoQueue();
            }
          } else {
            for (int i = 1; i <= 3; i++) {
              if (index + i < sequence.length) {
                final source = sequence[index + i];
                if (source is ResolvingAudioSource) {
                  source.resolve();
                }
              }
            }
          }
        }
      }
    });

    _androidAudioSessionIdSubscription = _player.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId != null && isLofiModeNotifier.value) {
        _applyReverb(sessionId, true);
      }
    });

    _sequenceStateSubscription = _player.sequenceStateStream.listen((state) {
      if (state == null) return;
      if (_isInitialLoading) return;
      final sequence = state.sequence;
      final index = state.currentIndex;

      for (int i = 1; i <= 3; i++) {
        if (index + i < sequence.length) {
          final source = sequence[index + i];
          if (source is ResolvingAudioSource) {
            source.resolve();
          }
        }
      }

      if (sequence.isEmpty || (index >= sequence.length - 1)) {
        if (_storage.isAutoQueueEnabled) {
          _handleAutoQueue();
        }
      }
    });

    _currentIndexSubscription = _player.currentIndexStream.listen((index) async {
      if (index == null) return;
      final sequence = _player.sequenceState?.sequence;
      if (sequence == null || index >= sequence.length) return;

      for (int i = 0; i <= 3; i++) {
        if (index + i < sequence.length) {
          final source = sequence[index + i];
          if (source is ResolvingAudioSource) {
            source.resolve();
          }
        }
      }
    });
  }

  Future<void> _applyReverb(int sessionId, bool enable) async {
    if (!Platform.isAndroid) return;
    try {
      await platform.invokeMethod('enableReverb', {
        'sessionId': sessionId,
        'enable': enable,
      });
    } catch (e) {
      debugPrint("Error toggling reverb: $e");
    }
  }

  Future<void> playVideo(dynamic video) async {
    try {
      _isInitialLoading = true;
      isLoadingStream.value = true;

      String? videoId = video is MuzoItem ? video.videoId : null;
      if (videoId == null) {
        debugPrint('playVideo: missing videoId');
        final context = navigatorKey.currentContext;
        if (context != null) {
          showGlassSnackBar(context, 'Cannot play this item: Missing ID');
        }
        _isInitialLoading = false;
        isLoadingStream.value = false;
        return;
      }

      // Extract stream URL — UI already shows loading state
      final source = await _createAudioSource(video);
      if (source == null) {
        isLoadingStream.value = false;
        _isInitialLoading = false;
        final context = navigatorKey.currentContext;
        if (context != null) {
          showGlassSnackBar(context, 'Failed to extract audio stream');
        }
        return;
      }

      // As soon as source is ready — set and play immediately
      await _playlist.clear();
      await _playlist.add(source);

      // setAudioSource with preload:true starts buffering immediately
      await _player.setAudioSource(
        _playlist,
        initialPosition: Duration.zero,
        initialIndex: 0,
        preload: true,
      );

      // Fire play without awaiting — playback starts instantly
      // while the rest of the app continues (queue loading etc.)
      unawaited(_player.play());

      isLoadingStream.value = false;
    } catch (e) {
      debugPrint('Error playing video: $e');
      isLoadingStream.value = false;
      _isInitialLoading = false;
      final context = navigatorKey.currentContext;
      if (context != null) {
        showGlassSnackBar(context, 'Playback failed: $e');
      }
    }
  }

  Future<void> addToQueue(dynamic video) async {
    try {
      final source = await _createAudioSource(video);
      if (source != null) {
        await _playlist.add(source);
        if (_player.audioSource != _playlist) {
          await _player.setAudioSource(_playlist);
        }
      } else {
        final context = navigatorKey.currentContext;
        if (context != null) {
          showGlassSnackBar(context, 'Failed to add to queue');
        }
      }
    } catch (e) {
      debugPrint('Error adding to queue: $e');
    }
  }

  Future<AudioSource?> _createAudioSource(dynamic video) async {
    try {
      String videoId;
      String title;
      String artist;
      String artUri;
      String resultType = 'video';
      String? artistId;
      Duration? duration;

      if (video is MuzoItem) {
        if (video.videoId == null) return null;
        videoId = video.videoId!;
        title = video.title;
        artist = video.displayArtist;
        artistId = video.artists?.firstOrNull?.id;
        artUri = video.thumbnails.isNotEmpty ? video.thumbnails.last.url : '';
        resultType = video.resultType;
        if (video.durationSeconds != null) {
          duration = Duration(seconds: video.durationSeconds!);
        }
      } else {
        return null;
      }

      final downloadPath = _storage.getDownloadPath(videoId);
      Uri audioUri;

      if (video.resultType == 'user_track') {
        if (video.audioUrl == null) {
          debugPrint('AudioHandler: user track missing audioUrl');
          return null;
        }
        audioUri = Uri.parse(video.audioUrl!);
      } else if (downloadPath != null && await File(downloadPath).exists()) {
        audioUri = Uri.file(downloadPath);
      } else {
        final streamUrl = await StreamExtractionService.getStreamUrl(
          videoId,
          title: title,
          artist: artist,
          durationSeconds: duration?.inSeconds,
        );
        if (streamUrl == null) {
          debugPrint('AudioHandler: getStreamUrl returned null for $videoId');
          return null;
        }
        audioUri = Uri.parse(streamUrl);
      }

      return AudioSource.uri(
        audioUri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Mobile Safari/537.36',
        },
        tag: MediaItem(
          id: videoId,
          album: "Muzo",
          title: title,
          artist: artist,
          duration: duration,
          artUri: Uri.parse(artUri),
          extras: {
            'resultType': resultType,
            'artistId': artistId,
            'isSaavn': StreamExtractionService.isSaavnCache[videoId],
            'audioUrl': video.audioUrl,
          },
        ),
      );
    } catch (e) {
      debugPrint('Error creating audio source: $e');
      return null;
    }
  }

  Future<void> playAll(List<MuzoItem> results) async {
    try {
      _isInitialLoading = true;
      if (results.isEmpty) {
        _isInitialLoading = false;
        return;
      }

      await _playlist.clear();

      // Resolve and play the first song immediately
      await addToQueue(results.first);

      if (_playlist.length > 0) {
        await _player.setAudioSource(
          _playlist,
          initialPosition: Duration.zero,
          initialIndex: 0,
          preload: true,
        );
        unawaited(_player.play());
      }

      // Add the rest lazily — resolved on demand
      if (results.length > 1) {
        final remainingSources = results
            .skip(1)
            .map((song) => _createLazyAudioSource(song))
            .whereType<AudioSource>()
            .toList();
        if (remainingSources.isNotEmpty) {
          await _playlist.addAll(remainingSources);
        }
      }
    } catch (e) {
      debugPrint('Error playing all: $e');
      _isInitialLoading = false;
    }
  }

  AudioSource? _createLazyAudioSource(MuzoItem result) {
    if (result.videoId == null) return null;
    final videoId = result.videoId!;
    final title = result.title;
    final artist = result.displayArtist;
    final artUri =
        result.thumbnails.isNotEmpty ? result.thumbnails.last.url : '';
    final duration = result.durationSeconds != null
        ? Duration(seconds: result.durationSeconds!)
        : null;

    final mediaItem = MediaItem(
      id: videoId,
      album: 'Muzo',
      title: title,
      artist: artist,
      duration: duration,
      artUri: Uri.parse(artUri),
      extras: {
        'resultType': result.resultType,
        'lazy': true,
        'audioUrl': result.audioUrl,
      },
    );

    return ResolvingAudioSource(
      videoId: videoId,
      storage: _storage,
      tag: mediaItem,
    );
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> seek(Duration position, {int? index}) =>
      _player.seek(position, index: index);

  Future<void> skipToNext() async {
    await _player.seekToNext();
    unawaited(_player.play());
  }

  Future<void> skipToPrevious() async {
    await _player.seekToPrevious();
    unawaited(_player.play());
  }

  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks
    _playerStateSubscription?.cancel();
    _androidAudioSessionIdSubscription?.cancel();
    _sequenceStateSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    
    // Dispose notifiers
    isLoadingStream.dispose();
    isLofiModeNotifier.dispose();
    
    // Dispose player last
    _player.dispose();
  }

  Future<void> removeQueueItem(int index) async {
    try {
      await _playlist.removeAt(index);
    } catch (e) {
      debugPrint('Error removing queue item: $e');
    }
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    try {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      await _playlist.move(oldIndex, newIndex);
    } catch (e) {
      debugPrint('Error reordering queue: $e');
    }
  }

  Future<void> clearQueue() async {
    try {
      final currentIndex = _player.currentIndex;
      if (currentIndex != null && _playlist.length > 1) {
        if (currentIndex < _playlist.length - 1) {
          await _playlist.removeRange(currentIndex + 1, _playlist.length);
        }
        if (currentIndex > 0) {
          await _playlist.removeRange(0, currentIndex);
        }
      } else {
        await _playlist.clear();
      }
    } catch (e) {
      debugPrint('Error clearing queue: $e');
    }
  }

  Future<void> playNext(MuzoItem result) async {
    try {
      final index = _player.currentIndex;
      if (index == null) {
        await addToQueue(result);
        return;
      }

      if (result.videoId == null) return;
      final videoId = result.videoId!;
      final title = result.title;
      final artist = result.displayArtist;
      final artistId = result.artists?.firstOrNull?.id;
      final artUri =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : '';
      final resultType = result.resultType;
      Duration? duration;
      if (result.durationSeconds != null) {
        duration = Duration(seconds: result.durationSeconds!);
      }

      final downloadPath = _storage.getDownloadPath(videoId);
      Uri audioUri;

      if (downloadPath != null && await File(downloadPath).exists()) {
        audioUri = Uri.file(downloadPath);
      } else {
        final streamUrl = await StreamExtractionService.getStreamUrl(
          videoId,
          title: title,
          artist: artist,
          durationSeconds: duration?.inSeconds,
        );
        if (streamUrl == null) return;
        audioUri = Uri.parse(streamUrl);
      }

      final audioSource = AudioSource.uri(
        audioUri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Mobile Safari/537.36',
        },
        tag: MediaItem(
          id: videoId,
          album: "Muzo",
          title: title,
          artist: artist,
          duration: duration,
          artUri: Uri.parse(artUri),
          extras: {
            'resultType': resultType,
            'artistId': artistId,
            'isSaavn': StreamExtractionService.isSaavnCache[videoId],
          },
        ),
      );

      await _playlist.insert(index + 1, audioSource);

      final context = navigatorKey.currentContext;
      if (context != null) {
        showGlassSnackBar(context, 'Song added to play next');
      }
    } catch (e) {
      debugPrint('Error playing next: $e');
    }
  }

  bool _isFetchingAutoQueue = false;

  Future<void> _handleAutoQueue() async {
    if (_isFetchingAutoQueue) return;

    final currentSource = _player.sequenceState?.currentSource;
    final tag = currentSource?.tag;
    if (tag is! MediaItem) {
      debugPrint('AutoQueue: Current item tag is not MediaItem');
      return;
    }

    final videoId = tag.id;
    debugPrint('AutoQueue: Fetching suggestions for $videoId');

    _isFetchingAutoQueue = true;
    try {
      final nextSongs = await _musicApiService.getUpNext(videoId);
      debugPrint('AutoQueue: fetched ${nextSongs.length} songs');

      final currentTag = _player.sequenceState?.currentSource?.tag;
      if (currentTag is! MediaItem || currentTag.id != videoId) {
        debugPrint('AutoQueue: Song changed, discarding results for $videoId');
        return;
      }

      if (nextSongs.isNotEmpty) {
        final filteredSongs = nextSongs
            .skip(1)
            .where((s) => s.videoId != videoId)
            .toList();
        if (filteredSongs.isEmpty) return;

        final sources = filteredSongs
            .map((song) => _createLazyAudioSource(song))
            .whereType<AudioSource>()
            .toList();
        if (sources.isNotEmpty) {
          await _playlist.addAll(sources);
        }
        debugPrint('AutoQueue: Added ${filteredSongs.length} songs lazily');
      }
    } catch (e) {
      debugPrint('Error in auto queue: $e');
    } finally {
      _isFetchingAutoQueue = false;
    }
  }
}

class ResolvingAudioSource extends StreamAudioSource {
  final String videoId;
  final StorageService storage;
  String? _resolvedUrl;
  Future<void>? _resolveFuture;

  ResolvingAudioSource({
    required this.videoId,
    required this.storage,
    super.tag,
  });

  Future<void> resolve() async {
    if (_resolvedUrl != null) return;
    if (_resolveFuture != null) {
      await _resolveFuture;
      return;
    }

    final mediaItem = tag as MediaItem?;
    if (mediaItem?.extras?['resultType'] == 'user_track') {
      _resolvedUrl = mediaItem?.extras?['audioUrl'];
      return;
    }

    final title = mediaItem?.title;
    final artist = mediaItem?.artist;
    final durationSeconds = mediaItem?.duration?.inSeconds;

    final future = StreamExtractionService.getStreamUrl(
      videoId,
      title: title,
      artist: artist,
      durationSeconds: durationSeconds,
    ).then((url) {
      _resolvedUrl = url;
    }).catchError((e) {
      debugPrint('Error pre-resolving track $videoId: $e');
    }).whenComplete(() {
      _resolveFuture = null;
    });

    _resolveFuture = future;
    await future;
  }

  Future<HttpClientResponse> _makeRequest(int? start, int? end) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(_resolvedUrl!));
    request.headers.add(
      'User-Agent',
      'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Mobile Safari/537.36',
    );

    if (start != null || end != null) {
      final rangeHeader =
          'bytes=${start ?? 0}-${end != null ? (end - 1) : ""}';
      request.headers.add('Range', rangeHeader);
    }

    return await request.close();
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final downloadPath = storage.getDownloadPath(videoId);
    if (downloadPath != null && await File(downloadPath).exists()) {
      final file = File(downloadPath);
      final length = await file.length();
      final s = start ?? 0;
      final e = end ?? length;
      return StreamAudioResponse(
        sourceLength: length,
        contentLength: e - s,
        offset: s,
        contentType: 'audio/mpeg',
        stream: file.openRead(s, e),
      );
    }

    if (_resolvedUrl == null) {
      await resolve();
      if (_resolvedUrl == null) {
        throw Exception('Failed to resolve stream URL for $videoId');
      }
    }

    HttpClientResponse response;
    try {
      response = await _makeRequest(start, end);
      if (response.statusCode == 403) {
        debugPrint(
            'ResolvingAudioSource: 403 Forbidden. Retrying with fresh URL...');
        _resolvedUrl = null;
        await resolve();
        if (_resolvedUrl == null) {
          throw Exception('Failed to re-resolve stream URL for $videoId');
        }
        response = await _makeRequest(start, end);
      }
    } catch (e) {
      debugPrint('ResolvingAudioSource request error: $e');
      rethrow;
    }

    if (response.statusCode >= 400) {
      throw Exception('Server returned status code ${response.statusCode}');
    }

    final contentLength = response.contentLength;
    int sourceLength = contentLength;
    final contentRange = response.headers.value('content-range');
    if (contentRange != null) {
      final parts = contentRange.split('/');
      if (parts.length == 2) {
        sourceLength = int.tryParse(parts[1]) ?? contentLength;
      }
    } else if (response.statusCode == 200 && start == null) {
      sourceLength = contentLength;
    }

    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: contentLength,
      offset: start ?? 0,
      contentType:
          response.headers.contentType?.toString() ?? 'audio/mpeg',
      stream: response,
    );
  }
}
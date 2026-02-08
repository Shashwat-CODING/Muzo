import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:muzo/services/youtube_api_service.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/music_api_service.dart';

class AudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final YouTubeApiService _apiService = YouTubeApiService();
  late final MusicApiService _musicApiService;
  final StorageService _storage;

  // Playlist for queue management
  ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    children: [],
  );

  // Loading state
  final ValueNotifier<bool> isLoadingStream = ValueNotifier(false);

  AudioPlayer get player => _player;
  ConcatenatingAudioSource get playlist => _playlist;

  // Lofi Mode
  final ValueNotifier<bool> isLofiModeNotifier = ValueNotifier(false);

  // Platform channel for audio effects
  static const platform = MethodChannel('com.shashwat.muzo/audio_effects');

  AudioHandler(this._storage) {
    _musicApiService = MusicApiService(_storage);
    _init();
  }

  Future<void> toggleLofiMode() async {
    isLofiModeNotifier.value = !isLofiModeNotifier.value;
    final enable = isLofiModeNotifier.value;

    // Apply speed/pitch
    if (enable) {
      final speed = _storage.lofiSpeed;
      final pitch = _storage.lofiPitch;
      await _player.setSpeed(speed);
      await _player.setPitch(pitch);
    } else {
      await _player.setSpeed(1.0);
      await _player.setPitch(1.0);
    }

    // Apply native reverb
    if (Platform.isAndroid) {
      final sessionId = _player.androidAudioSessionId;
      if (sessionId != null) {
        await _applyReverb(sessionId, enable);
      }
    }
  }

  Future<void> _init() async {
    // Listen to player state to manage loading indicator
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.ready ||
          state == ProcessingState.completed) {
        isLoadingStream.value = false;
      }
    });

    // Listen to session ID changes to re-apply reverb
    _player.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId != null && isLofiModeNotifier.value) {
        _applyReverb(sessionId, true);
      }
    });

    _player.sequenceStateStream.listen((state) {
      if (state == null) return;
      final sequence = state.sequence;
      final index = state.currentIndex;

      if (sequence.isEmpty || index >= sequence.length - 1) {
        if (_storage.isAutoQueueEnabled) {
          _handleAutoQueue();
        }
      }
    });

    // JIT: Listen for index changes to resolve upcoming lazy sources
    _player.currentIndexStream.listen((index) {
      if (index != null) {
        _ensureUpcomingResolved(index);
      }
    });

    // Listen to settings changes for real-time Lofi updates
    _storage.settingsListenable.addListener(() {
      if (isLofiModeNotifier.value) {
        _player.setSpeed(_storage.lofiSpeed);
        _player.setPitch(_storage.lofiPitch);
      }
    });
  }

  /// Reverb intensity (0.0 = off, 1.0 = maximum)
  static const double _reverbIntensity = 0.4; // 40% reverb

  Future<void> _applyReverb(int sessionId, bool enable) async {
    if (!Platform.isAndroid) return;
    try {
      await platform.invokeMethod('enableReverb', {
        'sessionId': sessionId,
        'enable': enable,
        'intensity': _reverbIntensity,
      });
    } catch (e) {
      debugPrint("Error toggling reverb: $e");
    }
  }

  Future<void> playVideo(dynamic video) async {
    try {
      isLoadingStream.value = true;

      // Clear queue and play single video
      // Stop and disable shuffle to prevent RangeError during switch
      await _player.stop();
      try {
        await _player.setShuffleModeEnabled(false);
      } catch (e) {
        debugPrint('Error disabling shuffle: $e');
      }

      // Reallocate playlist to avoid race conditions with old list indices
      _playlist = ConcatenatingAudioSource(children: []);

      // Create source (this enriches metadata)
      final source = await _createAudioSource(video);
      if (source != null) {
        // Save original data to history (not enriched)
        if (video is YtifyResult) {
          _storage.addToHistory(video);
        }

        await _playlist.add(source);
        // Always set the new audio source
        await _player.setAudioSource(_playlist);
        await _player.play();
      } else {
        debugPrint('Error: Could not create audio source');
        isLoadingStream.value = false;
      }
    } catch (e) {
      debugPrint('Error playing video: $e');
      isLoadingStream.value = false; // Hide spinner on error
    }
  }

  /// Saves to history using enriched metadata from the AudioSource's MediaItem tag.
  void _saveToHistoryFromSource(AudioSource source) {
    try {
      final tag = (source as dynamic).tag;
      if (tag is MediaItem) {
        final result = YtifyResult(
          title: tag.title,
          thumbnails: [
            YtifyThumbnail(
              url: tag.artUri?.toString() ?? '',
              width: 0,
              height: 0,
            ),
          ],
          resultType: tag.extras?['resultType'] ?? 'song',
          isExplicit: false,
          videoId: tag.id,
          duration: tag.duration != null
              ? _formatDuration(tag.duration!)
              : null,
          durationSeconds: tag.duration?.inSeconds,
          artists: tag.artist != null
              ? [YtifyArtist(name: tag.artist!, id: tag.extras?['artistId'])]
              : null,
        );
        _storage.addToHistory(result);
      }
    } catch (e) {
      debugPrint('Error saving to history from source: $e');
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> addToQueue(dynamic video) async {
    try {
      final source = await _createAudioSource(video, lazy: true);
      if (source != null) {
        await _playlist.add(source);

        // If player is not set to this playlist (e.g. first item), set it
        if (_player.audioSource != _playlist) {
          await _player.setAudioSource(_playlist);
        }
      }
    } catch (e) {
      debugPrint('Error adding to queue: $e');
    }
  }

  Future<AudioSource?> _createAudioSource(dynamic video, {bool lazy = false}) async {
    try {
      String videoId;
      String title;
      String artist;
      String artUri;
      String resultType = 'video';
      String? artistId;
      Duration? duration;

      if (video is YtifyResult) {
        if (video.videoId == null) return null;
        videoId = video.videoId!;
        title = video.title;
        artist = video.artists?.map((a) => a.name).join(', ') ?? video.videoType ?? 'Unknown';
        artistId = video.artists?.firstOrNull?.id;
        artUri = video.thumbnails.isNotEmpty ? video.thumbnails.last.url : '';
        resultType = video.resultType;
        if (video.durationSeconds != null) {
          duration = Duration(seconds: video.durationSeconds!);
        }
      } else {
        return null;
      }

      final Map<String, dynamic> extras = {
        'resultType': resultType,
        'artistId': artistId,
      };

      Uri audioUri;
      
      // Lazy Loading: Return dummy URI immediately if not downloaded
      final downloadPath = _storage.getDownloadPath(videoId);
      final isDownloaded = downloadPath != null && await File(downloadPath).exists();

      if (lazy && !isDownloaded) {
        audioUri = Uri.parse('lazy://$videoId');
      } else if (isDownloaded) {
        audioUri = Uri.file(downloadPath!);
      } else {
        // Fetch stream (Expensive)
        final streamUrl = await _apiService.getStreamUrl(
          videoId,
          title: title,
          artist: artist,
          onFallback: () => _showFallbackAlert(),
        );

        if (streamUrl == null) return null;
        audioUri = Uri.parse(streamUrl);
        // Log in chunks
        final pattern = RegExp('.{1,8000}');
        pattern.allMatches('Playing stream: $streamUrl').forEach((match) => debugPrint(match.group(0)));
      }

      return AudioSource.uri(
        audioUri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        tag: MediaItem(
          id: videoId,
          album: "Muzo",
          title: title,
          artist: artist,
          duration: duration,
          artUri: Uri.parse(artUri),
          extras: extras,
        ),
      );
    } catch (e) {
      debugPrint('Error creating audio source: $e');
      return null;
    }
  }

  Future<void> setAudioLanguage(String url, String languageName) async {
    try {
      final currentSource = _player.sequenceState?.currentSource;
      final currentPos = _player.position;
      final playing = _player.playing;

      if (currentSource == null) return;

      final oldTag = currentSource.tag as MediaItem;
      final newExtras = Map<String, dynamic>.from(oldTag.extras ?? {});
      newExtras['currentLanguage'] = languageName;

      final newSource = AudioSource.uri(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Mobile Safari/537.36',
        },
        tag: oldTag.copyWith(extras: newExtras),
      );

      final index = _player.currentIndex;
      if (index != null && index < _playlist.length) {
        if (_playlist.length == 1) {
          await _player.setAudioSource(newSource, initialPosition: currentPos);
          if (playing) {
            _player.play();
          }
          return;
        }
        await _player.pause();
        await _playlist.insert(index, newSource);
        await _player.seek(currentPos, index: index);
        await _playlist.removeAt(index + 1);
        if (playing) {
          _player.play();
        }
      }
    } catch (e) {
      debugPrint("Error changing language: $e");
    }
  }

  Future<void> playAll(List<YtifyResult> results) async {
    try {
      if (results.isEmpty) return;
      await _player.stop();
      try {
        await _player.setShuffleModeEnabled(false);
      } catch (e) {
        debugPrint('Error disabling shuffle: $e');
      }
      _playlist = ConcatenatingAudioSource(children: []);
      final firstSource = await _createAudioSource(results.first);
      if (firstSource != null) {
        _storage.addToHistory(results.first);
        await _playlist.add(firstSource);
        await _player.setAudioSource(_playlist);
        _player.play();
      }
      if (results.length > 1) {
        _queueRestOfPlaylist(results, 0);
      }
    } catch (e) {
      debugPrint('Error playing all: $e');
    }
  }

  Future<void> playPlaylist(List<YtifyResult> results, int initialIndex) async {
    try {
      if (results.isEmpty) return;
      if (initialIndex < 0 || initialIndex >= results.length) initialIndex = 0;
      await _player.stop();
      try {
        await _player.setShuffleModeEnabled(false);
      } catch (e) {
        debugPrint('Error disabling shuffle: $e');
      }
      _playlist = ConcatenatingAudioSource(children: []);
      final initialSong = results[initialIndex];
      final initialSource = await _createAudioSource(initialSong);
      if (initialSource != null) {
        _storage.addToHistory(initialSong);
        await _playlist.add(initialSource);
        await _player.setAudioSource(_playlist);
        _player.play();
      }
      _queueRestOfPlaylist(results, initialIndex);
    } catch (e) {
      debugPrint('Error playing playlist: $e');
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> seek(Duration position, {int? index}) => _player.seek(position, index: index);
  Future<void> skipToNext() => _player.seekToNext();
  Future<void> skipToPrevious() => _player.seekToPrevious();
  void dispose() { _player.dispose(); }

  Future<void> playNext(YtifyResult result) async {
    try {
      final index = _player.currentIndex;
      if (index == null) {
        await addToQueue(result);
        return;
      }
      
      // Use lazy loading for play next too? No, usually user wants it ready.
      // But for consistency we can use defaults.
      final source = await _createAudioSource(result, lazy: true);
      if (source != null) {
         await _playlist.insert(index + 1, source);
         final context = navigatorKey.currentContext;
         if (context != null) {
           showGlassSnackBar(context, 'Song added to play next');
         }
      }
    } catch (e) {
      debugPrint('Error playing next: $e');
    }
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
      if (oldIndex < newIndex) newIndex -= 1;
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
        await _player.stop();
        await _playlist.clear();
        try {
          await _player.setShuffleModeEnabled(false);
        } catch (e) {
          debugPrint('Error disabling shuffle: $e');
        }
      }
    } catch (e) {
      debugPrint('Error clearing queue: $e');
    }
  }

  void _showFallbackAlert() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showGlassSnackBar(context, 'Using fallback playback API');
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
        debugPrint('AutoQueue: Current song changed, discarding results');
        return;
      }

      if (nextSongs.isNotEmpty) {
        final filteredSongs = nextSongs.where((s) => s.videoId != videoId).toList();
        if (filteredSongs.isEmpty) return;

        // Lazy Loading Strategy
        final futures = <Future<AudioSource?>>[];
        
        // 1. Resolve first song immediately
        futures.add(_createAudioSource(filteredSongs.first, lazy: false));
        
        // 2. Add rest as lazy
        if (filteredSongs.length > 1) {
          for (int i = 1; i < filteredSongs.length; i++) {
             futures.add(_createAudioSource(filteredSongs[i], lazy: true));
          }
        }

        final sources = await Future.wait(futures);
        final validSources = sources.whereType<AudioSource>().toList();

        if (validSources.isNotEmpty) {
          await _playlist.addAll(validSources);
        }
      }
    } catch (e) {
      debugPrint('Error in auto queue: $e');
    } finally {
      _isFetchingAutoQueue = false;
    }
  }

  // JIT Resolution Logic
  bool _isResolving = false;

  Future<void> _ensureUpcomingResolved(int currentIndex) async {
    if (_isResolving) return;
    _isResolving = true;
    try {
      // Buffer horizon: Check next 2-3 songs
      for (int i = 1; i <= 3; i++) {
        final targetIndex = currentIndex + i;
        if (targetIndex >= _playlist.length) break;

        final source = _playlist.children[targetIndex];
        if (source is UriAudioSource && source.uri.scheme == 'lazy') {
          // Found lazy source, resolve it
          final tag = source.tag as MediaItem;
          // Reconstruct YtifyResult from MediaItem to reuse existing create logic
          final result = YtifyResult(
            videoId: tag.id,
            title: tag.title,
            artists: [YtifyArtist(name: tag.artist ?? '', id: tag.extras?['artistId'])],
            thumbnails: [YtifyThumbnail(url: tag.artUri.toString(), width: 0, height: 0)],
            durationSeconds: tag.duration?.inSeconds,
            resultType: tag.extras?['resultType'] ?? 'video',
            isExplicit: false,
          );

          debugPrint("JIT Resolving: ${tag.title}");
          final newSource = await _createAudioSource(result, lazy: false);
          
          if (newSource != null) {
            // Replace in playlist
            // Note: removeAt then insert keeps order
            await _playlist.removeAt(targetIndex);
            await _playlist.insert(targetIndex, newSource);
            debugPrint("JIT Resolved & Replaced: ${tag.title}");
          }
        }
      }
    } catch (e) {
      debugPrint("Error in JIT resolution: $e");
    } finally {
      _isResolving = false;
    }
  }

  Future<void> _queueRestOfPlaylist(List<YtifyResult> results, int initialIndex) async {
    try {
      // Add songs AFTER initial index (Lazy)
      if (initialIndex < results.length - 1) {
        final futures = <Future<AudioSource?>>[];
        for (int i = initialIndex + 1; i < results.length; i++) {
          futures.add(_createAudioSource(results[i], lazy: true));
        }
        // Create all lazy sources in parallel (super fast)
        final sources = await Future.wait(futures);
        final validSources = sources.whereType<AudioSource>().toList();
        if (validSources.isNotEmpty) {
          await _playlist.addAll(validSources);
        }
      }

      // Add songs BEFORE initial index (Lazy)
      // Note: We insert at 0, so iterate in reverse to keep order? 
      // Original logic: i from initial-1 down to 0, insert at 0. = Reverse order of insertion = Correct order in list.
      if (initialIndex > 0) {
        for (int i = initialIndex - 1; i >= 0; i--) {
          final source = await _createAudioSource(results[i], lazy: true);
          if (source != null) {
             await _playlist.insert(0, source);
          }
        }
      }
    } catch (e) {
      debugPrint("Error in background queueing: $e");
    }
  }
}

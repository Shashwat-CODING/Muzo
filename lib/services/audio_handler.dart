import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/services/stream_extraction_service.dart';

class AudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final StorageService _storage;
  late final MuzoApiService _apiService = MuzoApiService(_storage);
  late final MuzoApiService _musicApiService = _apiService;

  // Playlist for queue management
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    children: [],
  );

  // Keeps MuzoItem for each queue item (by ConcatenatingAudioSource index)
  // Used for lazy stream resolution: added to queue without a resolved URL,
  // resolved when the song becomes current.
  final Map<String, MuzoItem> _pendingQueueItems = {};
  final Set<String> _resolvingIds = {};
  String? _lastHistoryId;

  // Loading state
  final ValueNotifier<bool> isLoadingStream = ValueNotifier(false);

  AudioPlayer get player => _player;
  ConcatenatingAudioSource get playlist => _playlist;

  // Lofi Mode
  final ValueNotifier<bool> isLofiModeNotifier = ValueNotifier(false);

  // Platform channel for audio effects
  static const platform = MethodChannel('com.shashwat.muzo/audio_effects');

  AudioHandler(this._storage) {
    _init();
  }

  Future<void> toggleLofiMode() async {
    isLofiModeNotifier.value = !isLofiModeNotifier.value;
    await updateLofiSettings();
  }

  Future<void> updateLofiSettings() async {
    final enable = isLofiModeNotifier.value;

    // Apply speed/pitch
    if (enable) {
      await _player.setSpeed(_storage.lofiSpeed);
      await _player.setPitch(_storage.lofiPitch);
    } else {
      await _player.setSpeed(1.0);
      await _player.setPitch(1.0);
    }

    // Apply native reverb
    if (Platform.isAndroid) {
      final sessionId = await _player.androidAudioSessionId;
      if (sessionId != null) {
        await _applyReverb(sessionId, enable);
      }
    }
  }

  Future<void> _init() async {
    // Listen to player state to manage loading indicator and history
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.completed) {
        isLoadingStream.value = false;
      }

      // Log history only when actively playing a new track
      if (state.playing && state.processingState == ProcessingState.ready) {
        final index = _player.currentIndex;
        final sequence = _player.sequenceState?.sequence;
        if (index != null && sequence != null && index < sequence.length) {
          final source = sequence[index];
          final tag = source.tag;
          if (tag is MediaItem && tag.id != _lastHistoryId) {
            _lastHistoryId = tag
                .id; // Prevent duplicate logs for the same current play session
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
            );
            _storage.addToHistory(result);
          } else if (tag is MuzoItem && tag.videoId != _lastHistoryId) {
            _lastHistoryId = tag.videoId;
            _storage.addToHistory(tag);
          }
        }
      }
    });

    // 403 / source error retry — re-fetch stream URL via YoutubeExplode
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) async {
        debugPrint('Playback error (will retry): $e');
        await _retryCurrentTrack();
      },
    );

    // Listen to session ID changes to re-apply reverb
    _player.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId != null && isLofiModeNotifier.value) {
        _applyReverb(sessionId, true);
      }
    });

    _player.sequenceStateStream.listen((state) {
      final sequence = state.sequence;
      final index = state.currentIndex;

      if (sequence.isEmpty || (index != null && index >= sequence.length - 1)) {
        if (_storage.isAutoQueueEnabled) {
          _handleAutoQueue();
        }
      }
    });

    // Listen for index changes: resolve lazy items
    _player.currentIndexStream.listen((index) async {
      if (index == null) return;
      final sequence = _player.sequenceState?.sequence;
      if (sequence == null || index >= sequence.length) return;

      // 1. Resolve current track if lazy
      _resolveTrack(index);

      // 2. Pre-resolve next few tracks
      for (int i = 1; i <= 3; i++) {
        if (index + i < sequence.length) {
          _resolveTrack(index + i);
        }
      }
    });
  }

  /// Guarded resolution of a lazy track at a specific index.
  Future<void> _resolveTrack(int index) async {
    final sequence = _player.sequenceState?.sequence;
    if (sequence == null || index < 0 || index >= sequence.length) return;

    final source = sequence[index];
    final tag = source.tag;
    if (tag is! MediaItem || tag.extras?['lazy'] != true) return;

    final videoId = tag.id;
    if (_resolvingIds.contains(videoId)) return;

    _resolvingIds.add(videoId);
    if (index == _player.currentIndex) {
      isLoadingStream.value = true;
    }

    try {
      debugPrint('Resolving lazy track: $videoId at index $index');
      final streamUrl = await StreamExtractionService.getStreamUrl(videoId);

      if (streamUrl != null) {
        final realSource = AudioSource.uri(
          Uri.parse(streamUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Mobile Safari/537.36',
          },
          tag: tag.copyWith(extras: {...tag.extras ?? {}, 'lazy': false}),
        );

        // Re-check index and playlist state before applying
        final currentSequence = _player.sequenceState?.sequence;
        if (currentSequence != null &&
            index < currentSequence.length &&
            currentSequence[index].tag is MediaItem &&
            (currentSequence[index].tag as MediaItem).id == videoId) {
          final isCurrent = (_player.currentIndex == index);
          final wasPlaying = _player.playing;
          final currentPos = isCurrent ? _player.position : Duration.zero;

          await _playlist.removeAt(index);
          await _playlist.insert(index, realSource);

          if (isCurrent) {
            await _player.seek(Duration.zero, index: index);
            if (wasPlaying) await _player.play();
          }
        }
      }
    } catch (e) {
      debugPrint('Error resolving track $videoId: $e');
    } finally {
      _resolvingIds.remove(videoId);
      if (index == _player.currentIndex) {
        isLoadingStream.value = false;
      }
    }
  }

  /// Retries the currently playing track when a 403 or other stream error occurs.
  Future<void> _retryCurrentTrack() async {
    final index = _player.currentIndex;
    if (index == null) return;
    await _resolveTrack(index);
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
      String? videoId;
      if (video is MuzoItem) {
        videoId = video.videoId;
      }

      if (videoId == null) {
        debugPrint('playVideo: missing videoId');
        final context = navigatorKey.currentContext;
        if (context != null) {
          showGlassSnackBar(context, 'Cannot play this item: Missing ID');
        }
        return;
      }

      isLoadingStream.value = true;

      // Stop the player first to immediately abort current playback
      await _player.stop();

      // Resolve stream URL FIRST before clearing playlist,
      // so MiniPlayer doesn't disappear during the fetch.
      final source = await _createAudioSource(video);
      if (source == null) {
        isLoadingStream.value = false;
        final context = navigatorKey.currentContext;
        if (context != null) {
          showGlassSnackBar(context, 'Failed to extract audio stream');
        }
        return;
      }

      await _playlist.clear();
      await _playlist.add(source);

      if (_player.audioSource != _playlist) {
        await _player.setAudioSource(
          _playlist,
          initialPosition: Duration.zero,
          initialIndex: 0,
        );
      } else {
        await _player.seek(Duration.zero, index: 0);
      }
      await _player.play();
      isLoadingStream.value = false;
    } catch (e) {
      debugPrint('Error playing video: $e');
      isLoadingStream.value = false; // Hide spinner on error
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

        // If player is not set to this playlist (e.g. first item), set it
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

      if (downloadPath != null && await File(downloadPath).exists()) {
        audioUri = Uri.file(downloadPath);
      } else {
        final streamUrl = await StreamExtractionService.getStreamUrl(videoId);
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
          extras: {'resultType': resultType, 'artistId': artistId},
        ),
      );
    } catch (e) {
      debugPrint('Error creating audio source: $e');
      return null;
    }
  }

  Future<void> playAll(List<MuzoItem> results) async {
    try {
      if (results.isEmpty) return;

      await _player.stop();
      await _playlist.clear();

      // Resolve and play the first song immediately
      await addToQueue(results.first);

      if (_playlist.length > 0) {
        if (_player.audioSource != _playlist) {
          await _player.setAudioSource(
            _playlist,
            initialPosition: Duration.zero,
            initialIndex: 0,
          );
        } else {
          await _player.seek(Duration.zero, index: 0);
        }
        _player.play();
      }

      // Add the rest WITHOUT fetching stream URLs — they'll be resolved lazily
      // when each song becomes current (via the error/retry or index listener).
      if (results.length > 1) {
        for (int i = 1; i < results.length; i++) {
          await _addToQueueLazy(results[i]);
        }
      }
    } catch (e) {
      debugPrint('Error playing all: $e');
    }
  }

  /// Adds a song to the queue without resolving its stream URL.
  /// The stream URL is resolved when the song becomes current.
  Future<void> _addToQueueLazy(MuzoItem result) async {
    if (result.videoId == null) return;
    final videoId = result.videoId!;
    final title = result.title;
    final artist = result.displayArtist;
    final artUri = result.thumbnails.isNotEmpty
        ? result.thumbnails.last.url
        : '';
    final duration = result.durationSeconds != null
        ? Duration(seconds: result.durationSeconds!)
        : null;

    // Use a silent placeholder URI — will be replaced when track becomes current
    // We tag it with the MediaItem so we can identify and re-resolve it on error.
    final placeholder = AudioSource.uri(
      Uri.parse(
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      ), // tiny placeholder
      tag: MediaItem(
        id: videoId,
        album: 'Muzo',
        title: title,
        artist: artist,
        duration: duration,
        artUri: Uri.parse(artUri),
        extras: {'resultType': result.resultType, 'lazy': true},
      ),
    );
    await _playlist.add(placeholder);
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> seek(Duration position, {int? index}) =>
      _player.seek(position, index: index);
  Future<void> skipToNext() async {
    await _player.seekToNext();
    _player.play();
  }

  Future<void> skipToPrevious() async {
    await _player.seekToPrevious();
    _player.play();
  }

  void dispose() {
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
      // Keep the currently playing item if any
      final currentIndex = _player.currentIndex;
      if (currentIndex != null && _playlist.length > 1) {
        // Remove everything after
        if (currentIndex < _playlist.length - 1) {
          await _playlist.removeRange(currentIndex + 1, _playlist.length);
        }

        // Remove everything before
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

      // We need to insert after current index
      // But ConcatenatingAudioSource doesn't support insert at index easily with async logic inside addToQueue
      // So we'll use a modified version of addToQueue logic here

      String videoId;
      String title;
      String artist;
      String artUri;
      String resultType = 'video';
      String? artistId;
      Duration? duration;

      if (result.videoId == null) return;
      videoId = result.videoId!;
      title = result.title;
      artist = result.displayArtist;
      artistId = result.artists?.firstOrNull?.id;
      artUri = result.thumbnails.isNotEmpty ? result.thumbnails.last.url : '';
      resultType = result.resultType;
      if (result.durationSeconds != null) {
        duration = Duration(seconds: result.durationSeconds!);
      }

      // Check if downloaded
      final downloadPath = _storage.getDownloadPath(videoId);
      Uri audioUri;

      if (downloadPath != null && await File(downloadPath).exists()) {
        audioUri = Uri.file(downloadPath);
      } else {
        final streamUrl = await StreamExtractionService.getStreamUrl(videoId);
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
          extras: {'resultType': resultType, 'artistId': artistId},
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

  // Removed fallback alert method

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

      // Check if the current song is still the same as when we started
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

        // Add lazily — DO NOT fetch stream URLs here.
        // Each song's URL will be resolved on demand when it becomes current.
        for (final song in filteredSongs) {
          await _addToQueueLazy(song);
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

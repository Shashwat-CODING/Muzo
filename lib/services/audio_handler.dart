import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Listen to settings changes for real-time Lofi updates
    _storage.settingsListenable.addListener(() {
      if (isLofiModeNotifier.value) {
        _player.setSpeed(_storage.lofiSpeed);
        _player.setPitch(_storage.lofiPitch);
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
      final source = await _createAudioSource(video);
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

  Future<AudioSource?> _createAudioSource(dynamic video) async {
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
        artist =
            video.artists?.map((a) => a.name).join(', ') ??
            video.videoType ??
            'Unknown';
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
      Map<String, dynamic> extras = {
        'resultType': resultType,
        'artistId': artistId,
      };

      if (downloadPath != null && await File(downloadPath).exists()) {
        audioUri = Uri.file(downloadPath);
      } else {
        // Fetch stream manifest only - use source metadata directly
        final manifest = await _apiService.getStreamManifest(videoId);

        // Process Manifest
        if (manifest != null && (manifest as dynamic).audioStreams.isNotEmpty) {
          final typedManifest =
              manifest
                  as dynamic; // Cast to access properties if type inference fails
          // Process multi-language streams
          final uniqueLanguages =
              <String, String>{}; // name -> url (best bitrate)
          final languageBitrates = <String, int>{}; // name -> bitrate

          for (final stream in typedManifest.audioStreams) {
            final name = stream.languageDisplayName ?? "Default";
            final bitrate = stream.bitrate;

            if (!languageBitrates.containsKey(name) ||
                bitrate > languageBitrates[name]!) {
              languageBitrates[name] = bitrate;
              uniqueLanguages[name] = stream.url;
            }
          }

          final availableLanguages = uniqueLanguages.entries
              .map((e) => {'name': e.key, 'url': e.value})
              .toList();

          // Identify best default stream
          dynamic bestStream = typedManifest.audioStreams.first;
          String bestUrl = bestStream.url;
          String currentLanguage = bestStream.languageDisplayName ?? "Default";
          
          final bool isApple = Platform.isMacOS || Platform.isIOS;
          
          for (final stream in typedManifest.audioStreams) {
            // Helper to determine if stream is MP4/AAC friendly
            bool isMp4 = false;
            
            // 1. Check container (common in StreamInfo)
            try {
               // Check if 'container' property exists and convert to string
               // It might be an enum or object
               final container = (stream as dynamic).container.toString().toLowerCase();
               if (container.contains('mp4')) isMp4 = true;
            } catch (_) {}

            // 2. Check mimeType (if available)
            if (!isMp4) {
              try {
                 final mime = ((stream as dynamic).mimeType as String?) ?? '';
                 if (mime.contains('mp4') || mime.contains('audio/mp4')) isMp4 = true;
              } catch (_) {}
            }

            // 3. Check codec
            if (!isMp4) {
               try {
                  final codec = ((stream as dynamic).codec as String?) ?? '';
                  if (codec.contains('mp4') || codec.contains('aac')) isMp4 = true;
               } catch(_) {}
            }

            final int bitrate = stream.bitrate;
            
            // Check bestStream properties
            bool bestIsMp4 = false;
            try {
               final bContainer = (bestStream as dynamic).container.toString().toLowerCase();
               if (bContainer.contains('mp4')) bestIsMp4 = true;
            } catch (_) {}
            
            if (!bestIsMp4) {
               try {
                  final bMime = ((bestStream as dynamic).mimeType as String?) ?? '';
                  if (bMime.contains('mp4') || bMime.contains('audio/mp4')) bestIsMp4 = true;
               } catch (_) {}
            }

            bool shouldUse = false;
            final int bestBitrate = bestStream.bitrate;

            if (isApple) {
              // Prioritize MP4
              if (isMp4 && !bestIsMp4) {
                shouldUse = true;
              } else if (isMp4 == bestIsMp4 && bitrate > bestBitrate) {
                shouldUse = true;
              } else if (!isMp4 && !bestIsMp4 && bitrate > bestBitrate) {
                shouldUse = true;
              }
            } else {
              // Standard bitrate priority
              if (bitrate > bestBitrate) {
                shouldUse = true;
              }
            }

            if (shouldUse) {
              bestStream = stream;
              bestUrl = stream.url;
              currentLanguage = stream.languageDisplayName ?? "Default";
            }
          }
          
          debugPrint('Selected stream: URL=$bestUrl, Apple=$isApple');

          audioUri = Uri.parse(bestUrl);

          if (availableLanguages.length > 1) {
            extras['availableLanguages'] = availableLanguages;
            extras['currentLanguage'] = currentLanguage;
          }
        } else {
          // Fallback to old method
          final streamUrl = await _apiService.getStreamUrl(
            videoId,
            title: title,
            artist: artist,
            onFallback: () => _showFallbackAlert(),
          );
          if (streamUrl == null) return null;
          audioUri = Uri.parse(streamUrl);
        }
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

      // We need to preserve metadata but change URI
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
        // Optimization: If playlist has only 1 item, we can just set source directly
        // This is smoother than remove/insert
        if (_playlist.length == 1) {
          await _player.setAudioSource(newSource, initialPosition: currentPos);
          if (playing) {
            _player.play();
          }
          return;
        }

        // Fallback for playlist: Pause, Insert, Seek, Remove, Play
        await _player.pause();

        // Insert at current index (pushes current item down)
        await _playlist.insert(index, newSource);

        // Seek to new source (which is now at index)
        await _player.seek(currentPos, index: index);

        // Remove old source (which is now at index + 1)
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

      // Reallocate playlist
      _playlist = ConcatenatingAudioSource(children: []);

      // Add first item and play immediately
      final firstSource = await _createAudioSource(results.first);

      if (firstSource != null) {
        // Save original data to history (not enriched)
        _storage.addToHistory(results.first);

        await _playlist.add(firstSource);
        await _player.setAudioSource(_playlist);
        _player.play();
      }

      // Add the rest in background unawaited
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

      // Reallocate playlist
      _playlist = ConcatenatingAudioSource(children: []);

      // Optimization: Add ONLY the initial song first, start playing, then add the rest in background
      final initialSong = results[initialIndex];

      // 1. Add and play initial song
      final initialSource = await _createAudioSource(initialSong);
      if (initialSource != null) {
        // Save original data to history (not enriched)
        _storage.addToHistory(initialSong);

        await _playlist.add(initialSource);
        await _player.setAudioSource(_playlist);
        _player.play();
      }

      // 2. Add the rest (before and after) in background unawaited
      _queueRestOfPlaylist(results, initialIndex);
    } catch (e) {
      debugPrint('Error playing playlist: $e');
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> seek(Duration position, {int? index}) =>
      _player.seek(position, index: index);
  Future<void> skipToNext() => _player.seekToNext();
  Future<void> skipToPrevious() => _player.seekToPrevious();

  void dispose() {
    _player.dispose();
  }

  Future<void> playNext(YtifyResult result) async {
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
      artist =
          result.artists?.map((a) => a.name).join(', ') ??
          result.videoType ??
          'Unknown';
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
        final streamUrl = await _apiService.getStreamUrl(
          videoId,
          title: title,
          artist: artist,
          onFallback: () => _showFallbackAlert(),
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
        // We can't easily clear all EXCEPT one in ConcatenatingAudioSource without potentially stopping playback
        // But we can remove everything after current, and everything before current

        // Remove everything after
        if (currentIndex < _playlist.length - 1) {
          // removeRange is not available on ConcatenatingAudioSource directly in a way that is atomic for "all after"
          // We have to remove one by one from the end or use removeRange if supported (it's not in just_audio_background wrapper usually)
          // Actually ConcatenatingAudioSource has removeRange
          await _playlist.removeRange(currentIndex + 1, _playlist.length);
        }

        // Remove everything before
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

      // Check if the current song is still the same as when we started
      final currentTag = _player.sequenceState?.currentSource?.tag;
      if (currentTag is! MediaItem || currentTag.id != videoId) {
        debugPrint(
          'AutoQueue: Current song changed, discarding results for $videoId',
        );
        return;
      }

      if (nextSongs.isNotEmpty) {
        // Filter out current video
        final filteredSongs = nextSongs
            .where((s) => s.videoId != videoId)
            .toList();

        if (filteredSongs.isEmpty) return;

        // Limit to 5 songs to avoid freezing the UI with excessive network requests
        final limitedSongs = filteredSongs.take(5).toList();

        // Resolve sources in parallel
        final futures = limitedSongs.map((song) => _createAudioSource(song));
        final sources = await Future.wait(futures);

        // Check again before adding
        final currentTagAfterFetch = _player.sequenceState?.currentSource?.tag;
        if (currentTagAfterFetch is! MediaItem ||
            currentTagAfterFetch.id != videoId) {
          debugPrint(
            'AutoQueue: Current song changed during source creation, discarding results for $videoId',
          );
          return;
        }

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

  Future<void> _queueRestOfPlaylist(
    List<YtifyResult> results,
    int initialIndex,
  ) async {
    try {
      // Add songs AFTER initial index
      if (initialIndex < results.length - 1) {
        for (int i = initialIndex + 1; i < results.length; i++) {
          final source = await _createAudioSource(results[i]);
          if (source != null) {
            await _playlist.add(source);
          }
        }
      }

      // Add songs BEFORE initial index
      // We insert them at position 0, keeping their relative order
      // Iterate backwards from initialIndex - 1 to 0
      if (initialIndex > 0) {
        for (int i = initialIndex - 1; i >= 0; i--) {
          final source = await _createAudioSource(results[i]);
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

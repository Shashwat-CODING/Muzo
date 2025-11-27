import 'package:flutter/material.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:ytx/services/youtube_api_service.dart';
import 'package:ytx/models/ytify_result.dart';
import 'package:ytx/services/navigator_key.dart';
import 'package:ytx/services/storage_service.dart';
import 'package:ytx/widgets/glass_snackbar.dart';

class AudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final YouTubeApiService _apiService = YouTubeApiService();
  final StorageService _storage = StorageService();
  
  // Playlist for queue management
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  // Loading state
  final ValueNotifier<bool> isLoadingStream = ValueNotifier(false);

  AudioPlayer get player => _player;
  ConcatenatingAudioSource get playlist => _playlist;

  AudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // Listen to player state to manage loading indicator
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.ready || state == ProcessingState.completed) {
        isLoadingStream.value = false;
      }
    });
  }

  Future<void> playVideo(dynamic video) async {
    try {
      isLoadingStream.value = true;
      // Add to history
      if (video is YtifyResult) {
        _storage.addToHistory(video);
      }

      // Clear queue and play single video
      await _playlist.clear();
      await addToQueue(video);
      await _player.setAudioSource(_playlist);
      await _player.play();
      
      // Queue related videos immediately
      if (video is YtifyResult && video.videoId != null) {
        _queueRelatedVideos(video.videoId!);
      }
    } catch (e) {
      debugPrint('Error playing video: $e');
      isLoadingStream.value = false; // Hide spinner on error
    }
  }

  Future<void> _queueRelatedVideos(String videoId) async {
    if (!_storage.autoQueueEnabled) return;

    try {
      final related = await _apiService.getRelatedVideos(videoId);
      if (related.isNotEmpty) {
        for (final item in related) {
          // Check if already in queue
          bool alreadyInQueue = false;
          for (final source in _playlist.sequence) {
            if ((source.tag as MediaItem).id == item.videoId) {
              alreadyInQueue = true;
              break;
            }
          }
          
          if (!alreadyInQueue) {
            await addToQueue(item);
          }
        }
      }
    } catch (e) {
      debugPrint('Error queueing related videos: $e');
    }
  }

  Future<void> addToQueue(dynamic video) async {
    try {
      String videoId;
      String title;
      String artist;
      String artUri;
      String resultType = 'video';

      String? artistId;
      if (video is YtifyResult) {
        if (video.videoId == null) return;
        videoId = video.videoId!;
        title = video.title;
        artist = video.artists?.map((a) => a.name).join(', ') ?? video.videoType ?? 'Unknown';
        artistId = video.artists?.firstOrNull?.id;
        artUri = video.thumbnails.isNotEmpty ? video.thumbnails.last.url : '';
        resultType = video.resultType;
      } else {
        return;
      }

      // Check if downloaded
      final downloadPath = _storage.getDownloadPath(videoId);
      Uri audioUri;
      
      if (downloadPath != null && await File(downloadPath).exists()) {
        audioUri = Uri.file(downloadPath);
      } else {
        // We need to know if fallback was used. 
        // Since getStreamUrl returns just the string, we can't know for sure without changing the return type.
        // However, we can check if the URL looks like a fallback URL (e.g. from invidious or just different domain).
        // But the fallback logic is inside apiService.
        // A better approach is to have a callback or a separate method.
        // For now, let's just pass the title and artist.
        // To show the alert, we can check if the returned URL is NOT from googlevideo.com (primary) 
        // but that might be flaky if primary uses other domains.
        // Alternatively, we can add a callback to getStreamUrl? No, simpler to just check the domain.
        // Primary URLs usually contain 'googlevideo.com'.
        
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
          'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Mobile Safari/537.36',
        },
        tag: MediaItem(
          id: videoId,
          album: "YTX Music",
          title: title,
          artist: artist,
          artUri: Uri.parse(artUri),
          extras: {
            'resultType': resultType,
            'artistId': artistId,
          },
        ),
      );

      await _playlist.add(audioSource);
      
      // If player is not set to this playlist (e.g. first item), set it
      if (_player.audioSource != _playlist) {
        await _player.setAudioSource(_playlist);
      }

    } catch (e) {
      debugPrint('Error adding to queue: $e');
    }
  }



  Future<void> playAll(List<YtifyResult> results) async {
    try {
      if (results.isEmpty) return;

      await _player.stop();
      await _playlist.clear();
      
      // Add first item and play immediately
      _storage.addToHistory(results.first);
      await addToQueue(results.first);
      
      if (_playlist.length > 0) {
         await _player.setAudioSource(_playlist);
         _player.play(); 
      }

      // Add the rest in background, but await to ensure order
      if (results.length > 1) {
        for (int i = 1; i < results.length; i++) {
          await addToQueue(results[i]); 
        }
      }
    } catch (e) {
      debugPrint('Error playing all: $e');
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> seek(Duration position, {int? index}) => _player.seek(position, index: index);
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

      if (result.videoId == null) return;
      videoId = result.videoId!;
      title = result.title;
      artist = result.artists?.map((a) => a.name).join(', ') ?? result.videoType ?? 'Unknown';
      artistId = result.artists?.firstOrNull?.id;
      artUri = result.thumbnails.isNotEmpty ? result.thumbnails.last.url : '';
      resultType = result.resultType;

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
          'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Mobile Safari/537.36',
        },
        tag: MediaItem(
          id: videoId,
          album: "YTX Music",
          title: title,
          artist: artist,
          artUri: Uri.parse(artUri),
          extras: {
            'resultType': resultType,
            'artistId': artistId,
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

  void _showFallbackAlert() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showGlassSnackBar(context, 'Using fallback playback API');
    }
  }
}

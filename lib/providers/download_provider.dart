import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/ytify_result.dart';
import 'package:muzo/services/download_service.dart';
import 'package:muzo/services/storage_service.dart';

class DownloadState {
  final Map<String, double> progressMap;
  final Map<String, YtifyResult> activeDownloads;

  DownloadState({
    this.progressMap = const {},
    this.activeDownloads = const {},
  });

  DownloadState copyWith({
    Map<String, double>? progressMap,
    Map<String, YtifyResult>? activeDownloads,
  }) {
    return DownloadState(
      progressMap: progressMap ?? this.progressMap,
      activeDownloads: activeDownloads ?? this.activeDownloads,
    );
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(ref);
});

class DownloadNotifier extends StateNotifier<DownloadState> {
  final Ref ref;
  final DownloadService _downloadService = DownloadService();

  DownloadNotifier(this.ref) : super(DownloadState());

  Future<bool> startDownload(YtifyResult result) async {
    if (result.videoId == null) return false;
    
    // Add to active downloads
    state = state.copyWith(
      activeDownloads: {...state.activeDownloads, result.videoId!: result},
      progressMap: {...state.progressMap, result.videoId!: 0.0},
    );

    final success = await _downloadService.downloadSong(
      result,
      onProgress: (received, total) {
        if (total != -1) {
          final progress = received / total;
          state = state.copyWith(
            progressMap: {...state.progressMap, result.videoId!: progress},
          );
        }
      },
    );

    // Remove from active downloads
    final newActive = Map<String, YtifyResult>.from(state.activeDownloads);
    newActive.remove(result.videoId);
    
    final newProgress = Map<String, double>.from(state.progressMap);
    newProgress.remove(result.videoId);

    state = state.copyWith(
      activeDownloads: newActive,
      progressMap: newProgress,
    );

    return success;
  }
  Future<void> deleteDownload(String videoId) async {
    final storage = ref.read(storageServiceProvider);
    
    // Check if it's an active download
    if (state.activeDownloads.containsKey(videoId)) {
      // TODO: Cancel active download (requires DownloadService update)
      // For now, just remove from state
      final newActive = Map<String, YtifyResult>.from(state.activeDownloads);
      newActive.remove(videoId);
      
      final newProgress = Map<String, double>.from(state.progressMap);
      newProgress.remove(videoId);

      state = state.copyWith(
        activeDownloads: newActive,
        progressMap: newProgress,
      );
    }

    // Remove from storage and file system
    final path = storage.getDownloadPath(videoId);
    if (path != null) {
      // TODO: Delete file from file system
      // final file = File(path);
      // if (await file.exists()) await file.delete();
      
      await storage.removeDownload(videoId);
    }
  }
}

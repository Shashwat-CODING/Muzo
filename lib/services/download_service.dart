import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ytx/models/ytify_result.dart';
import 'package:ytx/services/storage_service.dart';
import 'package:ytx/services/youtube_api_service.dart';
import 'package:ytx/services/notification_service.dart';

class DownloadService {
  final Dio _dio = Dio();
  final YouTubeApiService _apiService = YouTubeApiService();
  final StorageService _storage = StorageService();

  Future<bool> downloadSong(YtifyResult result, {Function(int, int)? onProgress}) async {
    final notificationId = result.videoId.hashCode;
    try {
      if (result.videoId == null) return false;

      // Check permission
      if (!await _requestPermission()) {
        debugPrint('Permission denied');
        return false;
      }

      // Get download path
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/${result.videoId}.m4a';
      final file = File(savePath);

      // Check if already exists and is valid
      if (await file.exists()) {
        if (await file.length() > 0) {
          debugPrint('File already exists and is valid');
          await _storage.addDownload(result, savePath);
          await NotificationService().showCompletionNotification(
            id: notificationId,
            title: 'Download Complete',
            body: '${result.title} is already downloaded.',
          );
          return true;
        } else {
          // Delete empty/corrupt file
          await file.delete();
        }
      }

      await NotificationService().showProgressNotification(
        id: notificationId,
        title: 'Downloading...',
        body: result.title,
        progress: 0,
        maxProgress: 100,
      );

      // Get stream URL
      final streamUrl = await _apiService.getStreamUrl(
        result.videoId!,
        title: result.title,
        artist: result.artists?.map((a) => a.name).join(', ') ?? result.videoType ?? 'Unknown',
      );
      if (streamUrl == null) {
        debugPrint('Failed to get stream URL');
        await NotificationService().showCompletionNotification(
          id: notificationId,
          title: 'Download Failed',
          body: 'Could not get stream URL for ${result.title}',
          isError: true,
        );
        return false;
      }

      // Download
      await _dio.download(
        streamUrl, 
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toInt();
            NotificationService().showProgressNotification(
              id: notificationId,
              title: 'Downloading...',
              body: result.title,
              progress: progress,
              maxProgress: 100,
            );
            onProgress?.call(received, total);
          }
        },
        deleteOnError: true,
      );

      // Verify download
      if (await file.exists() && await file.length() > 0) {
        // Save to storage
        await _storage.addDownload(result, savePath);
        await NotificationService().showCompletionNotification(
          id: notificationId,
          title: 'Download Complete',
          body: result.title,
        );
        return true;
      } else {
        debugPrint('Download failed: File not found or empty');
        await NotificationService().showCompletionNotification(
          id: notificationId,
          title: 'Download Failed',
          body: 'File verification failed for ${result.title}',
          isError: true,
        );
        return false;
      }
    } catch (e) {
      debugPrint('Download error: $e');
      await NotificationService().showCompletionNotification(
        id: notificationId,
        title: 'Download Failed',
        body: 'Error downloading ${result.title}',
        isError: true,
      );
      return false;
    }
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      // On Android 10+ (API 29+), scoped storage is used, so WRITE_EXTERNAL_STORAGE 
      // is not needed for app-specific directories (getApplicationDocumentsDirectory).
      // However, for older versions, it might be needed.
      // Since we are targeting modern Android, we might skip this or check version.
      // But let's just return true for now as we use app-specific storage.
      return true;
    }
    return true;
  }
  
  Future<void> deleteDownload(String videoId) async {
    final path = _storage.getDownloadPath(videoId);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      await _storage.removeDownload(videoId);
    }
  }
}

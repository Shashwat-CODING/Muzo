import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/spotify_import_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class SpotifyImportDialog extends ConsumerStatefulWidget {
  const SpotifyImportDialog({super.key});

  @override
  ConsumerState<SpotifyImportDialog> createState() => _SpotifyImportDialogState();
}

class _SpotifyImportDialogState extends ConsumerState<SpotifyImportDialog> {
  final TextEditingController _controller = TextEditingController();
  StreamSubscription<SpotifyImportProgress>? _subscription;
  SpotifyImportProgress? _currentProgress;
  bool _isImporting = false;

  @override
  void dispose() {
    _controller.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  void _startImport() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isImporting = true;
      _currentProgress = SpotifyImportProgress(status: 'Starting...');
    });

    final service = ref.read(spotifyImportServiceProvider);
    _subscription = service.importPlaylist(input).listen(
      (progress) {
        if (mounted) {
          setState(() {
            _currentProgress = progress;
            if (progress.isComplete) {
              _isImporting = false;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isImporting = false;
            _currentProgress = _currentProgress?.copyWith(
              hasError: true,
              isComplete: true,
              errorMessage: error.toString(),
            ) ?? SpotifyImportProgress(hasError: true, isComplete: true, errorMessage: error.toString());
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final spotifyGreen = const Color(0xFF1DB954);
    
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181A).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 10),
              )
            ],
          ),
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: spotifyGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(FluentIcons.arrow_import_24_filled, color: spotifyGreen, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Import from Spotify',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (!_isImporting && (_currentProgress == null || _currentProgress!.hasError)) ...[
                CupertinoTextField(
                  controller: _controller,
                  placeholder: 'Paste Playlist URL',
                  placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey),
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.3) : CupertinoColors.systemGrey6.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    )
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 14.0),
                    child: Icon(FluentIcons.link_24_regular, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 22),
                  ),
                ),
                if (_currentProgress?.hasError == true) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(FluentIcons.error_circle_24_regular, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _currentProgress!.errorMessage ?? 'An error occurred.',
                            style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else if (_currentProgress != null) ...[
                const SizedBox(height: 12),
                if (!_currentProgress!.isComplete)
                  const SizedBox(
                    height: 56,
                    width: 56,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else if (!_currentProgress!.hasError)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: spotifyGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(FluentIcons.checkmark_circle_48_filled, color: spotifyGreen, size: 48),
                        ),
                      );
                    },
                  ),
                
                const SizedBox(height: 24),
                Text(
                  _currentProgress!.status,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_currentProgress!.total > 0 && !_currentProgress!.isComplete) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _currentProgress!.total > 0 ? (_currentProgress!.current / _currentProgress!.total) : null,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(spotifyGreen),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${((_currentProgress!.current / _currentProgress!.total) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_isImporting)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _currentProgress?.isComplete == true && !_currentProgress!.hasError ? 'Close' : 'Cancel', 
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 15, fontWeight: FontWeight.bold)
                      ),
                    ),
                  if (!_isImporting && (_currentProgress == null || _currentProgress!.hasError)) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _startImport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: spotifyGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Import', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

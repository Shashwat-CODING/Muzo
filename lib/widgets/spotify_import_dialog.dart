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
    final dividerCol = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.65) : const Color(0xFFE5E5EA).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: spotifyGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(FluentIcons.arrow_import_24_filled, color: spotifyGreen, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Import from Spotify',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (!_isImporting && (_currentProgress == null || _currentProgress!.hasError)) ...[
                        CupertinoTextField(
                          controller: _controller,
                          placeholder: 'Paste Playlist URL',
                          placeholderStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.35), fontSize: 14),
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                              width: 0.8,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 12.0),
                            child: Icon(FluentIcons.link_24_regular, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 18),
                          ),
                        ),
                        if (_currentProgress?.hasError == true) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.1), width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const Icon(FluentIcons.error_circle_24_regular, color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _currentProgress!.errorMessage ?? 'An error occurred.',
                                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        if (_currentProgress != null) ...[
                          const SizedBox(height: 12),
                          if (!_currentProgress!.isComplete)
                            const Center(
                              child: CupertinoActivityIndicator(radius: 12),
                            )
                          else if (!_currentProgress!.hasError)
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutBack,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: spotifyGreen.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(FluentIcons.checkmark_circle_24_filled, color: spotifyGreen, size: 36),
                                  ),
                                );
                              },
                            ),
                          
                          const SizedBox(height: 16),
                          Text(
                            _currentProgress!.status,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_currentProgress!.total > 0 && !_currentProgress!.isComplete) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _currentProgress!.total > 0 ? (_currentProgress!.current / _currentProgress!.total) : null,
                                backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(spotifyGreen),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${((_currentProgress!.current / _currentProgress!.total) * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
                if (!_isImporting) ...[
                  Container(height: 0.5, color: dividerCol),
                  if (_currentProgress == null || _currentProgress!.hasError)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 17,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(width: 0.5, height: 44, color: dividerCol),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextButton(
                              onPressed: _startImport,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              ),
                              child: Text(
                                'Import',
                                style: TextStyle(
                                  color: spotifyGreen,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

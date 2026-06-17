import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:muzo/models/user_track.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/widgets/global_background.dart';
import 'package:muzo/widgets/app_alert_dialog.dart';

class UserTracksScreen extends ConsumerStatefulWidget {
  const UserTracksScreen({super.key});

  @override
  ConsumerState<UserTracksScreen> createState() => _UserTracksScreenState();
}

class _UserTracksScreenState extends ConsumerState<UserTracksScreen> {
  List<UserTrack> _tracks = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(muzoApiServiceProvider);
      final tracks = await api.getUserTracks();
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UploadTrackDialog(
        onUploadComplete: () {
          _loadTracks();
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, UserTrack track) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => EditTrackDialog(
        track: track,
        onUpdated: _loadTracks,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, UserTrack track) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DeleteTrackDialog(
        track: track,
        onDeleted: _loadTracks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMediaItem = ref.watch(currentMediaItemProvider).value;
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;

    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTracks,
          color: Theme.of(context).primaryColor,
          backgroundColor: Theme.of(context).cardColor,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                floating: true,
                pinned: false,
                title: Text(
                  'My Uploads',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                ),
                iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
                actions: [
                  IconButton(
                    onPressed: () => _showUploadDialog(context),
                    icon: Icon(FluentIcons.add_24_regular, color: Theme.of(context).colorScheme.onSurface),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),

              if (_isLoading && _tracks.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null && _tracks.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FluentIcons.warning_24_regular,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _loadTracks,
                            icon: const Icon(FluentIcons.arrow_sync_24_regular),
                            label: const Text('Retry'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_tracks.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FluentIcons.cloud_arrow_up_24_regular,
                            size: 72,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No uploads yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the button below or in the top right corner to upload your first audio track to Muzo!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _showUploadDialog(context),
                            icon: const Icon(FluentIcons.cloud_arrow_up_24_filled),
                            label: const Text('Upload Track'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = _tracks[index];
                      final muzoItem = track.toMuzoItem();
                      final isCurrent = currentMediaItem?.id == muzoItem.videoId;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(audioHandlerProvider).playVideo(muzoItem);
                          },
                           child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                            child: Row(
                              children: [
                                // Thumbnail
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: track.thumbnailUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: track.thumbnailUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: Colors.grey[900]),
                                            errorWidget: (_, __, ___) => Container(
                                              color: Colors.grey[900],
                                              child: const Icon(FluentIcons.music_note_2_24_regular),
                                            ),
                                          )
                                        : Container(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                            child: Icon(
                                              FluentIcons.music_note_2_24_regular,
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title and Description
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isCurrent 
                                              ? Theme.of(context).primaryColor 
                                              : Theme.of(context).colorScheme.onSurface,
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        track.description != null && track.description!.isNotEmpty
                                            ? track.description!
                                            : 'No description',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Current track indicator
                                if (isCurrent) ...[
                                  Icon(
                                    isPlaying ? FluentIcons.play_circle_24_filled : FluentIcons.pause_circle_24_filled,
                                    color: Theme.of(context).primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Menu options (edit/delete)
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    FluentIcons.more_vertical_24_regular,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    size: 20,
                                  ),
                                  onSelected: (value) {
                                    HapticFeedback.lightImpact();
                                    if (value == 'edit') {
                                      _showEditDialog(context, track);
                                    } else if (value == 'delete') {
                                      _showDeleteConfirmation(context, track);
                                    }
                                  },
                                  color: Theme.of(context).cardColor,
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(FluentIcons.edit_24_regular, size: 16, color: Theme.of(context).colorScheme.onSurface),
                                          const SizedBox(width: 8),
                                          Text('Edit Metadata', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(FluentIcons.delete_24_regular, size: 16, color: Colors.red),
                                          const SizedBox(width: 8),
                                          const Text('Delete Track', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _tracks.length,
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
            ],
          ),
        ),
      ),
    ),);
  }
}

// ─────────────────────────────────────────────
//  Helper: Section label above a grouped form group
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Helper: Grouped form container (iOS style)
// ─────────────────────────────────────────────
class _GroupedCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupedCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: cs.onSurface.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: cs.onSurface.withValues(alpha: 0.1),
                  indent: 16,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Upload Track Dialog
// ─────────────────────────────────────────────
class UploadTrackDialog extends ConsumerStatefulWidget {
  final VoidCallback onUploadComplete;

  const UploadTrackDialog({super.key, required this.onUploadComplete});

  @override
  ConsumerState<UploadTrackDialog> createState() => _UploadTrackDialogState();
}

class _UploadTrackDialogState extends ConsumerState<UploadTrackDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  String? _audioPath;
  String? _audioFileName;
  String? _thumbnailPath;
  String? _thumbnailFileName;
  
  bool _isUploading = false;
  bool _isPublic = false;

  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _audioPath = result.files.single.path;
          _audioFileName = result.files.single.name;
          
          // Auto-fill title if empty
          if (_titleController.text.isEmpty && _audioFileName != null) {
            final nameWithoutExt = _audioFileName!.substring(0, _audioFileName!.lastIndexOf('.'));
            _titleController.text = nameWithoutExt.replaceAll(RegExp(r'[_-]'), ' ');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, 'Error picking audio file: $e');
      }
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _thumbnailPath = result.files.single.path;
          _thumbnailFileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, 'Error picking cover art: $e');
      }
    }
  }

  Future<void> _handleUpload() async {
    if (_audioPath == null) {
      showGlassSnackBar(context, 'Please select an audio file');
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      showGlassSnackBar(context, 'Please enter a title');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final api = ref.read(muzoApiServiceProvider);
      await api.uploadTrack(
        audioPath: _audioPath!,
        thumbnailPath: _thumbnailPath,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        isPublic: _isPublic,
      );

      if (mounted) {
        showGlassSnackBar(context, 'Track uploaded successfully!');
        widget.onUploadComplete();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, 'Upload failed: $e');
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final dialogBg = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.94);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.08),
                width: 0.5,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          FluentIcons.cloud_arrow_up_24_regular,
                          color: theme.primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Track',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Share your music with Muzo',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isUploading)
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── File Pickers ─────────────────────────────
                  _SectionLabel('Files'),
                  Row(
                    children: [
                      // Audio Picker
                      Expanded(
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAudio,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 90,
                            decoration: BoxDecoration(
                              color: _audioPath != null
                                  ? theme.primaryColor.withValues(alpha: 0.1)
                                  : cs.onSurface.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _audioPath != null
                                    ? theme.primaryColor.withValues(alpha: 0.4)
                                    : cs.onSurface.withValues(alpha: 0.1),
                                width: _audioPath != null ? 1.5 : 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _audioPath != null
                                      ? FluentIcons.checkmark_circle_20_filled
                                      : FluentIcons.arrow_upload_20_regular,
                                  color: _audioPath != null
                                      ? theme.primaryColor
                                      : cs.onSurface.withValues(alpha: 0.5),
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _audioPath != null ? 'Audio Ready' : 'Audio File *',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _audioPath != null
                                        ? theme.primaryColor
                                        : cs.onSurface,
                                  ),
                                ),
                                if (_audioFileName != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    child: Text(
                                      _audioFileName!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: cs.onSurface.withValues(alpha: 0.45),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Cover Art Picker
                      Expanded(
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickThumbnail,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 90,
                            decoration: BoxDecoration(
                              color: _thumbnailPath != null
                                  ? theme.primaryColor.withValues(alpha: 0.1)
                                  : cs.onSurface.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _thumbnailPath != null
                                    ? theme.primaryColor.withValues(alpha: 0.4)
                                    : cs.onSurface.withValues(alpha: 0.1),
                                width: _thumbnailPath != null ? 1.5 : 0.5,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_thumbnailPath != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(_thumbnailPath!),
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Icon(
                                        FluentIcons.image_20_regular,
                                        color: cs.onSurface.withValues(alpha: 0.5),
                                        size: 24,
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _thumbnailPath != null ? 'Cover Ready' : 'Cover Art',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _thumbnailPath != null
                                            ? theme.primaryColor
                                            : cs.onSurface,
                                      ),
                                    ),
                                    if (_thumbnailFileName != null)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        child: Text(
                                          _thumbnailFileName!,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: cs.onSurface.withValues(alpha: 0.45),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                                if (_thumbnailPath != null && !_isUploading)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _thumbnailPath = null;
                                          _thumbnailFileName = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: cs.onSurface.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.close, size: 10, color: cs.onSurface),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Track Info ───────────────────────────────
                  _SectionLabel('Track Info'),
                  _GroupedCard(
                    children: [
                      // Title
                      CupertinoTextField(
                        controller: _titleController,
                        enabled: !_isUploading,
                        placeholder: 'Track Title',
                        placeholderStyle: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.35),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: const BoxDecoration(color: Colors.transparent),
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 14.0),
                          child: Icon(
                            FluentIcons.music_note_2_24_regular,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      // Description
                      CupertinoTextField(
                        controller: _descController,
                        enabled: !_isUploading,
                        placeholder: 'Description (optional)',
                        placeholderStyle: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.35),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 3,
                        minLines: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: const BoxDecoration(color: Colors.transparent),
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 14.0, bottom: 26),
                          child: Icon(
                            FluentIcons.text_description_24_regular,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Visibility ───────────────────────────────
                  _SectionLabel('Visibility'),
                  _GroupedCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: (_isPublic ? theme.primaryColor : cs.onSurface)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _isPublic
                                    ? FluentIcons.people_community_24_regular
                                    : FluentIcons.lock_shield_24_regular,
                                size: 17,
                                color: _isPublic
                                    ? theme.primaryColor
                                    : cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Share with Community',
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _isPublic
                                        ? 'Visible in the Community Feed'
                                        : 'Only visible to you',
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(alpha: 0.4),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoSwitch(
                              value: _isPublic,
                              activeTrackColor: theme.primaryColor,
                              onChanged: _isUploading
                                  ? null
                                  : (value) => setState(() => _isPublic = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Upload Progress ──────────────────────────
                  if (_isUploading) ...[
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        color: theme.primaryColor,
                        backgroundColor: theme.primaryColor.withValues(alpha: 0.12),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Uploading your track…',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Upload Button ────────────────────────────
                  GestureDetector(
                    onTap: _isUploading ? null : _handleUpload,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isUploading
                            ? cs.onSurface.withValues(alpha: 0.45)
                            : cs.onSurface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _isUploading
                            ? []
                            : [
                                BoxShadow(
                                  color: cs.onSurface.withValues(alpha: 0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isUploading)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.surface,
                              ),
                            )
                          else
                            Icon(
                              FluentIcons.cloud_arrow_up_24_regular,
                              color: cs.surface,
                              size: 18,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isUploading ? 'Uploading…' : 'Upload Track',
                            style: TextStyle(
                              color: cs.surface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Edit Track Dialog
// ─────────────────────────────────────────────
class EditTrackDialog extends ConsumerStatefulWidget {
  final UserTrack track;
  final VoidCallback onUpdated;

  const EditTrackDialog({
    super.key,
    required this.track,
    required this.onUpdated,
  });

  @override
  ConsumerState<EditTrackDialog> createState() => _EditTrackDialogState();
}

class _EditTrackDialogState extends ConsumerState<EditTrackDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  bool _isSaving = false;
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _descController = TextEditingController(text: widget.track.description ?? '');
    _isPublic = widget.track.isPublic;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showGlassSnackBar(context, 'Please enter a title');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = ref.read(muzoApiServiceProvider);
      await api.updateTrack(
        widget.track.id,
        title: title,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        isPublic: _isPublic,
      );

      if (mounted) {
        showGlassSnackBar(context, 'Metadata updated!');
        widget.onUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, 'Update failed: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final dialogBg = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.94);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.08),
                width: 0.5,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          FluentIcons.edit_24_regular,
                          color: theme.primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Track',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Update metadata & visibility',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isSaving)
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Current Track Preview ────────────────────
                  if (widget.track.thumbnailUrl != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: cs.onSurface.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: widget.track.thumbnailUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                color: cs.onSurface.withValues(alpha: 0.08),
                                child: Icon(
                                  FluentIcons.music_note_2_24_regular,
                                  color: cs.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.track.title,
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.track.isPublic ? 'Currently Public' : 'Currently Private',
                                  style: TextStyle(
                                    color: widget.track.isPublic
                                        ? theme.primaryColor
                                        : cs.onSurface.withValues(alpha: 0.4),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Track Info ───────────────────────────────
                  _SectionLabel('Track Info'),
                  _GroupedCard(
                    children: [
                      CupertinoTextField(
                        controller: _titleController,
                        enabled: !_isSaving,
                        placeholder: 'Track Title',
                        placeholderStyle: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.35),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: const BoxDecoration(color: Colors.transparent),
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 14.0),
                          child: Icon(
                            FluentIcons.music_note_2_24_regular,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      CupertinoTextField(
                        controller: _descController,
                        enabled: !_isSaving,
                        placeholder: 'Description or Lyrics (optional)',
                        placeholderStyle: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.35),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 3,
                        minLines: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: const BoxDecoration(color: Colors.transparent),
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 14.0, bottom: 26),
                          child: Icon(
                            FluentIcons.text_description_24_regular,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Visibility ───────────────────────────────
                  _SectionLabel('Visibility'),
                  _GroupedCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: (_isPublic ? theme.primaryColor : cs.onSurface)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _isPublic
                                    ? FluentIcons.people_community_24_regular
                                    : FluentIcons.lock_shield_24_regular,
                                size: 17,
                                color: _isPublic
                                    ? theme.primaryColor
                                    : cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Share with Community',
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _isPublic
                                        ? 'Visible in the Community Feed'
                                        : 'Only visible to you',
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(alpha: 0.4),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoSwitch(
                              value: _isPublic,
                              activeTrackColor: theme.primaryColor,
                              onChanged: _isSaving
                                  ? null
                                  : (value) => setState(() => _isPublic = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Save Progress ────────────────────────────
                  if (_isSaving) ...[
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        color: theme.primaryColor,
                        backgroundColor: theme.primaryColor.withValues(alpha: 0.12),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saving changes…',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Save Button ──────────────────────────────
                  GestureDetector(
                    onTap: _isSaving ? null : _handleSave,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isSaving
                            ? cs.onSurface.withValues(alpha: 0.45)
                            : cs.onSurface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _isSaving
                            ? []
                            : [
                                BoxShadow(
                                  color: cs.onSurface.withValues(alpha: 0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSaving)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.surface,
                              ),
                            )
                          else
                            Icon(
                              FluentIcons.checkmark_24_regular,
                              color: cs.surface,
                              size: 18,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isSaving ? 'Saving…' : 'Save Changes',
                            style: TextStyle(
                              color: cs.surface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Delete Track Dialog
// ─────────────────────────────────────────────
class DeleteTrackDialog extends ConsumerStatefulWidget {
  final UserTrack track;
  final VoidCallback onDeleted;

  const DeleteTrackDialog({
    super.key,
    required this.track,
    required this.onDeleted,
  });

  @override
  ConsumerState<DeleteTrackDialog> createState() => _DeleteTrackDialogState();
}

class _DeleteTrackDialogState extends ConsumerState<DeleteTrackDialog> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    setState(() => _isDeleting = true);

    try {
      final api = ref.read(muzoApiServiceProvider);
      await api.deleteTrack(widget.track.id);

      if (mounted) {
        showGlassSnackBar(context, 'Track deleted');
        widget.onDeleted();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, 'Delete failed: $e');
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppAlertDialog(
      title: 'Delete Track',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Are you sure you want to delete\n"${widget.track.title}"?',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'This action cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (_isDeleting) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                color: Colors.red,
                backgroundColor: Colors.transparent,
                minHeight: 2,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: theme.primaryColor)),
        ),
        TextButton(
          onPressed: _isDeleting ? null : _handleDelete,
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class LibraryTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final bool isRound; // For artists
  final bool isPinned;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final IconData? placeholderIcon;

  const LibraryTile({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.isRound = false,
    this.isPinned = false,
    this.isLoading = false,
    required this.onTap,
    this.onLongPress,
    this.trailing,
    this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      onTap: onTap,
      onLongPress: onLongPress,
      leading: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: isRound ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isRound ? null : BorderRadius.circular(6),
                color: Colors.grey[850], // Placeholder color
                border: isLoading
                    ? Border.all(color: const Color(0xFF1ED760), width: 2)
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  isRound ? 46 : (isLoading ? 2 : 6),
                ), // Adjust radius if border present
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Center(
                          child: Icon(
                            placeholderIcon ??
                                FluentIcons.music_note_2_24_regular,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          placeholderIcon ??
                              FluentIcons.music_note_2_24_regular,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Row(
              children: [
                if (isPinned) ...[
                  Transform.rotate(
                    angle: 0.7,
                    child: const Icon(
                      FluentIcons.pin_12_filled,
                      color: Color(0xFF1ED760),
                      size: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            )
          : null,
      trailing: trailing ??
          Icon(
            CupertinoIcons.chevron_right,
            size: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
          ),
    );
  }
}

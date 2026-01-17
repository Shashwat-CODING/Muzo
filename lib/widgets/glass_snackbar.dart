import 'dart:ui';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'package:muzo/providers/theme_provider.dart';

void showGlassSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.zero,
      content: _GlassSnackBarContent(message: message),
    ),
  );
}

class _GlassSnackBarContent extends ConsumerWidget {
  final String message;

  const _GlassSnackBarContent({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiteMode = ref.watch(settingsProvider).isLiteMode;
    final dynamicColorScheme = ref.watch(dynamicColorSchemeProvider);
    final themeColor = ref.watch(themeColorProvider);
    // Use album art color first, then device accent, then fallback
    final accentColor =
        themeColor ?? dynamicColorScheme?.primary ?? const Color(0xFF5bc0be);

    if (isLiteMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accentColor.withValues(alpha: 0.25),
            const Color(0xFF272727),
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.5,
              ), // Stronger shadow for depth
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.checkmark_circle_24_regular,
              color: accentColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              accentColor.withValues(alpha: 0.15),
              const Color(0xFF1E1E1E).withValues(alpha: 0.8),
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.4),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.checkmark_circle_24_regular,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

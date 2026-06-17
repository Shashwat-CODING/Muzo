import 'package:flutter/material.dart';
import 'package:muzo/widgets/glass_container.dart';

class AppAlertDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const AppAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerCol = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return Dialog(
      backgroundColor: Colors.transparent, // Important for glass effect
      insetPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 24),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
        opacity: isDark ? 0.65 : 0.85,
        blur: 20.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.35,
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
                child: content,
              ),
            ),
            if (actions.isNotEmpty) ...[
              Container(height: 0.5, color: dividerCol),
              Theme(
                data: Theme.of(context).copyWith(
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(double.infinity, 44),
                      fixedSize: const Size.fromHeight(44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    if (actions.length == 2) {
                      return Row(
                        children: [
                          Expanded(
                            child: actions[0],
                          ),
                          Container(width: 0.5, height: 44, color: dividerCol),
                          Expanded(
                            child: actions[1],
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(actions.length, (index) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              actions[index],
                              if (index < actions.length - 1)
                                Container(height: 0.5, color: dividerCol),
                            ],
                          );
                        }),
                      );
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<T?> showAppAlertDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<Widget> actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) =>
        AppAlertDialog(title: title, content: content, actions: actions),
  );
}


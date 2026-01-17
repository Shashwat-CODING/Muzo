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
    return Dialog(
      backgroundColor: Colors.transparent, // Important for glass effect
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E1E1E),
        opacity: 0.7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
                child: content,
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            if (actions.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: actions.map((action) {
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: actions.indexOf(action) != actions.length - 1
                              ? BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                )
                              : BorderSide.none,
                        ),
                      ),
                      child: action,
                    ),
                  );
                }).toList(),
              ),
            if (actions.isEmpty) const SizedBox(height: 16),
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

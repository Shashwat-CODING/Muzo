import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/storage_service.dart';

class SyncProgressDialog extends ConsumerStatefulWidget {
  const SyncProgressDialog({super.key});

  @override
  ConsumerState<SyncProgressDialog> createState() => _SyncProgressDialogState();
}

class _SyncProgressDialogState extends ConsumerState<SyncProgressDialog> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  void _log(String message) {
    if (mounted) {
      setState(() {
        _logs.add(message);
      });
      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _startSync() async {
    final storage = ref.read(storageServiceProvider);

    try {
      _log('Starting sync...');

      if (storage.authToken == null) {
        _log('Error: Not logged in.');
        setState(() => _isSyncing = false);
        return;
      }

      _log('Fetching data from API...');
      await storage.refreshAll();
      _log('Sync Completed Successfully');

      // Auto-close after delay
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _log('Error: $e');
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerCol = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSyncing)
                        const CupertinoActivityIndicator(radius: 10)
                      else
                        const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Cloud Sync',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 0.8,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '> ${_logs[index]}',
                              style: const TextStyle(
                                color: Color(0xFF00FF00), // Terminal green
                                fontSize: 12,
                                fontFamily: 'Courier',
                                height: 1.3,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (!_isSyncing) ...[
                  Container(height: 0.5, color: dividerCol),
                  SizedBox(
                    height: 44,
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

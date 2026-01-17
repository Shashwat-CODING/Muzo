import 'dart:async';
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
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          if (_isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          const Text('Cloud Sync', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        height: 300,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: _logs.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '> ${_logs[index]}',
                style: const TextStyle(
                  color: Color(0xFF00FF00), // Terminal green
                  fontSize: 12,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        if (!_isSyncing)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
      ],
    );
  }
}

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final results = snapshot.data;
        final isOffline =
            results != null &&
            results.isNotEmpty &&
            !results.contains(ConnectivityResult.mobile) &&
            !results.contains(ConnectivityResult.wifi) &&
            !results.contains(ConnectivityResult.ethernet);

        if (!isOffline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          color: Colors.red.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, color: Theme.of(context).colorScheme.onSurface, size: 14),
              const SizedBox(width: 8),
              Text(
                'You are offline',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

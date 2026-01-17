import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          color: Colors.red.withOpacity(0.9),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 8),
              Text(
                'You are offline',
                style: GoogleFonts.outfit(
                  color: Colors.white,
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

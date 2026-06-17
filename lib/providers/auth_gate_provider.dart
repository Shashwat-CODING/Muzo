import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the user chose to continue as a guest.
/// When true, the AuthGate shows the main app even without an auth token.
final isGuestModeProvider = StateProvider<bool>((ref) => false);

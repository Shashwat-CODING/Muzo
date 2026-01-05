import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:muzo/screens/home_screen.dart';
import 'package:muzo/screens/auth_screen.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/services/notification_service.dart';

import 'package:muzo/widgets/main_layout.dart';
import 'package:muzo/providers/theme_provider.dart';
import 'package:muzo/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style for transparent nav bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  // Enable edge-to-edge
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final container = ProviderContainer();

  // Parallelize initialization
  await Future.wait([
    JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    ),
    container.read(storageServiceProvider).init(),
    NotificationService().init(),
  ]);

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Muzo',
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final authState = ref.watch(authServiceProvider);
            // Only show MainLayout (player/navbar) if authenticated
            if (authState.isAuthenticated) {
              return MainLayout(child: child!);
            }
            return child!;
          },
        );
      },
      home: Consumer(
        builder: (context, ref, _) {
          final authState = ref.watch(authServiceProvider);
          return authState.isAuthenticated ? const HomeScreen() : const AuthScreen();
        },
      ),
    );
  }
}

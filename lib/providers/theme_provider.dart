import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:google_fonts/google_fonts.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeData>((ref) {
  return ThemeNotifier(ref);
});

class ThemeNotifier extends StateNotifier<ThemeData> {
  final Ref ref;

  ThemeNotifier(this.ref) : super(_darkTheme) {
    _listenToMediaChanges();
  }

  static final _darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212), // Deep dark background
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFE50914), // Vibrant Red
      secondary: Color(0xFFFFFFFF),
      surface: Color(0xFF1E1E1E),
      background: Color(0xFF121212),
    ),
    // Use Outfit (Google Sans alternative)
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF121212).withValues(alpha: 0.8),
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1E1E1E).withValues(alpha: 0.8),
      indicatorColor: const Color(0xFFE50914).withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
  );

  void _listenToMediaChanges() {
    ref.listen(currentMediaItemProvider, (previous, next) async {
      if (next?.value != null && next!.value!.artUri != null) {
        await _updateThemeFromImage(next.value!.artUri.toString());
      } else {
        state = _darkTheme;
      }
    });
  }

  Future<void> _updateThemeFromImage(String imageUrl) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 20,
      );

      final dominantColor = paletteGenerator.dominantColor?.color ?? const Color(0xFFE50914);
      final vibrantColor = paletteGenerator.vibrantColor?.color ?? dominantColor;
      final mutedColor = paletteGenerator.mutedColor?.color ?? const Color(0xFF1E1E1E);
      final darkMutedColor = paletteGenerator.darkMutedColor?.color ?? const Color(0xFF121212);

      state = ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkMutedColor.withValues(alpha: 0.0), // Tinted background
        colorScheme: ColorScheme.dark(
          primary: vibrantColor,
          secondary: dominantColor,
          surface: mutedColor.withValues(alpha: 0.5),
          background: darkMutedColor,
          onPrimary: _getTextColorForBackground(vibrantColor),
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: darkMutedColor.withValues(alpha: 0.8),
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          titleTextStyle: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: vibrantColor,
          thumbColor: vibrantColor,
          inactiveTrackColor: vibrantColor.withValues(alpha: 0.3),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: vibrantColor,
        ),
      );
    } catch (e) {
      debugPrint('Error generating palette: $e');
      state = _darkTheme;
    }
  }

  Color _getTextColorForBackground(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}


import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/utils/app_colors.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/utils/app_colors.dart';

const String kDefaultFontFamily = 'Roboto';

// Extensions from the user's snippet
extension ColorWithHSL on Color {
  HSLColor get hsl => HSLColor.fromColor(this);

  Color withSaturation(double saturation) {
    return hsl.withSaturation(clampDouble(saturation, 0.0, 1.0)).toColor();
  }

  Color withLightness(double lightness) {
    return hsl.withLightness(clampDouble(lightness, 0.0, 1.0)).toColor();
  }

  Color withHue(double hue) {
    return hsl.withHue(clampDouble(hue, 0.0, 360.0)).toColor();
  }
}

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String toHex({bool leadingHashSign = true}) =>
      '${((a * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
      '${((r * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
      '${((g * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}'
      '${((b * 255.0).round() & 0xff).toRadixString(16).padLeft(2, '0')}';
}

// Current Palette Provider
final currentPaletteProvider = FutureProvider<PaletteGenerator?>((ref) async {
  final mediaItem = ref.watch(currentMediaItemProvider).value;

  if (mediaItem?.artUri == null) return null;

  try {
    final imageProvider = NetworkImage(mediaItem!.artUri.toString());
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      imageProvider,
      maximumColorCount: 20,
    );
    return paletteGenerator;
  } catch (e) {
    debugPrint('Error generating palette: $e');
    return null;
  }
});

// Stable Theme Color Provider to prevent flickering
class ThemeColorNotifier extends StateNotifier<Color?> {
  ThemeColorNotifier(this.ref) : super(null) {
    _init();
  }

  final Ref ref;

  void _init() {
    ref.listen(currentPaletteProvider, (previous, next) {
      next.whenData((palette) {
        if (palette != null) {
          final color =
              palette.dominantColor?.color ??
              palette.darkMutedColor?.color ??
              palette.darkVibrantColor?.color ??
              palette.lightMutedColor?.color ??
              palette.lightVibrantColor?.color;
          if (color != null) {
            state = color;
          }
        }
      });
    });
  }
}

final themeColorProvider = StateNotifierProvider<ThemeColorNotifier, Color?>((
  ref,
) {
  return ThemeColorNotifier(ref);
});

// Dynamic Color Scheme Provider from Device
final dynamicColorSchemeProvider = StateProvider<ColorScheme?>((ref) => null);

// Theme Logic Class (Helper)
class ThemeLogic {
  // Global Text Color Controls
  static const Color _darkPrimaryText = AppColors.primaryText;
  static const Color _darkSecondaryText = AppColors.secondaryText;
  static const Color _lightPrimaryText = Colors.black;
  static const Color _lightSecondaryText = Color(0xFF424242);

  static MaterialColor createMaterialColor(Color color) {
    List<double> strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.r.toInt(), g = color.g.toInt(), b = color.b.toInt();

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.toARGB32(), swatch);
  }

  static ThemeData createThemeData(
    MaterialColor? primarySwatch,
    ThemeType themeType, {
    MaterialColor? titleColorSwatch,
    Color? textColor,
    Brightness? systemBrightness,
    ColorScheme? dynamicColorScheme,
    String fontFamily = kDefaultFontFamily,
  }) {
    // Ensure the effective ColorScheme matches the target brightness
    final Brightness targetBrightness = themeType == ThemeType.light
        ? Brightness.light
        : Brightness.dark;

    ColorScheme? effectiveColorScheme = dynamicColorScheme;
    if (effectiveColorScheme != null &&
        effectiveColorScheme.brightness != targetBrightness) {
      effectiveColorScheme = ColorScheme.fromSeed(
        seedColor: effectiveColorScheme.primary,
        brightness: targetBrightness,
      );
    }

    if (themeType == ThemeType.dark && primarySwatch != null) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white.withValues(alpha: 0.002),
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: true,
        ),
      );

      final baseTheme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: primarySwatch[500],
        colorScheme: ColorScheme.fromSwatch(
          accentColor: primarySwatch[200],
          brightness: Brightness.dark,
          backgroundColor: primarySwatch[700],
          primarySwatch: primarySwatch,
        ),
        cardColor: primarySwatch[600],
        primaryColorLight: primarySwatch[400],
        primaryColorDark: primarySwatch[700],
        canvasColor: primarySwatch[700],
        scaffoldBackgroundColor: primarySwatch[900], // Darkest shade for bg
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: primarySwatch[600],
          modalBarrierColor: primarySwatch[400]?.withValues(alpha: 0.5),
        ),
        textTheme: TextTheme(
          titleLarge: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: _darkPrimaryText,
          ),
          titleMedium: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _darkPrimaryText,
          ),
          titleSmall: TextStyle(color: primarySwatch[100]),

          bodyMedium: const TextStyle(color: _darkSecondaryText),
          labelMedium: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 23,
            color: _darkPrimaryText,
          ),
          labelSmall: const TextStyle(
            fontSize: 15,
            color: _darkSecondaryText,
            letterSpacing: 0,
            fontWeight: FontWeight.bold,
          ),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          linearTrackColor: (primarySwatch[300])!.computeLuminance() > 0.3
              ? Colors.black54
              : Colors.white70,
          color: textColor,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: primarySwatch[700],
          selectedIconTheme: const IconThemeData(color: Colors.white),
          unselectedIconTheme: IconThemeData(color: primarySwatch[100]),
          selectedLabelTextStyle: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: primarySwatch[100],
            fontWeight: FontWeight.bold,
          ),
        ),
        sliderTheme: SliderThemeData(
          inactiveTrackColor: primarySwatch[300],
          activeTrackColor: textColor,
          valueIndicatorColor: primarySwatch[400],
          thumbColor: Colors.white,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: primarySwatch[200],
          selectionColor: primarySwatch[200],
          selectionHandleColor: primarySwatch[200],
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF5bc0be), // Static bluish color
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          },
        ),
        dialogTheme: DialogThemeData(backgroundColor: primarySwatch[700]),
        tabBarTheme: TabBarThemeData(indicatorColor: Colors.white),
      );
      return baseTheme.copyWith(
        textTheme: GoogleFonts.getTextTheme(fontFamily, baseTheme.textTheme),
      );
    } else if (themeType == ThemeType.light) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.black.withValues(alpha: 0.002),
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: true,
        ),
      );
      final baseTheme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        canvasColor: const Color(0xFFFFFFFF),
        primaryColor: effectiveColorScheme?.primary ?? const Color(0xFF1DB954),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        colorScheme:
            effectiveColorScheme?.copyWith(surface: const Color(0xFFFFFFFF)) ??
            const ColorScheme.light(
              primary: Color(0xFF1DB954),
              secondary: Color(0xFF888888),
              surface: Color(0xFFFFFFFF),
              onSurface: Colors.black,
            ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF1DB954),
          linearTrackColor: Colors.black12,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: _lightPrimaryText,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: _lightPrimaryText,
          ),
          labelMedium: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 23,
            color: _lightPrimaryText,
          ),
          labelSmall: TextStyle(
            fontSize: 15,
            color: _lightSecondaryText,
            letterSpacing: 0,
            fontWeight: FontWeight.bold,
          ),
          bodyMedium: TextStyle(color: _lightSecondaryText),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          modalBarrierColor: Colors.black26,
        ),
        sliderTheme: const SliderThemeData(
          thumbColor: Colors.black,
          activeTrackColor: Color(0xFF5bc0be),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusColor: Colors.black,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.black),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF5bc0be), // Static bluish color
          ),
        ),
      );
      return baseTheme.copyWith(
        textTheme: GoogleFonts.getTextTheme(fontFamily, baseTheme.textTheme),
      );
    } else {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white.withValues(alpha: 0.002),
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: true,
        ),
      );
      final baseTheme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        canvasColor: const Color(0xFF121212), // Spotify Dark Gray
        primaryColor: effectiveColorScheme?.primary ?? const Color(0xFFE2E2E2),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme:
            effectiveColorScheme?.copyWith(surface: const Color(0xFF121212)) ??
            const ColorScheme.dark(
              primary: Color(0xFFE2E2E2),
              secondary: Color(0xFF888888),
              surface: Color(0xFF181818), // Slightly elevated dark gray
              onSurface: Colors.white,
            ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFE2E2E2),
          linearTrackColor: Colors.white10,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: _darkPrimaryText,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: _darkPrimaryText,
          ),
          labelMedium: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 23,
            color: _darkPrimaryText,
          ),
          labelSmall: TextStyle(
            fontSize: 15,
            color: _darkSecondaryText,
            letterSpacing: 0,
            fontWeight: FontWeight.bold,
          ),
          bodyMedium: TextStyle(color: _darkSecondaryText),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1c2541),
          modalBarrierColor: Colors.black54,
        ),
        sliderTheme: const SliderThemeData(
          thumbColor: Colors.white,
          activeTrackColor: Color(0xFF5bc0be),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusColor: Colors.white,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF5bc0be), // Static bluish color
          ),
        ),
      );
      return baseTheme.copyWith(
        textTheme: GoogleFonts.getTextTheme(fontFamily, baseTheme.textTheme),
      );
    }
  }
}

// Dynamic Theme Provider
final themeProvider = Provider<ThemeData>((ref) {
  final settings = ref.watch(settingsProvider);
  final themeType = settings.themeType;
  final fontFamily = settings.appFontFamily;
  final dynamicColorScheme = ref.watch(dynamicColorSchemeProvider);

  // Resolve auto → system brightness
  final effectiveType = themeType == ThemeType.auto
      ? (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.light
            ? ThemeType.light
            : ThemeType.dark)
      : themeType;

  if (effectiveType == ThemeType.light) {
    return ThemeLogic.createThemeData(
      null,
      ThemeType.light,
      dynamicColorScheme: dynamicColorScheme,
      fontFamily: fontFamily,
    );
  } else {
    // Return static dark mode theme without album art color overriding
    return ThemeLogic.createThemeData(
      null,
      ThemeType.dark,
      dynamicColorScheme: dynamicColorScheme,
      fontFamily: fontFamily,
    );
  }
});

import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzo/providers/settings_provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/utils/app_colors.dart'; // Add import

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
      '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
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
    final int r = color.red, g = color.green, b = color.blue;

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
    return MaterialColor(color.value, swatch);
  }

  static ThemeData createThemeData(
    MaterialColor? primarySwatch,
    ThemeType themeType, {
    MaterialColor? titleColorSwatch,
    Color? textColor,
    Brightness? systemBrightness,
    ColorScheme? dynamicColorScheme,
  }) {
    if (themeType == ThemeType.dynamic && primarySwatch != null) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white.withOpacity(0.002),
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: true,
        ),
      );

      final baseTheme = ThemeData(
        useMaterial3: true,
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
          modalBarrierColor: primarySwatch[400]?.withOpacity(0.5),
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
          selectedLabelTextStyle: const TextStyle(
            color: Colors.white,
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
        textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme),
      );
    } else {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white.withOpacity(0.002),
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: true,
        ),
      );
      final baseTheme = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        canvasColor: Colors.black,
        primaryColor: dynamicColorScheme?.primary ?? const Color(0xFF3a506b),
        scaffoldBackgroundColor:
            dynamicColorScheme?.surface ??
            const Color(0xFF0b132b), // Deep bluish black
        colorScheme:
            dynamicColorScheme ??
            const ColorScheme.dark(
              primary: Color(0xFF5bc0be), // Cyan/Blue accent
              secondary: Color(0xFF3a506b),
              surface: Color(0xFF1c2541),
              onSurface: Colors.white,
            ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF5bc0be),
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
        textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme),
      );
    }
  }
}

// Dynamic Theme Provider
final themeProvider = Provider<ThemeData>((ref) {
  final settings = ref.watch(settingsProvider);
  final themeType = settings.themeType;
  final dynamicColorScheme = ref.watch(dynamicColorSchemeProvider);

  if (themeType == ThemeType.dynamic) {
    // Watch stable color
    final activeColor = ref.watch(themeColorProvider);

    if (activeColor != null) {
      Color primaryColor = activeColor;
      // Custom Luminance Logic
      if (activeColor.computeLuminance() > 0.10) {
        primaryColor = activeColor.withLightness(0.10);
      }
      final primarySwatch = ThemeLogic.createMaterialColor(primaryColor);

      return ThemeLogic.createThemeData(primarySwatch, ThemeType.dynamic);
    }
    // Fallback to dark with dynamic color if available
    return ThemeLogic.createThemeData(
      null,
      ThemeType.dark,
      dynamicColorScheme: dynamicColorScheme,
    );
  } else {
    // Static themes (Now only Dark)
    return ThemeLogic.createThemeData(
      null,
      ThemeType.dark,
      dynamicColorScheme: dynamicColorScheme,
    );
  }
});

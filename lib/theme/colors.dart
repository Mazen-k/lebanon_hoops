import 'package:flutter/material.dart';

class AppColors {
  // Named Colors
  static const Color background = Color(0xFFFAF8FF);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color inverseOnSurface = Color(0xFFEDF0FF);
  static const Color inversePrimary = Color(0xFFFFB4AB);
  static const Color inverseSurface = Color(0xFF2A303F);
  static const Color onBackground = Color(0xFF151B2A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  static const Color onPrimaryFixed = Color(0xFF410002);
  static const Color onPrimaryFixedVariant = Color(0xFF93000D);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF5A647C);
  static const Color onSecondaryFixed = Color(0xFF101B30);
  static const Color onSecondaryFixedVariant = Color(0xFF3C475D);
  static const Color onSurface = Color(0xFF151B2A);
  static const Color onSurfaceVariant = Color(0xFF5E3F3C);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFFFCFCFC);
  static const Color onTertiaryFixed = Color(0xFF1A1C1C);
  static const Color onTertiaryFixedVariant = Color(0xFF454747);
  static const Color outline = Color(0xFF936E6A);
  static const Color outlineVariant = Color(0xFFE8BCB7);
  static const Color primary = Color(0xFFBB0013);
  static const Color primaryContainer = Color(0xFFE71520);
  static const Color primaryFixed = Color(0xFFFFDAD6);
  static const Color primaryFixedDim = Color(0xFFFFB4AB);
  static const Color secondary = Color(0xFF545E76);
  static const Color secondaryContainer = Color(0xFFD7E2FF);
  static const Color secondaryFixed = Color(0xFFD7E2FF);
  static const Color secondaryFixedDim = Color(0xFFBBC6E2);
  static const Color surface = Color(0xFFFAF8FF);
  static const Color surfaceBright = Color(0xFFFAF8FF);
  static const Color surfaceContainer = Color(0xFFE9EDFF);
  static const Color surfaceContainerHigh = Color(0xFFE2E8FC);
  static const Color surfaceContainerHighest = Color(0xFFDDE2F6);
  static const Color surfaceContainerLow = Color(0xFFF2F3FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFD4D9EE);
  static const Color surfaceTint = Color(0xFFC00014);
  static const Color surfaceVariant = Color(0xFFDDE2F6);
  static const Color tertiary = Color(0xFF5A5C5C);
  static const Color tertiaryContainer = Color(0xFF737575);
  static const Color tertiaryFixed = Color(0xFFE2E2E2);
  static const Color tertiaryFixedDim = Color(0xFFC6C6C7);

  // Gradient definitions
  static const LinearGradient signatureGradient = LinearGradient(
    colors: [primary, primaryContainer],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight, // approximated 135 deg
  );
  
  // Material 3 ColorScheme mapping
  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceVariant,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    inverseSurface: inverseSurface,
    onInverseSurface: inverseOnSurface,
    inversePrimary: inversePrimary,
  );
}

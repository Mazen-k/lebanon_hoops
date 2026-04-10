import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.lexend(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -1.14),
      displayMedium: GoogleFonts.lexend(fontSize: 45, fontWeight: FontWeight.w400, letterSpacing: -0.9),
      displaySmall: GoogleFonts.lexend(fontSize: 36, fontWeight: FontWeight.w400, letterSpacing: -0.72),
      headlineLarge: GoogleFonts.lexend(fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: -0.64),
      headlineMedium: GoogleFonts.lexend(fontSize: 28, fontWeight: FontWeight.w400, letterSpacing: -0.56),
      headlineSmall: GoogleFonts.lexend(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: -0.48),
      titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
      titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      labelLarge: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      labelMedium: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      labelSmall: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
    );
  }
}

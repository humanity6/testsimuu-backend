import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const darkBlue = Color(0xFF015055);
  static const limeYellow = Color(0xFFE1F369);
  static const darkGrey = Color(0xFF222222);
  static const white = Color(0xFFFFFFFF);
  
  // Additional shades
  static const lightGrey = Color(0xFFF5F5F5);
  static const mediumGrey = Color(0xFFAAAAAA);
  static final darkBlueLighter = Color(0xFF026D73);
  static final darkBlueTransparent = Color(0xFF015055).withOpacity(0.08);
  
  // Missing colors that were referenced in the code
  static const blue = Color(0xFF1976D2);
  static const green = Color(0xFF4CAF50);
  static const orange = Color(0xFFFF9800);
  static const red = Color(0xFFF44336);
  static const purple = Color(0xFF9C27B0);
  static const lightBlue = Color(0xFF03A9F4);
  static const lightYellow = Color(0xFFFFFAC8);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.darkBlue,
      scaffoldBackgroundColor: AppColors.limeYellow,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.darkBlue,
        onPrimary: AppColors.white,
        secondary: AppColors.limeYellow,
        onSecondary: AppColors.darkGrey,
        background: AppColors.limeYellow,
        onBackground: AppColors.darkGrey,
        surface: AppColors.white,
        onSurface: AppColors.darkGrey,
        error: Colors.redAccent,
        onError: AppColors.white,
      ),
      
      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.limeYellow,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.darkBlue),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.darkBlue,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        color: AppColors.white,
        elevation: 4,
        shadowColor: AppColors.darkBlueTransparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkBlue,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkBlue,
          side: const BorderSide(color: AppColors.darkBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Theme
      textTheme: TextTheme(
        // Headlines
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.darkBlue,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.darkBlue,
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.darkBlue,
        ),
        
        // Body
        bodyLarge: GoogleFonts.urbanist(
          fontSize: 18,
          color: AppColors.darkGrey,
        ),
        bodyMedium: GoogleFonts.urbanist(
          fontSize: 16,
          color: AppColors.darkGrey,
        ),
        bodySmall: GoogleFonts.urbanist(
          fontSize: 14,
          color: AppColors.darkGrey,
        ),
        
        // Labels
        labelLarge: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkBlue,
        ),
        labelMedium: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.darkBlue,
        ),
        labelSmall: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.darkBlue,
        ),
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.darkBlue, width: 1.5),
        ),
        hintStyle: GoogleFonts.urbanist(
          color: AppColors.mediumGrey,
        ),
        prefixIconColor: AppColors.darkBlue,
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkBlue,
        selectedItemColor: AppColors.limeYellow,
        unselectedItemColor: AppColors.white,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      
      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.darkBlue;
          }
          return AppColors.white;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      
      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.darkBlue,
        inactiveTrackColor: AppColors.darkBlueTransparent,
        thumbColor: AppColors.darkBlue,
        overlayColor: AppColors.darkBlueTransparent,
      ),
    );
  }
} 
import 'package:stock_arena/core/app_material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColorTheme {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color card;
  final Color outline;
  final Color border;
  final Color muted;
  final Color subtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const AppColorTheme({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.card,
    required this.outline,
    required this.border,
    required this.muted,
    required this.subtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  static const dark = AppColorTheme(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceAlt: AppColors.darkSurfaceAlt,
    card: AppColors.darkCard,
    outline: AppColors.darkOutline,
    border: AppColors.darkBorder,
    muted: AppColors.darkMuted,
    subtle: AppColors.darkSubtle,
    textPrimary: AppColors.darkText,
    textSecondary: Color(0xFF9E9E9E),
    textMuted: AppColors.darkMuted,
  );

  static const light = AppColorTheme(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceAlt: AppColors.lightSurfaceAlt,
    card: AppColors.lightCard,
    outline: AppColors.lightOutline,
    border: AppColors.lightBorder,
    muted: AppColors.lightMuted,
    subtle: AppColors.lightSubtle,
    textPrimary: AppColors.lightText,
    textSecondary: Color(0xFF475569),
    textMuted: AppColors.lightMuted,
  );
}

class AppColors {
  // ── Brand (identical across themes) ────────────────────────────────────────
  static const primary     = Color(0xFF00D09C);   // teal accent (buy / profit)
  static const primaryDark = Color(0xFF0A2E2A);   // teal tint background

  // ── Semantic (identical across themes) ─────────────────────────────────────
  static const profit      = Color(0xFF0ECB81);   // green  (Binance green)
  static const loss        = Color(0xFFF6465D);   // red    (Binance red)
  static const warning     = Color(0xFFF0B90B);   // amber  (Binance yellow)

  // ── Explicit Dark Palette Constants ────────────────────────────────────────
  static const darkBackground = Color(0xFF000000);   // True pitch OLED black
  static const darkSurface    = Color(0xFF121418);   // Elevated card / input background
  static const darkSurfaceAlt = Color(0xFF0D0F12);   // Slightly raised surface
  static const darkCard       = Color(0xFF1E2329);   // Card background
  static const darkOutline    = Color(0xFF1E2329);   // Borders & dividers
  static const darkBorder     = Color(0xFF2B3139);   // Secondary borders
  static const darkMuted      = Color(0xFF4B5563);   // Tertiary text
  static const darkSubtle     = Color(0xFF6B7280);   // Secondary text
  static const darkText       = Color(0xFFFFFFFF);   // Primary text

  // ── Explicit Light Palette Constants ───────────────────────────────────────
  static const lightBackground = Color(0xFFF4F6F9);  // Clean crypto light grey
  static const lightSurface    = Color(0xFFFFFFFF);  // Pure white card / sheet
  static const lightSurfaceAlt = Color(0xFFEEF2F6);  // Slightly shaded input/chip
  static const lightCard       = Color(0xFFFFFFFF);  // Card background
  static const lightOutline    = Color(0xFFE2E8F0);  // Crisp light divider/border
  static const lightBorder     = Color(0xFFCBD5E1);  // Secondary border
  static const lightMuted      = Color(0xFF94A3B8);  // Tertiary text
  static const lightSubtle     = Color(0xFF64748B);  // Secondary text
  static const lightText       = Color(0xFF0F172A);  // Primary text (rich slate)

  // ── Dynamic Theme State ────────────────────────────────────────────────────
  static bool isDarkMode = true;

  // ── Constant Grey Tokens (safe in const expressions across dark & light) ───
  static const muted  = Color(0xFF4B5563);   // Tertiary text
  static const subtle = Color(0xFF6B7280);   // Secondary text

  // ── Dynamic Palette Accessors ──────────────────────────────────────────────
  static Color get background => isDarkMode ? darkBackground : lightBackground;
  static Color get surface    => isDarkMode ? darkSurface : lightSurface;
  static Color get surfaceAlt => isDarkMode ? darkSurfaceAlt : lightSurfaceAlt;
  static Color get card       => isDarkMode ? darkCard : lightCard;
  static Color get outline    => isDarkMode ? darkOutline : lightOutline;
  static Color get border     => isDarkMode ? darkBorder : lightBorder;
  static Color get textPrimary   => isDarkMode ? darkText : lightText;
  static Color get textSecondary => isDarkMode ? const Color(0xFFB0B3B8) : const Color(0xFF475569);
  static Color get textMuted     => isDarkMode ? darkMuted : lightMuted;

  // Context-aware theme access
  static AppColorTheme of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColorTheme.dark : AppColorTheme.light;
  }
}

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData(
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: Colors.black,
        secondary: AppColors.primary,
        onSecondary: Colors.black,
        surface: AppColors.darkSurface,
        onSurface: Colors.white,
        error: AppColors.loss,
        outline: AppColors.darkOutline,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      useMaterial3: true,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return base.copyWith(
      textTheme: textTheme,

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // ── Bottom Navigation Bar ──────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkBackground,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        elevation: 0,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 22);
          }
          return const IconThemeData(color: Color(0xFF6B7280), size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 10.0,
              letterSpacing: -0.3,
            );
          }
          return GoogleFonts.inter(
            color: const Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
            fontSize: 10.0,
            letterSpacing: -0.3,
          );
        }),
      ),

      // ── Card ───────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.darkOutline, width: 1),
        ),
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.darkOutline,
        thickness: 1,
        space: 1,
      ),

      // ── TextField / Input ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFF4B5563),
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.inter(
          color: const Color(0xFF6B7280),
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.loss),
        ),
      ),

      // ── Chip ───────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.primaryDark,
        disabledColor: AppColors.darkSurface,
        labelStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
        secondaryLabelStyle: GoogleFonts.inter(color: AppColors.primary, fontSize: 12),
        side: const BorderSide(color: AppColors.darkOutline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // ── Filled / ElevatedButton ────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: const Size(double.infinity, 44),
        ),
      ),

      // ── Outlined Button ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: AppColors.darkOutline),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: const Size(double.infinity, 44),
        ),
      ),

      // ── Text Button ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),

      // ── Slider ────────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.darkOutline,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),

      // ── Progress indicator ─────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.darkOutline,
      ),

      // ── BottomSheet ────────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        dragHandleColor: Color(0xFF4B5563),
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.darkOutline),
        ),
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.darkOutline),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          color: const Color(0xFF6B7280),
          fontSize: 12,
        ),
      ),

      // ── Icon ──────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: Color(0xFF6B7280)),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primary,
        onSecondary: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        error: AppColors.loss,
        outline: AppColors.lightOutline,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      useMaterial3: true,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.lightText,
      displayColor: AppColors.lightText,
    );

    return base.copyWith(
      textTheme: textTheme,

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.lightText,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightText),
      ),

      // ── Bottom Navigation Bar ──────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        elevation: 3,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 22);
          }
          return const IconThemeData(color: AppColors.lightSubtle, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 10.0,
              letterSpacing: -0.3,
            );
          }
          return GoogleFonts.inter(
            color: AppColors.lightSubtle,
            fontWeight: FontWeight.w500,
            fontSize: 10.0,
            letterSpacing: -0.3,
          );
        }),
      ),

      // ── Card ───────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.lightOutline, width: 1),
        ),
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.lightOutline,
        thickness: 1,
        space: 1,
      ),

      // ── TextField / Input ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: GoogleFonts.inter(
          color: AppColors.lightMuted,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.inter(
          color: AppColors.lightSubtle,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.lightOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.loss),
        ),
      ),

      // ── Chip ───────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceAlt,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        disabledColor: AppColors.lightSurfaceAlt,
        labelStyle: GoogleFonts.inter(color: AppColors.lightText, fontSize: 12),
        secondaryLabelStyle: GoogleFonts.inter(color: AppColors.primary, fontSize: 12),
        side: const BorderSide(color: AppColors.lightOutline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // ── Filled / ElevatedButton ────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: const Size(double.infinity, 44),
        ),
      ),

      // ── Outlined Button ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightText,
          side: const BorderSide(color: AppColors.lightOutline),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: const Size(double.infinity, 44),
        ),
      ),

      // ── Text Button ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),

      // ── Slider ────────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.lightOutline,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),

      // ── Progress indicator ─────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.lightOutline,
      ),

      // ── BottomSheet ────────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        dragHandleColor: AppColors.lightBorder,
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.lightOutline),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.lightText,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          color: AppColors.lightSubtle,
          fontSize: 12,
        ),
      ),

      // ── Icon ──────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: AppColors.lightSubtle),
    );
  }
}

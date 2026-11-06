import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aura_colors.dart';

abstract final class AuraTheme {
  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: AuraColors.electric,
      onPrimary: Colors.white,
      secondary: AuraColors.ember,
      onSecondary: Colors.white,
      error: AuraColors.critical,
      onError: Colors.white,
      surface: AuraColors.midnight,
      onSurface: AuraColors.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AuraColors.deepNavy,
      fontFamily: _defaultFamily,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AuraColors.textPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AuraColors.textPrimary),
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: AuraColors.textPrimary,
            displayColor: AuraColors.textPrimary,
          )
          .copyWith(
            headlineLarge: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.1,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
            bodySmall: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AuraColors.textSecondary,
            ),
            labelLarge: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AuraColors.textPrimary,
          side: const BorderSide(color: AuraColors.glassStroke),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AuraColors.cyan),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        hintStyle: const TextStyle(color: AuraColors.textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _inputBorder(AuraColors.glassStroke),
        enabledBorder: _inputBorder(AuraColors.glassStroke),
        focusedBorder: _inputBorder(AuraColors.cyan, width: 1.6),
        errorBorder: _inputBorder(AuraColors.critical),
        focusedErrorBorder: _inputBorder(AuraColors.critical, width: 1.6),
      ),
      dividerTheme: const DividerThemeData(
        color: AuraColors.glassStroke,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AuraColors.royal,
        contentTextStyle: const TextStyle(color: AuraColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AuraColors.midnight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AuraColors.midnight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AuraColors.midnight.withValues(alpha: 0.92),
        indicatorColor: AuraColors.electric.withValues(alpha: 0.22),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Keluarga font bawaan platform — tidak butuh unduhan aset.
  static String? get _defaultFamily => null;
}

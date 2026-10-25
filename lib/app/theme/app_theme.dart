import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens. Neutral greys plus one cool accent; no red, nothing taken
/// from the official FGV / Metrovalencia branding.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
  });

  final Color background;
  final Color surface;
  final Color border;
  final Color text;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;

  static const light = AppTokens(
    background: Color(0xFFF5F5F3),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE3E3DF),
    text: Color(0xFF111214),
    muted: Color(0xFF666A71),
    faint: Color(0xFFA9ACB1),
    accent: Color(0xFF2B59E8),
    accentSoft: Color(0xFFE6ECFD),
    onAccent: Color(0xFFFFFFFF),
  );

  static const dark = AppTokens(
    background: Color(0xFF0D0E10),
    surface: Color(0xFF16171A),
    border: Color(0xFF26282C),
    text: Color(0xFFF1F1EF),
    muted: Color(0xFF9A9DA3),
    faint: Color(0xFF5A5D63),
    accent: Color(0xFF7D9BFF),
    accentSoft: Color(0xFF1D2540),
    onAccent: Color(0xFF0D0E10),
  );

  static AppTokens of(BuildContext context) => Theme.of(context).extension<AppTokens>()!;

  @override
  AppTokens copyWith({
    Color? background,
    Color? surface,
    Color? border,
    Color? text,
    Color? muted,
    Color? faint,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
  }) =>
      AppTokens(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        border: border ?? this.border,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        faint: faint ?? this.faint,
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        onAccent: onAccent ?? this.onAccent,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

/// Tabular figures keep times aligned in lists and stop digits jumping.
const tabular = [FontFeature.tabularFigures()];

const radius = 20.0;

class AppTheme {
  static ThemeData light() => _build(AppTokens.light, Brightness.light);

  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  /// Transparent system bars (the app draws edge to edge) with icons that
  /// contrast with the background.
  static SystemUiOverlayStyle overlay(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: brightness,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    );
  }

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.onAccent,
      secondary: t.accent,
      onSecondary: t.onAccent,
      error: const Color(0xFFD64545),
      onError: const Color(0xFFFFFFFF),
      surface: t.surface,
      onSurface: t.text,
      surfaceContainerHighest: t.background,
      outline: t.border,
      outlineVariant: t.border,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final text = base.textTheme.apply(bodyColor: t.text, displayColor: t.text);

    return base.copyWith(
      scaffoldBackgroundColor: t.background,
      extensions: [t],
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlay(brightness),
        titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: t.text),
      ),
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        hintStyle: TextStyle(color: t.faint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.border)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.border)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.accent, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.text,
          foregroundColor: t.background,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: t.accent, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: t.surface,
          foregroundColor: t.muted,
          selectedBackgroundColor: t.text,
          selectedForegroundColor: t.background,
          side: BorderSide(color: t.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: t.faint,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.text,
        contentTextStyle: TextStyle(color: t.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.accent),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.accentSoft,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? t.text : t.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? t.accent : t.muted),
        ),
      ),
      badgeTheme: BadgeThemeData(backgroundColor: t.accent, textColor: t.onAccent),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: t.surface,
        headerForegroundColor: t.text,
      ),
    );
  }
}

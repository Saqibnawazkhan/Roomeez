import 'package:flutter/material.dart';

/// Extra semantic colors not covered by [ColorScheme].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.positive,
    required this.negative,
    required this.fund,
    required this.fundContainer,
    required this.onFundContainer,
    required this.muted,
    required this.canvas,
  });

  /// Money in your favour.
  final Color positive;

  /// Money you owe.
  final Color negative;

  /// Group fund / contributions. Deliberately distinct from expense colors.
  final Color fund;
  final Color fundContainer;
  final Color onFundContainer;
  final Color muted;
  final Color canvas;

  static const AppColors light = AppColors(
    positive: Color(0xFF15803D),
    negative: Color(0xFFB42318),
    fund: Color(0xFF4F46E5),
    fundContainer: Color(0xFFEEF0FF),
    onFundContainer: Color(0xFF2E2A85),
    muted: Color(0xFF667085),
    canvas: Color(0xFFF5F7F8),
  );

  static const AppColors dark = AppColors(
    positive: Color(0xFF4ADE80),
    negative: Color(0xFFF97066),
    fund: Color(0xFFA5B4FC),
    fundContainer: Color(0xFF26264A),
    onFundContainer: Color(0xFFE0E3FF),
    muted: Color(0xFF98A2B3),
    canvas: Color(0xFF0F1415),
  );

  @override
  AppColors copyWith({
    Color? positive,
    Color? negative,
    Color? fund,
    Color? fundContainer,
    Color? onFundContainer,
    Color? muted,
    Color? canvas,
  }) {
    return AppColors(
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      fund: fund ?? this.fund,
      fundContainer: fundContainer ?? this.fundContainer,
      onFundContainer: onFundContainer ?? this.onFundContainer,
      muted: muted ?? this.muted,
      canvas: canvas ?? this.canvas,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      fund: Color.lerp(fund, other.fund, t)!,
      fundContainer: Color.lerp(fundContainer, other.fundContainer, t)!,
      onFundContainer: Color.lerp(onFundContainer, other.onFundContainer, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

abstract final class AppTheme {
  static const Color seed = Color(0xFF0F766E);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final extra = isDark ? AppColors.dark : AppColors.light;
    final surface = isDark ? scheme.surfaceContainer : Colors.white;
    final outline = scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.7);
    final radius12 = BorderRadius.circular(12);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);

    return base.copyWith(
      scaffoldBackgroundColor: extra.canvas,
      extensions: [extra],
      appBarTheme: AppBarTheme(
        backgroundColor: extra.canvas,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: outline),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: isDark ? scheme.surfaceContainerLow : Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    );
  }
}

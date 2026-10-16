import 'package:flutter/material.dart';

import '../../core/neu/neu.dart';

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
    positive: Color(0xFF27936A),
    negative: Color(0xFFD45B55),
    fund: Color(0xFF6A78E8),
    fundContainer: Color(0xFFE6EBF1),
    onFundContainer: Color(0xFF3B4555),
    muted: Color(0xFF8A95A6),
    canvas: Color(0xFFE6EBF1),
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
  static const Color seed = Color(0xFF2FAFAD);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Neumorphic theme: one soft surface color, Poppins, teal accent.
  /// Shadows come from the widgets in core/neu/neu.dart.
  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final neu = isDark ? NeuPalette.dark : NeuPalette.light;
    final extra = (isDark ? AppColors.dark : AppColors.light).copyWith(
      canvas: neu.base,
      muted: neu.muted,
      fundContainer: neu.base,
    );
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
      primary: neu.accent,
      onPrimary: Colors.white,
      surface: neu.base,
      onSurface: neu.text,
      onSurfaceVariant: neu.muted,
      surfaceContainerLowest: neu.base,
      surfaceContainerLow: neu.base,
      surfaceContainer: neu.base,
      surfaceContainerHigh: neu.base,
      surfaceContainerHighest: neu.base,
      outlineVariant: neu.shade.withValues(alpha: 0.35),
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: neu.base,
    );
    final radius = BorderRadius.circular(18);

    return base.copyWith(
      extensions: [extra, neu],
      textTheme: base.textTheme.apply(bodyColor: neu.text, displayColor: neu.text),
      appBarTheme: AppBarTheme(
        backgroundColor: neu.base,
        foregroundColor: neu.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600, color: neu.text),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: neu.base,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      // Fields are wrapped in NeuTextFormField, which draws the inset.
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        labelStyle: TextStyle(color: neu.muted),
        floatingLabelStyle: TextStyle(color: neu.accent),
        hintStyle: TextStyle(color: neu.muted.withValues(alpha: 0.7)),
        prefixIconColor: neu.muted,
        suffixIconColor: neu.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neu.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neu.accent,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: neu.shade.withValues(alpha: 0.5)),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neu.accent,
          textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
      ),
      iconTheme: IconThemeData(color: neu.muted),
      dividerTheme: DividerThemeData(color: neu.shade.withValues(alpha: 0.25), space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: neu.text,
        contentTextStyle: TextStyle(fontFamily: 'Poppins', color: neu.base),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: neu.base,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: neu.shade,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: neu.base,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: neu.base,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      datePickerTheme: DatePickerThemeData(backgroundColor: neu.base, surfaceTintColor: Colors.transparent),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: neu.accent),
      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    );
  }
}

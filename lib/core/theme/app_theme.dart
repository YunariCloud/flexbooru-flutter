import 'package:flutter/material.dart';

class AppTheme {
  static const List<String> fontFallback = [
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Hiragino Sans GB',
    'Noto Sans SC',
    'Segoe UI',
    'sans-serif',
  ];

  static ThemeData lightTheme(Color primaryColor, {LinearGradient? gradient}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      brightness: Brightness.light,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
    );
    return base.copyWith(
      extensions: [
        GradientThemeExtension(
          gradient: gradient,
          isGradient: gradient != null,
        ),
      ],
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.primary),
        actionsIconTheme: IconThemeData(color: colorScheme.primary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        selectedColor: colorScheme.primary,
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
        circularTrackColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.primary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        indicatorColor: colorScheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return null;
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.35),
        selectionHandleColor: colorScheme.primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        actionTextColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return null;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        prefixIconColor: colorScheme.primary,
      ),
      textTheme: base.textTheme.apply(
        fontFamilyFallback: fontFallback,
      ),
    );
  }

  static ThemeData darkTheme(
    Color primaryColor, {
    bool amoled = false,
    LinearGradient? gradient,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      brightness: Brightness.dark,
      surface: amoled ? Colors.black : const Color(0xFF1E1E1E),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      extensions: [
        GradientThemeExtension(
          gradient: gradient,
          isGradient: gradient != null,
        ),
      ],
      scaffoldBackgroundColor: amoled ? Colors.black : const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: amoled ? Colors.black : const Color(0xFF1E1E1E),
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.primary),
        actionsIconTheme: IconThemeData(color: colorScheme.primary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        selectedColor: colorScheme.primary,
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      cardTheme: CardThemeData(
        color: amoled ? const Color(0xFF121212) : const Color(0xFF242424),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
        circularTrackColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.primary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        indicatorColor: colorScheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return null;
        }),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.35),
        selectionHandleColor: colorScheme.primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        actionTextColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return null;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        prefixIconColor: colorScheme.primary,
      ),
      textTheme: base.textTheme.apply(
        fontFamilyFallback: fontFallback,
      ),
    );
  }
}

class GradientThemeExtension extends ThemeExtension<GradientThemeExtension> {
  final LinearGradient? gradient;
  final bool isGradient;

  const GradientThemeExtension({
    this.gradient,
    this.isGradient = false,
  });

  @override
  ThemeExtension<GradientThemeExtension> copyWith({
    LinearGradient? gradient,
    bool? isGradient,
  }) {
    return GradientThemeExtension(
      gradient: gradient ?? this.gradient,
      isGradient: isGradient ?? this.isGradient,
    );
  }

  @override
  ThemeExtension<GradientThemeExtension> lerp(
    covariant ThemeExtension<GradientThemeExtension>? other,
    double t,
  ) {
    if (other is! GradientThemeExtension) return this;
    return GradientThemeExtension(
      gradient: LinearGradient.lerp(gradient, other.gradient, t),
      isGradient: t < 0.5 ? isGradient : other.isGradient,
    );
  }
}

extension GradientThemeX on ThemeData {
  LinearGradient? get primaryGradient =>
      extension<GradientThemeExtension>()?.gradient;
  bool get hasGradient =>
      extension<GradientThemeExtension>()?.isGradient ?? false;
}

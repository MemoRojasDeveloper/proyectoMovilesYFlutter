/// Tema visual de Banco Santander (paleta corporativa).
///
/// - Color primario: rojo Santander `#EC0000`.
/// - Soporta modo claro y oscuro **automático** (sigue al sistema) y
///   **manual** mediante `ThemeController` (botón en la AppBar).
/// - Variantes de rojo diseñadas para mantener contraste WCAG AA en
///   ambos fondos.
///
/// Uso:
/// ```dart
/// final controller = ThemeController();
/// await controller.load();   // una vez al arrancar
/// runApp(MyApp(controller: controller));
/// ```
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paleta corporativa de Santander (constantes puras).
class SantanderColors {
  SantanderColors._();

  // Rojos
  static const Color red = Color(0xFFEC0000);
  static const Color redDark = Color(0xFFB30000);
  static const Color redLight = Color(0xFFFF4D4D);

  // Neutros (modo claro)
  static const Color black = Color(0xFF333333);
  static const Color graySurface = Color(0xFFF4F4F4);
  static const Color grayBorder = Color(0xFFCCCCCC);
  static const Color grayText = Color(0xFF666666);

  // Modo oscuro
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkText = Color(0xFFE6E6E6);
}

/// Tokens semánticos — úsalos en vez de `Color(0xFF…)` en widgets.
class AppColors {
  const AppColors._({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.error,
  });

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color background;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color error;

  static const AppColors light = AppColors._(
    primary: SantanderColors.red,
    primaryDark: SantanderColors.redDark,
    primaryLight: SantanderColors.redLight,
    background: Colors.white,
    surface: SantanderColors.graySurface,
    border: SantanderColors.grayBorder,
    textPrimary: SantanderColors.black,
    textSecondary: SantanderColors.grayText,
    error: Color(0xFFD32F2F),
  );

  static const AppColors dark = AppColors._(
    primary: SantanderColors.redLight,
    primaryDark: SantanderColors.red,
    primaryLight: Color(0xFFFF8080),
    background: SantanderColors.darkSurface,
    surface: SantanderColors.darkCard,
    border: Color(0xFF333333),
    textPrimary: SantanderColors.darkText,
    textSecondary: Color(0xFFB0B0B0),
    error: Color(0xFFEF9A9A),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

/// Modo de tema elegido por el usuario.
enum AppThemeMode { system, light, dark }

extension AppThemeModeLabel on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.system:
        return 'Tema del sistema';
      case AppThemeMode.light:
        return 'Tema claro';
      case AppThemeMode.dark:
        return 'Tema oscuro';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.system:
        return Icons.brightness_auto_outlined;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }
}

/// `ThemeData` para modo claro.
ThemeData buildLightTheme() => _baseTheme(
      scheme: ColorScheme.fromSeed(
        seedColor: SantanderColors.red,
        brightness: Brightness.light,
      ),
      tokens: AppColors.light,
    );

/// `ThemeData` para modo oscuro.
ThemeData buildDarkTheme() => _baseTheme(
      scheme: ColorScheme.fromSeed(
        seedColor: SantanderColors.redLight,
        brightness: Brightness.dark,
      ),
      tokens: AppColors.dark,
    );

ThemeData _baseTheme({
  required ColorScheme scheme,
  required AppColors tokens,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: scheme.brightness,
    scaffoldBackgroundColor: tokens.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: SantanderColors.red,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 18,
        letterSpacing: 0.3,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        disabledBackgroundColor: tokens.border,
        disabledForegroundColor: tokens.textSecondary,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: tokens.primary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.primary,
        side: BorderSide(color: tokens.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.error, width: 2),
      ),
      labelStyle: TextStyle(color: tokens.textSecondary),
      hintStyle: TextStyle(color: tokens.textSecondary),
      errorStyle: TextStyle(color: tokens.error, fontSize: 12),
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: tokens.border,
    iconTheme: IconThemeData(color: tokens.textSecondary),
  );
}

/// Controlador del tema. Persiste la elección del usuario y cicla entre
/// modos. Por defecto sigue al sistema.
class ThemeController extends ChangeNotifier {
  ThemeController({AppThemeMode initial = AppThemeMode.system}) : _mode = initial;

  static const _storageKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get mode => _mode;

  ThemeMode get materialThemeMode {
    switch (_mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  /// Carga el modo guardado. Llamar una sola vez al arrancar.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      _mode = AppThemeMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => AppThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setMode(AppThemeMode value) async {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value.name);
  }

  /// Cicla: `system → light → dark → system`.
  Future<void> cycle() async {
    const order = [
      AppThemeMode.system,
      AppThemeMode.light,
      AppThemeMode.dark,
    ];
    final i = order.indexOf(_mode);
    final next = order[(i + 1) % order.length];
    await setMode(next);
  }
}

/// IconButton lista para poner en cualquier AppBar que cambie el tema al
/// pulsar. Cicla por los 3 modos.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: controller.mode.label,
      icon: Icon(controller.mode.icon),
      onPressed: controller.cycle,
    );
  }
}

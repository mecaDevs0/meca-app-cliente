import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  bool _isDarkMode = true; // Tema escuro como padrão

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // Tema Escuro (Verde MECA como cor principal)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00C977), // Verde MECA
        primary: const Color(0xFF00C977),
        secondary: const Color(0xFF3B82F6),
        surface: const Color(0xFF1A1A1A),
        background: const Color(0xFF0A0A0A),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF0A0A0A),
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1A1A),
        selectedItemColor: Color(0xFF00C977),
        unselectedItemColor: Color(0xFF8B8B8B),
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: const CardTheme(
        color: Color(0xFF1A1A1A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF444444)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF444444)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF00C977), width: 2),
        ),
        labelStyle: TextStyle(color: Color(0xFF8B8B8B)),
        hintStyle: TextStyle(color: Color(0xFF8B8B8B)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF8B8B8B),
          fontSize: 14,
        ),
      ),
    );
  }

  // Tema Claro (Verde MECA como cor principal)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00C977),
        primary: const Color(0xFF00C977),
        secondary: const Color(0xFF3B82F6),
        surface: Colors.white,
        background: const Color(0xFFFAFAFA),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF00C977),
        unselectedItemColor: Color(0xFF8B8B8B),
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: const CardTheme(
        color: Colors.white,
        elevation: 2,
        shadowColor: Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF00C977), width: 2),
        ),
        labelStyle: TextStyle(color: Color(0xFF666666)),
        hintStyle: TextStyle(color: Color(0xFF999999)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C977),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF666666),
          fontSize: 14,
        ),
      ),
    );
  }

  // Cores específicas para cada tema
  static Color getBackgroundColor(bool isDark) {
    return isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);
  }

  static Color getSurfaceColor(bool isDark) {
    return isDark ? const Color(0xFF1A1A1A) : Colors.white;
  }

  static Color getCardColor(bool isDark) {
    return isDark ? const Color(0xFF1A1A1A) : Colors.white;
  }

  static Color getTextColor(bool isDark) {
    return isDark ? Colors.white : const Color(0xFF1A1A1A);
  }

  static Color getSecondaryTextColor(bool isDark) {
    return isDark ? const Color(0xFF8B8B8B) : const Color(0xFF666666);
  }

  static Color getBorderColor(bool isDark) {
    return isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0);
  }

  static Color getInputColor(bool isDark) {
    return isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
  }

  // Inicializar tema salvo
  Future<void> initializeTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? true; // Padrão: tema escuro
    notifyListeners();
  }

  // Alternar tema
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _saveTheme();
    notifyListeners();
  }

  // Salvar tema
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }

  // Definir tema específico
  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    await _saveTheme();
    notifyListeners();
  }
}

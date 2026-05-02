import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppState extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  AppState() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  ThemeData get currentTheme {
    return _isDarkMode ? _buildDarkTheme() : _buildLightTheme();
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFDFDFD),
      cardColor: Colors.white,
      dividerColor: Colors.black12,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        secondary: Color(0xFF475569),
        surface: Color(0xFFF8F9FA),
        onSurface: Colors.black,
      ),
      textTheme: ThemeData.light().textTheme.apply(bodyColor: Colors.black, displayColor: Colors.black),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      cardColor: const Color(0xFF0F172A),
      canvasColor: const Color(0xFF0F172A),
      dialogBackgroundColor: const Color(0xFF0F172A),
      dividerColor: Colors.white12,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: Color(0xFFE2E8F0),
        surface: Color(0xFF0A0A0A),
        onSurface: Colors.white,
      ),
      textTheme: ThemeData.dark().textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }
}

class OfflineCache {
  static late Box _cacheBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _cacheBox = await Hive.openBox('offline_cache');
  }

  static void save(String key, dynamic value) {
    _cacheBox.put(key, value);
  }

  static dynamic get(String key) {
    return _cacheBox.get(key);
  }
}

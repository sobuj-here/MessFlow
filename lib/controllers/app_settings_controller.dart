import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class AppSettingsController extends ChangeNotifier {
  static final AppSettingsController instance = AppSettingsController._();
  AppSettingsController._();

  ThemeMode _themeMode = ThemeMode.light;
  String _language = 'en';

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  String get language => _language;
  bool get isBangla => _language == 'bn';

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _language = prefs.getString('app_language') ?? 'en';
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
    notifyListeners();
  }

  // 🌟 ভাষা পরিবর্তনের সময় EasyLocalization-এর লোকাল্লে আপডেট করে দেওয়া হলো
  Future<void> changeLanguage(BuildContext context, String langCode) async {
    _language = langCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', langCode);

    // EasyLocalization এর ভাষা ইনস্ট্যান্ট পরিবর্তন করার জন্য
    await context.setLocale(Locale(langCode));

    notifyListeners();
  }
}
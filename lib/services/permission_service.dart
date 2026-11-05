import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPermissionService {
  static const String _kInitialPermissionKey = 'has_requested_initial_permissions_v1';

  /// অ্যাপ ওপেনের পর প্রথমবার ইউজারকে দরকারি সব পারমিশনের ডায়ালগ দেখানোর মেথড
  static Future<void> checkAndRequestInitialPermissions(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool alreadyRequested = prefs.getBool(_kInitialPermissionKey) ?? false;

      if (!alreadyRequested) {
        await prefs.setBool(_kInitialPermissionKey, true);

        // ১. সিস্টেম নোটিফিকেশন পারমিশন (অ্যান্ড্রয়েড ১৩+ এর জন্য অত্যন্ত জরুরি)
        await Permission.notification.request();

        // ২. ক্যামেরা ও স্টোরেজ/গ্যালারি পারমিশন
        if (Platform.isAndroid) {
          await [
            Permission.camera,
            Permission.storage,
            Permission.photos,
          ].request();
        } else if (Platform.isIOS) {
          await [
            Permission.camera,
            Permission.photos,
          ].request();
        }
      }
    } catch (_) {}
  }
}

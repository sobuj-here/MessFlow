import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPermissionService {
  static const String _kInitialPermissionKey = 'has_requested_initial_permissions_v1';

  /// Checks and requests runtime notification and storage permissions.
  static Future<void> checkAndRequestInitialPermissions(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool alreadyRequested = prefs.getBool(_kInitialPermissionKey) ?? false;

      if (!alreadyRequested) {
        await prefs.setBool(_kInitialPermissionKey, true);

        await Permission.notification.request();

        if (Platform.isAndroid) {
          try {
            if (await Permission.ignoreBatteryOptimizations.isDenied) {
              await Permission.ignoreBatteryOptimizations.request();
            }
          } catch (_) {}

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

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  /// যেকোনো জায়গা থেকে সহজে নোটিফিকেশন পাঠানোর সিঙ্গেল ফাংশন
  static Future<void> send({
    required String messId,
    required String title,
    required String body,
    required String type,
    String? targetUid,     // নির্দিষ্ট কোনো মেম্বারের জন্য হলে
    String? targetRole,    // 'manager' বা 'admin' এর জন্য হলে
  }) async {
    if (messId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('messes')
          .doc(messId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'targetUid': targetUid,
        'targetRole': targetRole,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [],
      });
    } catch (e) {
      // Background fail safe
    }
  }
}
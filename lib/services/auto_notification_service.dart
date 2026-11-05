import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart'; // flutterLocalNotificationsPlugin ব্যবহারের জন্য

class AutoNotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static bool _isListening = false;
  static String? _currentMessId;

  // 🌟 ডুপ্লিকেট নোটিফিকেশন আসা স্থায়ীভাবে বন্ধ করতে ট্র্যাকিং সেট
  static final Set<String> _shownNotificationIds = {};
  static final Set<String> _shownChatIds = {};
  static bool _isFirstNotificationSnap = true;
  static bool _isFirstChatSnap = true;

  // 🌟 পরপর দ্রুত একই নোটিফিকেশন দুবার সেন্ড হওয়া বন্ধ করতে ডিবউন্স
  static String? _lastSentSig;
  static int _lastSentTime = 0;

  static void startListening(String messId) {
    if ((_isListening && _currentMessId == messId) || messId.isEmpty) return;
    _isListening = true;
    _currentMessId = messId;
    _isFirstNotificationSnap = true;
    _isFirstChatSnap = true;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final messRef = _db.collection('messes').doc(messId);
    final DateTime sessionStartTime = DateTime.now();

    // 🌟 নতুন নোটিফিকেশন আসলে ডিভাইসের স্ট্যাটাসবারে সিস্টেম নোটিফিকেশন দেখানোর অপটিমাইজড লিসেনার
    messRef
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .listen((snap) {
      if (_isFirstNotificationSnap) {
        _isFirstNotificationSnap = false;
        for (var doc in snap.docs) {
          _shownNotificationIds.add(doc.id);
        }
        return;
      }

      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final docId = change.doc.id;
          if (_shownNotificationIds.contains(docId)) continue;
          _shownNotificationIds.add(docId);

          final data = change.doc.data();
          if (data == null) continue;

          final Timestamp? createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null &&
              createdAt.toDate().isBefore(sessionStartTime.subtract(const Duration(minutes: 1)))) {
            continue;
          }

          final List readBy = data['readBy'] ?? [];
          final String senderUid = data['senderUid'] ?? '';

          // যদি বর্তমান ইউজার ইতিমধ্যে পড়ে না থাকে এবং নিজে না পাঠিয়ে থাকে
          if (currentUid != null && !readBy.contains(currentUid) && senderUid != currentUid) {
            _showLocalNotification(
              title: data['title'] ?? 'MessFlow Notification',
              body: data['body'] ?? '',
              type: data['type'] ?? 'notice',
            );
          }
        }
      }
    });

    // 🌟 মেসেজের জন্য বাইরে সিস্টেম নোটিফিকেশন লিসেনার
    messRef
        .collection('group_chats')
        .orderBy('timestamp', descending: true)
        .limit(25)
        .snapshots()
        .listen((snap) {
      if (_isFirstChatSnap) {
        _isFirstChatSnap = false;
        for (var doc in snap.docs) {
          _shownChatIds.add(doc.id);
        }
        return;
      }

      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final docId = change.doc.id;
          if (_shownChatIds.contains(docId)) continue;
          _shownChatIds.add(docId);

          final data = change.doc.data();
          if (data == null) continue;

          final Timestamp? timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null &&
              timestamp.toDate().isBefore(sessionStartTime.subtract(const Duration(minutes: 1)))) {
            continue;
          }

          final String senderId = data['senderId'] ?? '';
          if (currentUid != null && senderId.isNotEmpty && senderId != currentUid) {
            final String senderName = data['senderName'] ?? 'Member';
            final String text = data['text'] ?? '';
            final String mediaType = data['mediaType'] ?? '';
            final String body = text.isNotEmpty
                ? text
                : (mediaType.isNotEmpty ? 'Sent an attachment ($mediaType)' : 'New message');

            _showLocalNotification(
              title: '$senderName (Group Chat)',
              body: body,
              type: 'chat',
            );
          }
        }
      }
    });
  }

  // 🌟 যে কোনো স্ক্রিন থেকে সরাসরি সেন্ট্রাল নোটিফিকেশন তৈরি করার মেথড (ডুপ্লিকেট প্রতিরোধসহ)
  static Future<void> sendNotification({
    required String messId,
    required String title,
    required String body,
    required String type,
    String? senderUid,
  }) async {
    if (messId.isEmpty) return;

    // একই নোটিফিকেশন পরপর ২ সেকেন্ডের মধ্যে এলে ইগনোর করা হবে
    final sig = '$messId|$title|$body|$type';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastSentSig == sig && (nowMs - _lastSentTime) < 2000) {
      return;
    }
    _lastSentSig = sig;
    _lastSentTime = nowMs;

    try {
      final uid = senderUid ?? FirebaseAuth.instance.currentUser?.uid;
      await _db
          .collection('messes')
          .doc(messId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'senderUid': uid ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': uid != null ? [uid] : [],
      });
    } catch (_) {}
  }

  // 🌟 ডিভাইসের স্ট্যাটাসবারে রিয়েল নোটিফিকেশন প্রদর্শন করার মেথড
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String type,
  }) async {
    String channelId = 'mess_notice_channel';
    String channelName = 'Mess Notices';

    if (type.contains('chat')) {
      channelId = 'mess_chat_channel';
      channelName = 'Chat Messages';
    } else if (type.contains('meal')) {
      channelId = 'mess_meal_channel';
      channelName = 'Meal Updates';
    } else if (type.contains('payment') || type.contains('bazaar')) {
      channelId = 'mess_payment_channel';
      channelName = 'Payments & Bazaar';
    } else if (type.contains('duty') || type.contains('assign')) {
      channelId = 'mess_assign_channel';
      channelName = 'Bazaar Assign & Duties';
    } else if (type.contains('rent')) {
      channelId = 'mess_rent_channel';
      channelName = 'Room Rent & Utilities';
    } else if (type.contains('approval') || type.contains('join') || type.contains('member')) {
      channelId = 'mess_approval_channel';
      channelName = 'Account Approvals';
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final int notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    try {
      await flutterLocalNotificationsPlugin.show(
        notifId,
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (_) {}
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../main.dart';
import '../screens/group_chat_screen.dart';
import '../screens/assign_bazaar_screen.dart';
import '../screens/add_bazaar_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/meal_chart_screen.dart';
import '../screens/room_rent_sheet_screen.dart';
import '../screens/notifications_screen.dart';

class AutoNotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static bool _isListening = false;
  static String? _currentMessId;
  static String? currentUserRole;

  
  static bool isChatScreenActive = false;

  
  static final Set<String> _shownNotificationIds = {};
  static final Set<String> _shownChatIds = {};
  static bool _isFirstNotificationSnap = true;
  static bool _isFirstChatSnap = true;

  
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

    
    try {
      FirebaseMessaging.instance.subscribeToTopic('mess_$messId');
      if (currentUid != null) {
        FirebaseMessaging.instance.subscribeToTopic('user_$currentUid');
      }
    } catch (_) {}

    
    if (currentUid != null) {
      messRef.collection('members').doc(currentUid).get().then((doc) {
        if (doc.exists) {
          currentUserRole = doc.data()?['role']?.toString().toLowerCase();
        }
      }).catchError((_) {});

      _db.collection('users').doc(currentUid).get().then((doc) {
        if (doc.exists && currentUserRole == null) {
          currentUserRole = doc.data()?['role']?.toString().toLowerCase();
        }
      }).catchError((_) {});
    }

    
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
          final String? targetUid = data['targetUid']?.toString();
          final String? targetRole = data['targetRole']?.toString().toLowerCase();

          
          if (currentUid != null && senderUid.isNotEmpty && senderUid == currentUid) {
            continue;
          }

          
          if (currentUid != null && readBy.contains(currentUid)) {
            continue;
          }

          
          if (targetUid != null && targetUid.isNotEmpty && targetUid != currentUid) {
            continue;
          }

          
          if (targetRole != null && targetRole.isNotEmpty) {
            final role = currentUserRole ?? 'member';
            if (targetRole == 'manager' && !(role == 'manager' || role == 'admin')) {
              continue;
            }
            if (targetRole == 'admin' && role != 'admin') {
              continue;
            }
          }

          _showLocalNotification(
            title: data['title'] ?? 'MessFlow Notification',
            body: data['body'] ?? '',
            type: data['type'] ?? 'notice',
            messId: messId,
          );
        }
      }
    });

    
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

          
          if (isChatScreenActive) {
            continue;
          }

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
              messId: messId,
            );
          }
        }
      }
    });
  }

  
  static Future<void> sendNotification({
    required String messId,
    required String title,
    required String body,
    required String type,
    String? senderUid,
    String? targetUid,
    String? targetRole,
  }) async {
    if (messId.isEmpty) return;

    final sig = '$messId|$title|$body|$type|$targetUid|$targetRole';
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
        'targetUid': targetUid,
        'targetRole': targetRole,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': uid != null ? [uid] : [],
        'clearedBy': [],
      });
    } catch (_) {}
  }

  
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String type,
    String? messId,
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
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final int notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final String payload = '${messId ?? _currentMessId ?? ""}|$type';

    try {
      await flutterLocalNotificationsPlugin.show(
        notifId,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (_) {}
  }

  
  static void handleNotificationTap(String messId, String type, NavigatorState? navigator) {
    if (navigator == null || messId.isEmpty) return;

    Widget targetScreen;
    if (type.contains('chat')) {
      targetScreen = GroupChatScreen(messId: messId);
    } else if (type.contains('duty') || type.contains('assign')) {
      targetScreen = AssignBazaarScreen(messId: messId, isManager: false);
    } else if (type.contains('bazaar')) {
      targetScreen = AddBazaarScreen(messId: messId, isAdmin: false, isManager: false);
    } else if (type.contains('payment')) {
      targetScreen = PaymentScreen(messId: messId, isAdmin: false, isManager: false);
    } else if (type.contains('meal')) {
      targetScreen = FullMonthMealChartScreen(messId: messId);
    } else if (type.contains('rent')) {
      targetScreen = RoomRentSheetScreen(messId: messId, isAdmin: false);
    } else {
      targetScreen = NotificationsScreen(messId: messId);
    }

    navigator.push(MaterialPageRoute(builder: (_) => targetScreen));
  }

  
  static Future<void> showTestNotification() async {
    await _showLocalNotification(
      title: '🔔 MessFlow Test Notification',
      body: 'Your notification and alert system is working properly.',
      type: 'notice',
    );
  }
}

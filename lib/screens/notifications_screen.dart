import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // 🌟 সময় ফরম্যাট করার জন্য
import 'add_bazaar_screen.dart';
import 'payment_screen.dart';
import 'meal_chart_screen.dart';
import 'assign_bazaar_screen.dart';
import 'expense_sheet_screen.dart';
import 'room_rent_sheet_screen.dart';
import 'settings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String messId;
  final bool isAdmin;
  final bool isManager;

  const NotificationsScreen({
    super.key,
    required this.messId,
    this.isAdmin = false,
    this.isManager = false,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _markAsRead(String docId, List<dynamic> readByList) async {
    if (currentUid == null || readByList.contains(currentUid)) return;

    await FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('notifications')
        .doc(docId)
        .update({
      'readBy': FieldValue.arrayUnion([currentUid]),
    });
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    if (currentUid == null || docs.isEmpty) return;

    final unreadDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final List readBy = data['readBy'] ?? [];
      return !readBy.contains(currentUid);
    }).toList();

    if (unreadDocs.isEmpty) return;

    for (int i = 0; i < unreadDocs.length; i += 400) {
      final chunk = unreadDocs.sublist(i, (i + 400 > unreadDocs.length) ? unreadDocs.length : i + 400);
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in chunk) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([currentUid]),
        });
      }
      await batch.commit();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read!')),
      );
    }
  }

  // 🌟 একক নোটিফিকেশন ডিলিট করার ফাংশন
  Future<void> _deleteNotification(String docId) async {
    if (currentUid == null) return;
    try {
      if (widget.isAdmin) {
        await FirebaseFirestore.instance
            .collection('messes')
            .doc(widget.messId)
            .collection('notifications')
            .doc(docId)
            .delete();
      } else {
        await FirebaseFirestore.instance
            .collection('messes')
            .doc(widget.messId)
            .collection('notifications')
            .doc(docId)
            .update({
          'clearedBy': FieldValue.arrayUnion([currentUid]),
        });
      }
    } catch (_) {
      try {
        await FirebaseFirestore.instance
            .collection('messes')
            .doc(widget.messId)
            .collection('notifications')
            .doc(docId)
            .update({
          'clearedBy': FieldValue.arrayUnion([currentUid]),
        });
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted successfully')),
      );
    }
  }

  // 🌟 সমস্ত নোটিফিকেশন একবারে ক্লিয়ার বা ডিলিট করার ফাংশন
  Future<void> _clearAllNotifications(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty || currentUid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (widget.isAdmin) {
          for (int i = 0; i < docs.length; i += 400) {
            final chunk = docs.sublist(i, (i + 400 > docs.length) ? docs.length : i + 400);
            final batch = FirebaseFirestore.instance.batch();
            for (var doc in chunk) {
              batch.delete(doc.reference);
            }
            await batch.commit();
          }
        } else {
          for (int i = 0; i < docs.length; i += 400) {
            final chunk = docs.sublist(i, (i + 400 > docs.length) ? docs.length : i + 400);
            final batch = FirebaseFirestore.instance.batch();
            for (var doc in chunk) {
              batch.update(doc.reference, {
                'clearedBy': FieldValue.arrayUnion([currentUid]),
              });
            }
            await batch.commit();
          }
        }
      } catch (e) {
        try {
          for (int i = 0; i < docs.length; i += 400) {
            final chunk = docs.sublist(i, (i + 400 > docs.length) ? docs.length : i + 400);
            final batch = FirebaseFirestore.instance.batch();
            for (var doc in chunk) {
              batch.update(doc.reference, {
                'clearedBy': FieldValue.arrayUnion([currentUid]),
              });
            }
            await batch.commit();
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared!')),
        );
      }
    }
  }

  // সঠিক নোটিফিকেশন টাইপ অনুযায়ী নিখুঁত স্ক্রিন নেভিগেশন লজিক
  void _navigateToScreen(String type) {
    Widget targetScreen;

    if (type.contains('duty') || type.contains('bazaar_duty') || type.contains('assign')) {
      targetScreen = AssignBazaarScreen(
        messId: widget.messId,
        isManager: widget.isManager,
      );
    } else if (type.contains('bazaar_add') || type.contains('bazaar')) {
      targetScreen = AddBazaarScreen(
        messId: widget.messId,
        isAdmin: widget.isAdmin,
        isManager: widget.isManager,
      );
    } else if (type.contains('payment')) {
      targetScreen = PaymentScreen(
        messId: widget.messId,
        isAdmin: widget.isAdmin,
        isManager: widget.isManager,
      );
    } else if (type.contains('meal')) {
      targetScreen = FullMonthMealChartScreen(messId: widget.messId);
    } else if (type.contains('shared_cost') || type.contains('expense')) {
      targetScreen = ExpenseSheetScreen(messId: widget.messId);
    } else if (type.contains('rent') || type.contains('bill')) {
      targetScreen = RoomRentSheetScreen(
        messId: widget.messId,
        isAdmin: widget.isAdmin,
      );
    } else {
      targetScreen = SettingsScreen(messId: widget.messId);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 🌟 AppBar-এর ভেতরে সরাসরি 'Clear All' বাটন যুক্ত করা হলো
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('messes')
                .doc(widget.messId)
                .collection('notifications')
                .snapshots(),
            builder: (context, snapshot) {
              final rawDocs = snapshot.data?.docs ?? [];
              final docs = rawDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final List clearedBy = data['clearedBy'] ?? [];
                return currentUid != null && !clearedBy.contains(currentUid);
              }).toList();
              if (docs.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                onPressed: () => _clearAllNotifications(docs),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('messes')
            .doc(widget.messId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)));
          }

          final rawDocs = snapshot.data?.docs ?? [];
          final docs = rawDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final List clearedBy = data['clearedBy'] ?? [];
            return currentUid != null && !clearedBy.contains(currentUid);
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No notifications yet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          int unreadCount = 0;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final List readBy = data['readBy'] ?? [];
            if (!readBy.contains(currentUid)) {
              unreadCount++;
            }
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      unreadCount > 0 ? '$unreadCount Unread' : 'All caught up',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: unreadCount > 0 ? const Color(0xFF1B5E20) : Colors.grey,
                      ),
                    ),
                    if (unreadCount > 0)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1B5E20),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Mark all as read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _markAllAsRead(docs),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Notification';
                    final body = data['body'] ?? '';
                    final type = data['type'] ?? '';
                    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                    final List readBy = data['readBy'] ?? [];
                    final bool isRead = readBy.contains(currentUid);

                    // 🌟 নোটিফিকেশনের সময় ফরম্যাট করা (যেমন: 10:30 AM অথবা 25 Sep, 04:15 PM)
                    String timeFormatted = '';
                    if (createdAt != null) {
                      final DateTime dateTime = createdAt.toDate();
                      final now = DateTime.now();
                      if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
                        timeFormatted = DateFormat('hh:mm a').format(dateTime); // আজকের হলে শুধু সময়
                      } else {
                        timeFormatted = DateFormat('dd MMM, hh:mm a').format(dateTime); // অন্যদিনের হলে তারিখ ও সময়
                      }
                    }

                    IconData iconData = Icons.notifications_rounded;
                    Color iconColor = const Color(0xFF1B5E20);

                    if (type.contains('payment')) {
                      iconData = Icons.account_balance_wallet_rounded;
                      iconColor = Colors.blue;
                    } else if (type.contains('bazaar_add')) {
                      iconData = Icons.shopping_basket_rounded;
                      iconColor = Colors.teal;
                    } else if (type.contains('duty') || type.contains('assign')) {
                      iconData = Icons.assignment_ind_rounded;
                      iconColor = Colors.indigo;
                    } else if (type.contains('meal')) {
                      iconData = Icons.restaurant_rounded;
                      iconColor = Colors.orange;
                    } else if (type.contains('shared_cost')) {
                      iconData = Icons.receipt_long_rounded;
                      iconColor = Colors.purple;
                    } else if (type.contains('issue')) {
                      iconData = Icons.warning_rounded;
                      iconColor = Colors.redAccent;
                    }

                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        _deleteNotification(doc.id);
                      },
                      child: InkWell(
                        onTap: () async {
                          await _markAsRead(doc.id, readBy);
                          if (context.mounted) {
                            _navigateToScreen(type); 
                          }
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Notification'),
                              content: const Text('Do you want to delete this notification?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _deleteNotification(doc.id);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          color: isRead ? Colors.transparent : const Color(0xFFE8F5E9).withOpacity(0.35),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: iconColor.withOpacity(0.12),
                                child: Icon(iconData, color: iconColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                              fontSize: 14,
                                              color: isRead ? Colors.black87 : Colors.black,
                                            ),
                                          ),
                                        ),
                                        // 🌟 এখানে নোটিফিকেশনের সময় শো করছে
                                        if (timeFormatted.isNotEmpty)
                                          Text(
                                            timeFormatted,
                                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      body,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isRead ? Colors.grey.shade600 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isRead) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1B5E20),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
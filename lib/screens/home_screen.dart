import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

import 'add_bazaar_screen.dart';
import 'meal_screen.dart';
import 'payment_screen.dart';
import 'assign_bazaar_screen.dart';
import 'notifications_screen.dart';
import 'group_chat_screen.dart';
import 'settings_screen.dart';
import 'room_rent_sheet_screen.dart';
import 'shared_expense_screen.dart';
import 'live_mess_sheet_screen.dart';
import 'manager_balance_widget.dart';
import 'join_mess_screen.dart';
import 'mess_notice_board_widget.dart';
import '../services/auto_notification_service.dart'; 
import '../services/permission_service.dart';

class HomeScreen extends StatefulWidget {
  final String messId;

  const HomeScreen({
    super.key,
    required this.messId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    AutoNotificationService.startListening(widget.messId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppPermissionService.checkAndRequestInitialPermissions(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messId.trim().isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'No Active Mess Found!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please join or create a mess to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const JoinMessScreen()),
                    );
                  },
                  child: const Text('Join / Create Mess', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined, size: 23),
          tooltip: 'Mess Settings'.tr(),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(messId: widget.messId))),
        ),
        title: const Text('MessFlow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 🌟 Chat Icon with Unread Badge Count (Optimized with limit)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('messes')
                .doc(widget.messId)
                .collection('group_chats')
                .orderBy('timestamp', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, chatSnapshot) {
              int unreadChatCount = 0;
              if (chatSnapshot.hasData && currentUid != null) {
                for (var doc in chatSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final List readBy = data['readByUids'] ?? [];
                  if (!readBy.contains(currentUid)) {
                    unreadChatCount++;
                  }
                }
              }
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.forum_rounded, size: 20),
                      tooltip: 'Mess Group Chat'.tr(),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GroupChatScreen(messId: widget.messId))),
                    ),
                  ),
                  if (unreadChatCount > 0)
                    Positioned(
                      top: 8,
                      right: 4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(
                          unreadChatCount > 9 ? '9+' : '$unreadChatCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('messes')
                .doc(widget.messId)
                .collection('notifications')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, notificationSnapshot) {
              int unread = 0;
              if (notificationSnapshot.hasData) {
                for (final doc in notificationSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final List<dynamic> readBy = data['readBy'] is List ? List<dynamic>.from(data['readBy']) : [];
                  final List<dynamic> clearedBy = data['clearedBy'] is List ? List<dynamic>.from(data['clearedBy']) : [];
                  if (currentUid != null && !clearedBy.contains(currentUid) && !readBy.contains(currentUid)) {
                    unread++;
                  }
                }
              }
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, size: 24),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsScreen(messId: widget.messId))),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 7,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(unread > 9 ? '9+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('messes').doc(widget.messId).snapshots(),
        builder: (context, messSnapshot) {
          if (messSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)));
          }
          if (!messSnapshot.hasData || !messSnapshot.data!.exists) {
            return Center(child: const Text('Mess not found.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)).tr());
          }

          final messData = messSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final String messName = messData['name']?.toString() ?? 'My Mess';
          final String inviteCode = messData['inviteCode']?.toString() ?? widget.messId;
          final String adminUid = messData['adminUid']?.toString() ?? '';
          final String managerUid = messData['managerUid']?.toString() ?? '';
          final String messNote = messData['messNote']?.toString() ?? 'No notice available right now.';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('messId', isEqualTo: widget.messId).snapshots(),
            builder: (context, userSnapshot) {
              final members = userSnapshot.data?.docs ?? [];

              final currentUserDoc = members.where((m) => m.id == currentUid).toList();
              final userData = currentUserDoc.isNotEmpty ? (currentUserDoc.first.data() as Map<String, dynamic>) : {};
              
              final bool isAdmin = (currentUid != null && currentUid == adminUid) || (userData['role'] == 'admin');
              final bool isManager = (currentUid != null && currentUid == managerUid) || (userData['role'] == 'manager');

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopMessCard(messName, isAdmin, isManager, inviteCode),
                    const SizedBox(height: 14),
                    RepaintBoundary(child: _buildLiveMealRateCard()),
                    const SizedBox(height: 14),
                    RepaintBoundary(child: ManagerBalanceWidget(messId: widget.messId)),
                    const SizedBox(height: 14),

                    MessNoticeBoardWidget(
                      messId: widget.messId,
                      currentNote: messNote,
                      isAdmin: isAdmin,
                      isManager: isManager,
                    ),

                    const SizedBox(height: 18),
                    
                    const Text('Daily Operations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)).tr(),
                    const SizedBox(height: 10),
                    
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        _buildOperationCard(
                          icon: Icons.meeting_room_rounded,
                          title: 'Room Rent'.tr(),
                          subtitle: 'View monthly rent'.tr(),
                          iconColor: Colors.indigo,
                          bgColor: Colors.indigo.shade50,
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => RoomRentSheetScreen(
                                messId: widget.messId,
                                isAdmin: isAdmin || isManager,
                              ),
                            ),
                          ),
                        ),
                        _buildOperationCard(
                          icon: Icons.call_split_rounded,
                          title: 'Extra Expense'.tr(),
                          subtitle: 'View extra bills'.tr(),
                          iconColor: Colors.brown,
                          bgColor: Colors.brown.shade50,
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => SharedExpenseScreen(
                                messId: widget.messId,
                                isManager: isManager || isAdmin,
                              ),
                            ),
                          ),
                        ),
                        _buildOperationCard(
                          icon: Icons.shopping_basket_rounded,
                          title: 'Bazaar Expenses'.tr(),
                          subtitle: 'Daily shopping list'.tr(),
                          iconColor: const Color(0xFF1B5E20),
                          bgColor: const Color(0xFFE8F5E9),
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => AddBazaarScreen(
                                messId: widget.messId,
                                isAdmin: isAdmin,
                                isManager: isManager,
                              ),
                            ),
                          ),
                        ),
                        _buildOperationCard(
                          icon: Icons.checklist_rounded,
                          title: 'Bazaar Duty'.tr(),
                          subtitle: 'View & accept duties'.tr(),
                          iconColor: Colors.teal,
                          bgColor: Colors.teal.shade50,
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => AssignBazaarScreen(
                                messId: widget.messId,
                                isManager: isManager || isAdmin,
                              ),
                            ),
                          ),
                        ),
                        _buildOperationCard(
                          icon: Icons.restaurant_rounded,
                          title: 'Daily Meals'.tr(),
                          subtitle: 'Daily meal entries'.tr(),
                          iconColor: Colors.orange.shade800,
                          bgColor: Colors.orange.shade50,
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => MealScreen(
                                messId: widget.messId,
                                isManager: isManager || isAdmin,
                              ),
                            ),
                          ),
                        ),
                        _buildOperationCard(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Payments & Funds'.tr(),
                          subtitle: 'Send deposits & rent'.tr(),
                          iconColor: const Color(0xFF1976D2),
                          bgColor: Colors.blue.shade50,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentScreen(messId: widget.messId, isAdmin: isAdmin, isManager: isManager))),
                        ),
                        _buildOperationCard(
                          icon: Icons.receipt_long_rounded,
                          title: 'Live Mess Sheet'.tr(),
                          subtitle: 'Balances and dues'.tr(),
                          iconColor: Colors.deepPurple,
                          bgColor: Colors.deepPurple.shade50,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MessHomeDashboardScreen(messId: widget.messId))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTopMessCard(String messName, bool isAdmin, bool isManager, String inviteCode) {
    final String roleName = isAdmin ? 'ADMIN' : (isManager ? 'MANAGER' : 'MEMBER');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(messName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Text('Logged in as: ', style: TextStyle(color: Colors.green, fontSize: 12)).tr(),
                        Text(roleName, style: TextStyle(color: Colors.green.shade100, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Invite Code copied to clipboard!').tr()));
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        const Text('Invite Code: ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)).tr(),
                        Text(inviteCode, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Text('Tap to Copy', style: TextStyle(color: Colors.white60, fontSize: 11)).tr(),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMealRateCard() {
    final now = DateTime.now();
    final String currentMonthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messes')
          .doc(widget.messId)
          .collection('bazaars')
          .snapshots(),
      builder: (context, bazaarSnapshot) {
        double totalBazaar = 0.0;
        if (bazaarSnapshot.hasData) {
          for (final doc in bazaarSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final status = (data['status']?.toString() ?? 'approved').toLowerCase().trim();
            if (status == 'approved') {
              final amount = data['amount'];
              if (amount is num) {
                totalBazaar += amount.toDouble();
              } else if (amount is String) {
                totalBazaar += double.tryParse(amount.replaceAll(',', '').trim()) ?? 0.0;
              }
            }
          }
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('messes')
              .doc(widget.messId)
              .collection('meals')
              .snapshots(),
          builder: (context, mealSnapshot) {
            double totalMeals = 0.0;
            if (mealSnapshot.hasData) {
              for (final doc in mealSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final count = data['count'] ?? data['mealCount'];
                if (count is num) {
                  totalMeals += count.toDouble();
                } else if (count is String) {
                  totalMeals += double.tryParse(count.replaceAll(',', '').trim()) ?? 0.0;
                }
              }
            }
            final bool isLiveRateLoading = bazaarSnapshot.connectionState == ConnectionState.waiting || mealSnapshot.connectionState == ConnectionState.waiting;
            final double mealRate = totalMeals > 0 ? totalBazaar / totalMeals : 0.0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.trending_up_rounded, color: Color(0xFF1B5E20), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Live Meal Rate', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)).tr(),
                        const SizedBox(height: 2),
                        Text(
                          isLiveRateLoading ? '...' : '৳ ${mealRate.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 32, width: 1, color: Theme.of(context).dividerColor, margin: const EdgeInsets.symmetric(horizontal: 8)),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('Total Bazaar: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)).tr(),
                            Text(
                              isLiveRateLoading ? '...' : '৳${totalBazaar.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text('Total Meals: ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)).tr(),
                            Text(
                              isLiveRateLoading ? '...' : '${totalMeals.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOperationCard({required IconData icon, required String title, required String subtitle, required Color iconColor, required Color bgColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 18, backgroundColor: bgColor, child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
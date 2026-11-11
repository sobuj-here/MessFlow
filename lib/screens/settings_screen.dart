import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../services/auto_notification_service.dart';
import '../controllers/app_settings_controller.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'history_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String? messId;
  const SettingsScreen({super.key, this.messId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _closeMonthAndReset(BuildContext context, String messId) async {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final currentMonthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    final currentMonthFullName = "${months[now.month - 1]} ${now.year}";

    final prevDate = DateTime(now.year, now.month - 1, 1);
    final prevMonthKey = "${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}";
    final prevMonthFullName = "${months[prevDate.month - 1]} ${prevDate.year}";

    String selectedMonthKey = now.day <= 15 ? prevMonthKey : currentMonthKey;
    String selectedMonthFullName = now.day <= 15 ? prevMonthFullName : currentMonthFullName;

    final messRef = FirebaseFirestore.instance.collection('messes').doc(messId);

    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF1B5E20)),
                SizedBox(width: 16),
                Text('Loading month overview...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );

    final bazaarSnap = await messRef.collection('bazaars').get();
    final mealSnap = await messRef.collection('meals').get();
    final dutySnap = await messRef.collection('bazaar_duties').get();
    final sharedExpenseSnap = await messRef.collection('shared_expenses').get();
    final paymentSnap = await messRef.collection('payments').get();
    final seatRentSnap = await messRef.collection('seat_rents').get();
    final monthlyBillsSnap = await messRef.collection('monthly_bills').get();

    if (context.mounted) {
      Navigator.pop(context);
    }

    double totalBazaar = 0;
    for (var doc in bazaarSnap.docs) {
      final d = doc.data();
      if ((d['status'] ?? 'approved') == 'approved') {
        totalBazaar += (d['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }

    double totalMeals = 0;
    for (var doc in mealSnap.docs) {
      final d = doc.data();
      totalMeals += (d['count'] ?? d['mealCount'] ?? 0 as num).toDouble();
    }

    double totalRent = 0;
    for (var doc in monthlyBillsSnap.docs) {
      final d = doc.data();
      final bMonth = d['month']?.toString() ?? '';
      if (bMonth.isEmpty || bMonth == selectedMonthFullName || bMonth == currentMonthFullName) {
        totalRent += (d['amount'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final double mealRate = totalMeals > 0 ? (totalBazaar / totalMeals) : 0.0;

    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.archive_rounded, color: Color(0xFF1B5E20), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Month-End Close & Archive'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select Month Session'.tr(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setDialogState(() {
                              selectedMonthKey = prevMonthKey;
                              selectedMonthFullName = prevMonthFullName;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: selectedMonthKey == prevMonthKey
                                  ? const Color(0xFF1B5E20).withValues(alpha: 0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedMonthKey == prevMonthKey
                                    ? const Color(0xFF1B5E20)
                                    : Colors.grey.shade300,
                                width: selectedMonthKey == prevMonthKey ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Previous Month'.tr(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: selectedMonthKey == prevMonthKey ? const Color(0xFF1B5E20) : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  prevMonthFullName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                if (now.day <= 15) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Recommended'.tr(),
                                      style: TextStyle(fontSize: 9, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setDialogState(() {
                              selectedMonthKey = currentMonthKey;
                              selectedMonthFullName = currentMonthFullName;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: selectedMonthKey == currentMonthKey
                                  ? const Color(0xFF1B5E20).withValues(alpha: 0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedMonthKey == currentMonthKey
                                    ? const Color(0xFF1B5E20)
                                    : Colors.grey.shade300,
                                width: selectedMonthKey == currentMonthKey ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Current Month'.tr(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: selectedMonthKey == currentMonthKey ? const Color(0xFF1B5E20) : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentMonthFullName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                if (now.day > 15) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Recommended'.tr(),
                                      style: TextStyle(fontSize: 9, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF1B5E20)),
                            const SizedBox(width: 6),
                            Text(
                              'Financial Overview'.tr(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                            ),
                            const Spacer(),
                            Text(
                              selectedMonthKey,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Bazaar'.tr(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                    const SizedBox(height: 2),
                                    Text('৳${totalBazaar.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Meals'.tr(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                    const SizedBox(height: 2),
                                    Text(totalMeals.toStringAsFixed(1), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Final Meal Rate'.tr(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                    const SizedBox(height: 2),
                                    Text('৳${mealRate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Utility Bills'.tr(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                    const SizedBox(height: 2),
                                    Text('৳${totalRent.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Important Notice'.tr(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'All bazaar, meals, and payment records for this session will be safely archived into History.'.tr(),
                                style: const TextStyle(fontSize: 10.5, color: Colors.black87, height: 1.3),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Fixed room rent and member seat configs remain preserved.'.tr(),
                                style: const TextStyle(fontSize: 10.5, color: Colors.black87, height: 1.3),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '24-Hour Safety Grace: You can restore this month anytime with 1 click.'.tr(),
                                style: const TextStyle(fontSize: 10.5, color: Colors.blueAccent, fontWeight: FontWeight.bold, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel'.tr(), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock_clock_rounded, size: 16, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              label: Text(
                'Archive & Close Month'.tr(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const CircularProgressIndicator(color: Color(0xFF1B5E20)),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Archiving month data safely...'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Please wait...'.tr(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Map<String, dynamic> backupBazaars = {for (var doc in bazaarSnap.docs) doc.id: doc.data()};
    Map<String, dynamic> backupMeals = {for (var doc in mealSnap.docs) doc.id: doc.data()};
    Map<String, dynamic> backupDuties = {for (var doc in dutySnap.docs) doc.id: doc.data()};
    Map<String, dynamic> backupSharedExpenses = {for (var doc in sharedExpenseSnap.docs) doc.id: doc.data()};
    Map<String, dynamic> backupPayments = {for (var doc in paymentSnap.docs) doc.id: doc.data()};
    Map<String, dynamic> backupSeatRents = {for (var doc in seatRentSnap.docs) doc.id: doc.data()};
    Map<String, dynamic> backupMonthlyBills = {for (var doc in monthlyBillsSnap.docs) doc.id: doc.data()};

    await messRef.collection('archived_months').doc(selectedMonthKey).set({
      'month': selectedMonthKey,
      'monthFullName': selectedMonthFullName,
      'closedAt': FieldValue.serverTimestamp(),
      'totalBazaar': totalBazaar,
      'totalMeals': totalMeals,
      'mealRate': mealRate,
      'totalRent': totalRent,
      'canUndoUntil': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      'backupData': {
        'bazaars': backupBazaars,
        'meals': backupMeals,
        'bazaar_duties': backupDuties,
        'shared_expenses': backupSharedExpenses,
        'payments': backupPayments,
        'seat_rents': backupSeatRents,
        'monthly_bills': backupMonthlyBills,
      },
    });

    for (var doc in bazaarSnap.docs) { await doc.reference.delete(); }
    for (var doc in dutySnap.docs) { await doc.reference.delete(); }
    for (var doc in mealSnap.docs) { await doc.reference.delete(); }
    for (var doc in sharedExpenseSnap.docs) { await doc.reference.delete(); }
    for (var doc in paymentSnap.docs) { await doc.reference.delete(); }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    await AutoNotificationService.sendNotification(
      messId: messId,
      title: '🔒 Fiscal Month Closed',
      body: 'Financial records for $selectedMonthFullName have been closed and archived.',
      type: 'notice',
      senderUid: currentUid,
    );

    if (context.mounted) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${"Session".tr()} $selectedMonthFullName ${"closed and archived successfully!".tr()}'),
          action: SnackBarAction(
            label: 'Undo (24h)'.tr(),
            textColor: Colors.yellow,
            onPressed: () => _restoreClosedMonth(context, messId),
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  Future<void> _restoreClosedMonth(BuildContext context, String messId) async {
    final messRef = FirebaseFirestore.instance.collection('messes').doc(messId);
    final now = DateTime.now();

    final archivedSnap = await messRef.collection('archived_months').get();
    final validRestorable = archivedSnap.docs.where((doc) {
      final data = doc.data();
      final canUndoUntil = (data['canUndoUntil'] as Timestamp?)?.toDate();
      return canUndoUntil != null && canUndoUntil.isAfter(now);
    }).toList();

    if (!context.mounted) return;

    if (validRestorable.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Restore Closed Month'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text('No recently closed month available for restoration (within 24h).'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close'.tr()),
            ),
          ],
        ),
      );
      return;
    }

    final targetDoc = validRestorable.first;
    final data = targetDoc.data();
    final monthName = data['monthFullName'] ?? data['month'] ?? targetDoc.id;
    final canUndoUntil = (data['canUndoUntil'] as Timestamp).toDate();
    final remainingMinutes = canUndoUntil.difference(now).inMinutes;
    final remainingHours = (remainingMinutes / 60).toStringAsFixed(1);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.restore_rounded, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Restore Month'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$monthName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 6),
            Text(
              '${"Time remaining to restore:".tr()} $remainingHours ${"hours".tr()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              'Do you want to restore this month? All archived records (bazaars, meals, duties, expenses, payments, room rent) will be returned to active status and this archive entry will be removed.'.tr(),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Restore Month'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final backupData = data['backupData'] as Map<String, dynamic>? ?? {};
    final backupBazaars = backupData['bazaars'] as Map<String, dynamic>? ?? {};
    final backupMeals = backupData['meals'] as Map<String, dynamic>? ?? {};
    final backupDuties = backupData['bazaar_duties'] as Map<String, dynamic>? ?? {};
    final backupShared = backupData['shared_expenses'] as Map<String, dynamic>? ?? {};
    final backupPayments = backupData['payments'] as Map<String, dynamic>? ?? {};
    final backupSeatRents = backupData['seat_rents'] as Map<String, dynamic>? ?? {};
    final backupMonthlyBills = backupData['monthly_bills'] as Map<String, dynamic>? ?? {};

    for (var entry in backupBazaars.entries) {
      await messRef.collection('bazaars').doc(entry.key).set(entry.value);
    }
    for (var entry in backupMeals.entries) {
      await messRef.collection('meals').doc(entry.key).set(entry.value);
    }
    for (var entry in backupDuties.entries) {
      await messRef.collection('bazaar_duties').doc(entry.key).set(entry.value);
    }
    for (var entry in backupShared.entries) {
      await messRef.collection('shared_expenses').doc(entry.key).set(entry.value);
    }
    for (var entry in backupPayments.entries) {
      await messRef.collection('payments').doc(entry.key).set(entry.value);
    }
    for (var entry in backupSeatRents.entries) {
      await messRef.collection('seat_rents').doc(entry.key).set(entry.value, SetOptions(merge: true));
    }
    for (var entry in backupMonthlyBills.entries) {
      await messRef.collection('monthly_bills').doc(entry.key).set(entry.value);
    }

    await targetDoc.reference.delete();

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    await AutoNotificationService.sendNotification(
      messId: messId,
      title: '🔄 Month Restored',
      body: 'Month records for $monthName have been restored.',
      type: 'notice',
      senderUid: currentUid,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Month restored successfully!'.tr())),
      );
    }
  }

  Future<void> _requestAccountDeletion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('Your account will be scheduled for permanent deletion in 15 days. If you log in within 15 days, this request will be cancelled automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Account', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && currentUser != null) {
      final deleteTime = DateTime.now().add(const Duration(days: 15));
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'scheduledDeletionTime': Timestamp.fromDate(deleteTime),
      });

      await AuthService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account scheduled for deletion in 15 days.')),
        );
      }
    }
  }

  void _showEditMessNameDialog(String messId, String currentMessName) {
    final messNameController = TextEditingController(text: currentMessName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_road_rounded, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            const Text('Change Mess Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)).tr(),
          ],
        ),
        content: TextField(
          controller: messNameController,
          decoration: const InputDecoration(
            labelText: 'New Mess Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel').tr(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            onPressed: () async {
              final newName = messNameController.text.trim();
              if (newName.isNotEmpty) {
                await FirebaseFirestore.instance.collection('messes').doc(messId).update({
                  'name': newName,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mess name updated successfully!')),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)).tr(),
          ),
        ],
      ),
    );
  }

  void _showAssignManagerDialog(String messId, List<DocumentSnapshot> members, String currentManagerUid) {
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members found.')),
      );
      return;
    }

    String? selectedUid = currentManagerUid.isNotEmpty && members.any((m) => m.id == currentManagerUid)
        ? currentManagerUid
        : members.first.id;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stateContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.manage_accounts_rounded, color: Color(0xFF1B5E20)),
                  const SizedBox(width: 8),
                  const Text('Assign Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)).tr(),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select a member to assign as this month\'s manager:', style: TextStyle(fontSize: 13, color: Colors.grey)).tr(),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUid,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Select Member'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: members.map((member) {
                      final data = member.data() as Map<String, dynamic>? ?? {};
                      return DropdownMenuItem<String>(
                        value: member.id,
                        child: Text(data['name']?.toString() ?? 'Member', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedUid = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel').tr()),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (selectedUid == null) return;
                    
                    if (currentManagerUid.isNotEmpty && currentManagerUid != selectedUid) {
                      final oldManagerDoc = await FirebaseFirestore.instance.collection('users').doc(currentManagerUid).get();
                      final oldManagerRole = oldManagerDoc.data()?['role'] ?? 'member';
                      
                      if (oldManagerRole.toString().toLowerCase() != 'admin') {
                        await FirebaseFirestore.instance.collection('users').doc(currentManagerUid).update({'role': 'member'});
                      }
                    }

                    final newManagerDoc = await FirebaseFirestore.instance.collection('users').doc(selectedUid).get();
                    final newManagerRole = newManagerDoc.data()?['role'] ?? 'member';

                    if (newManagerRole.toString().toLowerCase() != 'admin') {
                      await FirebaseFirestore.instance.collection('users').doc(selectedUid).update({'role': 'manager'});
                    }

                    await FirebaseFirestore.instance.collection('messes').doc(messId).update({'managerUid': selectedUid});

                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manager assigned successfully!')));
                    }
                  },
                  child: const Text('Assign', style: TextStyle(fontWeight: FontWeight.bold)).tr(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPendingRequestsDialog(String messId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person_add_rounded, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            const Text('Pending Join Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)).tr(),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('messId', isEqualTo: messId)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data?.docs ?? [];
              if (requests.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: const Text('No pending requests found.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)).tr(),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: requests.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final reqDoc = requests[index];
                  final data = reqDoc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown User';
                  final email = data['email'] ?? 'No email';
                  final uid = reqDoc.id;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(email, style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.red),
                          tooltip: 'Reject'.tr(),
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                              'messId': '',
                              'status': '',
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_rounded, color: Colors.green),
                          tooltip: 'Approve'.tr(),
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                              'status': 'active',
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close').tr(),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(String currentName, String currentPhotoUrl, String currentPhone) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);
    String tempPhotoUrl = currentPhotoUrl;
    bool isUploadingPhoto = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF1B5E20)),
              const SizedBox(width: 8),
              const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)).tr(),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: tempPhotoUrl.isNotEmpty ? NetworkImage(tempPhotoUrl) : null,
                          child: tempPhotoUrl.isEmpty
                              ? const Icon(Icons.person, size: 40, color: Colors.grey)
                              : null,
                        ),
                        if (isUploadingPhoto)
                          const Positioned.fill(
                            child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () async {
                              final picker = ImagePicker();
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 70,
                              );

                              if (image == null) return;

                              setDialogState(() => isUploadingPhoto = true);

                              try {
                                const cloudName = 'kedrygkt';
                                const uploadPreset = 'mess_chat_preset';

                                final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
                                var request = http.MultipartRequest('POST', uri)
                                  ..fields['upload_preset'] = uploadPreset
                                  ..files.add(await http.MultipartFile.fromPath('file', image.path));

                                var response = await request.send();
                                if (response.statusCode == 200) {
                                  final responseData = await response.stream.bytesToString();
                                  final jsonData = json.decode(responseData);
                                  setDialogState(() {
                                    tempPhotoUrl = jsonData['secure_url'];
                                    isUploadingPhoto = false;
                                  });
                                } else {
                                  throw Exception('Upload failed');
                                }
                              } catch (e) {
                                setDialogState(() => isUploadingPhoto = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Image upload failed: $e')),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1B5E20),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Your Name'.tr(),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number'.tr(),
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel').tr(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final newName = nameController.text.trim();
                final newPhone = phoneController.text.trim();
                if (newName.isEmpty) return;

                if (currentUser != null) {
                  await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
                    'name': newName,
                    'phone': newPhone,
                    'photoUrl': tempPhotoUrl,
                  });

                  await currentUser!.updateDisplayName(newName);
                  await currentUser!.updatePhotoURL(tempPhotoUrl.isNotEmpty ? tempPhotoUrl : null);
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)).tr(),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessMembersDialog(String messId, bool viewerIsAdmin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.contacts_rounded, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            const Text('Members Directory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)).tr(),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('messId', isEqualTo: messId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data?.docs ?? [];
              if (members.isEmpty) {
                return const Text('No members found.').tr();
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: members.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final memberDoc = members[index];
                  final data = memberDoc.data() as Map<String, dynamic>;
                  final memberUid = memberDoc.id;
                  final name = data['name'] ?? 'Member';
                  final phone = data['phone'] ?? 'No number';
                  final role = (data['role'] ?? 'member').toString().toUpperCase();
                  final photoUrl = data['photoUrl'] ?? '';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE8F5E9),
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'M',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)))
                          : null,
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      viewerIsAdmin ? '📞 $phone\nRole: $role' : 'Role: $role',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: viewerIsAdmin && memberUid != currentUser?.uid
                        ? IconButton(
                            icon: const Icon(Icons.person_remove_rounded, color: Colors.red),
                            tooltip: 'Remove Member'.tr(),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove Member?').tr(),
                                  content: Text('Are you sure you want to remove $name from the mess?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel').tr()),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remove', style: TextStyle(color: Colors.white)).tr(),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await FirebaseFirestore.instance.collection('users').doc(memberUid).update({
                                  'messId': '',
                                  'status': '',
                                  'role': 'member',
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$name has been removed from the mess.')),
                                  );
                                }
                              }
                            },
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close').tr(),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout Confirmation').tr(),
        content: const Text('Are you sure you want to log out from MessFlow?').tr(),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel').tr()),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)).tr(),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        final isDark = AppSettingsController.instance.isDarkMode;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings').tr(),
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (currentUser != null)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final String name = userData['name'] ?? currentUser!.displayName ?? 'User';
                    final String email = currentUser!.email ?? '';
                    final String phone = userData['phone'] ?? '';
                    final String photoUrl = userData['photoUrl'] ?? currentUser!.photoURL ?? '';
                    final String rawRole = (userData['role'] ?? 'member').toString().toUpperCase();
                    final String messId = userData['messId'] ?? '';

                    return StreamBuilder<DocumentSnapshot>(
                      stream: messId.isNotEmpty
                          ? FirebaseFirestore.instance.collection('messes').doc(messId).snapshots()
                          : null,
                      builder: (context, messSnap) {
                        final messData = messSnap.data?.data() as Map<String, dynamic>? ?? {};
                        final String currentManagerUid = messData['managerUid']?.toString() ?? '';
                        final String adminUid = messData['adminUid']?.toString() ?? '';
                        final String messName = messData['name']?.toString() ?? 'My Mess';

                        final bool isMessAdmin = (adminUid.isNotEmpty && adminUid == currentUser!.uid) || rawRole == 'ADMIN';
                        final String effectiveRole = isMessAdmin ? 'ADMIN' : rawRole;

                        final String displayRole = (effectiveRole == 'ADMIN' && currentUser!.uid == currentManagerUid)
                            ? 'ADMIN + MANAGER'
                            : effectiveRole;

                        final bool isAdminOrManager = displayRole.contains('ADMIN') || displayRole.contains('MANAGER');
                        final bool viewerIsAdmin = isMessAdmin;

                        return StreamBuilder<QuerySnapshot>(
                          stream: messId.isNotEmpty 
                              ? FirebaseFirestore.instance.collection('users').where('messId', isEqualTo: messId).snapshots() 
                              : null,
                          builder: (context, memberSnap) {
                            final totalMembers = memberSnap.data?.docs.length ?? 0;
                            final memberDocs = memberSnap.data?.docs ?? [];

                            return Column(
                              children: [
                                Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 34,
                                                  backgroundColor: const Color(0xFF1B5E20),
                                                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                                  child: photoUrl.isEmpty
                                                      ? Text(
                                                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                                                        )
                                                      : null,
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: InkWell(
                                                    onTap: () => _showEditProfileDialog(name, photoUrl, phone),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                                      ),
                                                      child: const Icon(Icons.camera_alt, size: 16, color: Color(0xFF1B5E20)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          name,
                                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.edit, size: 18, color: Color(0xFF1B5E20)),
                                                        onPressed: () => _showEditProfileDialog(name, photoUrl, phone),
                                                      ),
                                                    ],
                                                  ),
                                                  if (email.isNotEmpty)
                                                    Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                  const SizedBox(height: 4),
                                                  if (phone.isNotEmpty)
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.phone, size: 12, color: Colors.grey),
                                                        const SizedBox(width: 4),
                                                        Text(phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                      ],
                                                    ),
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF1B5E20).withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'Role: $displayRole',
                                                      style: const TextStyle(color: Color(0xFF1B5E20), fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (messId.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          const Divider(),
                                          InkWell(
                                            onTap: () => _showMessMembersDialog(messId, viewerIsAdmin),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.group_rounded, size: 16, color: Color(0xFF1B5E20)),
                                                      const SizedBox(width: 8),
                                                      const Text(
                                                        'Total Mess Members',
                                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                      ).tr(),
                                                    ],
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      '$totalMembers Members',
                                                      style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),

                                
                                if (messId.isNotEmpty) ...[
                                  Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: const Icon(Icons.history_rounded, color: Color(0xFF1B5E20)),
                                      title: const Text('Monthly Archives & History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)).tr(),
                                      subtitle: const Text('View closed months and past summaries', style: TextStyle(fontSize: 11, color: Colors.grey)).tr(),
                                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1B5E20)),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => HistoryScreen(messId: messId),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                if (isAdminOrManager && messId.isNotEmpty) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: const Text(
                                      'Manager / Admin Operations',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                                    ).tr(),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  if (viewerIsAdmin) ...[
                                    Card(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      color: Colors.green.shade50,
                                      child: ListTile(
                                        leading: const Icon(Icons.home_work_rounded, color: Color(0xFF1B5E20)),
                                        title: const Text(
                                          'Change Mess Name',
                                          style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 14),
                                        ).tr(),
                                        subtitle: const Text(
                                          'Update your mess name anytime',
                                          style: TextStyle(fontSize: 11, color: Colors.black54),
                                        ).tr(),
                                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1B5E20)),
                                        onTap: () => _showEditMessNameDialog(messId, messName),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],

                                  Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    color: Colors.green.shade50,
                                    child: ListTile(
                                      leading: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF1B5E20)),
                                      title: const Text(
                                        'Assign Mess Manager',
                                        style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 14),
                                      ).tr(),
                                      subtitle: const Text(
                                        'Assign or change this month\'s manager',
                                        style: TextStyle(fontSize: 11, color: Colors.black54),
                                      ).tr(),
                                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1B5E20)),
                                      onTap: () => _showAssignManagerDialog(messId, memberDocs, currentManagerUid),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    color: Colors.green.shade50,
                                    child: ListTile(
                                      leading: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF1B5E20)),
                                      title: const Text(
                                        'Pending Join Requests',
                                        style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 14),
                                      ).tr(),
                                      subtitle: const Text(
                                        'Approve or reject new members waiting to join',
                                        style: TextStyle(fontSize: 11, color: Colors.black54),
                                      ).tr(),
                                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1B5E20)),
                                      onTap: () => _showPendingRequestsDialog(messId),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    color: Colors.red.shade50.withValues(alpha: 0.6),
                                    child: ListTile(
                                      leading: const Icon(Icons.restart_alt_rounded, color: Colors.red),
                                      title: const Text(
                                        'Close Month & Start New Month',
                                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                                      ).tr(),
                                      subtitle: const Text(
                                        'Archive current month and safely reset records (24h undo)',
                                        style: TextStyle(fontSize: 11, color: Colors.black54),
                                      ).tr(),
                                      onTap: () => _closeMonthAndReset(context, messId),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    color: Colors.blue.shade50.withValues(alpha: 0.7),
                                    child: ListTile(
                                      leading: const Icon(Icons.restore_rounded, color: Colors.blue),
                                      title: const Text(
                                        'Restore Closed Month (24h Undo)',
                                        style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14),
                                      ).tr(),
                                      subtitle: const Text(
                                        'Restore recently closed month within 24 hours',
                                        style: TextStyle(fontSize: 11, color: Colors.black54),
                                      ).tr(),
                                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.blue),
                                      onTap: () => _restoreClosedMonth(context, messId),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),

              const Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)).tr(),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  secondary: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: isDark ? Colors.amber : const Color(0xFF1B5E20),
                  ),
                  title: const Text('Dark Mode').tr(),
                  subtitle: Text(isDark ? 'Dark theme enabled' : 'Light theme enabled'),
                  value: isDark,
                  onChanged: (val) {
                    AppSettingsController.instance.toggleTheme(val);
                  },
                ),
              ),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.language_rounded, color: Color(0xFF1B5E20)),
                  title: const Text('Language').tr(),
                  subtitle: Text(
                    context.locale.languageCode == 'bn'
                        ? 'বাংলা (Bangla)'
                        : context.locale.languageCode == 'hi'
                            ? 'हिन्दी (Hindi)'
                            : context.locale.languageCode == 'ar'
                                ? 'العربية (Arabic)'
                                : context.locale.languageCode == 'es'
                                    ? 'Español (Spanish)'
                                    : 'English',
                  ),
                  trailing: DropdownButton<String>(
                    value: ['en', 'bn', 'hi', 'ar', 'es'].contains(context.locale.languageCode)
                        ? context.locale.languageCode
                        : 'en',
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: 'bn', child: Text('বাংলা', style: TextStyle(fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: 'hi', child: Text('हिन्दी', style: TextStyle(fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: 'ar', child: Text('العربية', style: TextStyle(fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: 'es', child: Text('Español', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (newLang) async {
                      if (newLang != null) {
                        
                        await context.setLocale(Locale(newLang));
                        
                        
                        if (context.mounted) {
                          await AppSettingsController.instance.changeLanguage(context, newLang);
                        }
                        
                        
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => widget,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Text('Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)).tr(),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: const Text('Delete Account').tr(),
                  onTap: _requestAccountDeletion,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text('Logout').tr(),
                  onTap: _signOut,
                ),
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

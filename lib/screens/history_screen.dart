import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../controllers/app_settings_controller.dart';

class HistoryScreen extends StatefulWidget {
  final String messId;

  const HistoryScreen({super.key, required this.messId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  double _parseNum(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '')) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _checkPermissions() async {
    if (currentUid == null) return;
    
    final messDoc = await FirebaseFirestore.instance.collection('messes').doc(widget.messId).get();
    final adminUid = messDoc.data()?['adminUid']?.toString() ?? '';
    final managerUid = messDoc.data()?['managerUid']?.toString() ?? '';

    if (currentUid == adminUid || currentUid == managerUid) {
      if (mounted) setState(() => _canDelete = true);
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
    final role = userDoc.data()?['role']?.toString().toLowerCase() ?? '';
    
    if (role == 'admin' || role == 'manager') {
      if (mounted) setState(() => _canDelete = true);
    }
  }

  Future<void> _deleteArchiveRecord(String docId, String monthName) async {
    if (!_canDelete) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Archive Record?').tr(),
        content: Text('Are you sure you want to delete history for $monthName? You can undo this within 24 hours.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel').tr()),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)).tr(),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final deleteTime = DateTime.now().add(const Duration(hours: 24));
      final autoPurgeTime = DateTime.now().add(const Duration(days: 30));

      await FirebaseFirestore.instance
          .collection('messes')
          .doc(widget.messId)
          .collection('archived_months')
          .doc(docId)
          .update({
        'isDeleted': true,
        'canUndoUntil': Timestamp.fromDate(deleteTime),
        'autoDeleteAt': Timestamp.fromDate(autoPurgeTime),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${"Archive record for".tr()} $monthName ${"moved to trash.".tr()}'),
            action: SnackBarAction(
              label: 'Undo (24h)'.tr(),
              textColor: Colors.yellow,
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('messes')
                    .doc(widget.messId)
                    .collection('archived_months')
                    .doc(docId)
                    .update({
                  'isDeleted': false,
                  'canUndoUntil': null,
                  'autoDeleteAt': null,
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archive restored successfully!'.tr())));
              },
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _restoreMonthToActive(String docId, String monthName, Map<String, dynamic> data) async {
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
              monthName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
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

    final messRef = FirebaseFirestore.instance.collection('messes').doc(widget.messId);
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

    await messRef.collection('archived_months').doc(docId).delete();

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/history');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Month restored successfully!'.tr())),
      );
    }
  }

  void _viewArchivedSheetDetails(String monthName, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('users').where('messId', isEqualTo: widget.messId).get(),
          builder: (context, userSnap) {
            final members = userSnap.data?.docs ?? [];
            final List<String> memberUids = members.map((m) => m.id).toList();
            Map<String, String> memberNames = {};
            for (var m in members) {
              final mData = m.data() as Map<String, dynamic>;
              memberNames[m.id] = mData['name']?.toString() ?? 'Member';
            }

            final Map<String, dynamic> backupData = (data['backupData'] as Map<String, dynamic>?) ?? {};
            final Map<String, dynamic> backupBazaars = (backupData['bazaars'] as Map<String, dynamic>?) ?? {};
            final Map<String, dynamic> backupMeals = (backupData['meals'] as Map<String, dynamic>?) ?? {};
            final Map<String, dynamic> backupPayments = (backupData['payments'] as Map<String, dynamic>?) ?? {};
            final Map<String, dynamic> backupSharedExpenses = (backupData['shared_expenses'] as Map<String, dynamic>?) ?? {};
            final Map<String, dynamic> backupSeatRents = (backupData['seat_rents'] as Map<String, dynamic>?) ?? {};

            final double totalBazaar = _parseNum(data['totalBazaar']);
            final double totalMeals = _parseNum(data['totalMeals']);
            final double mealRate = _parseNum(data['mealRate']);
            final double totalRent = _parseNum(data['totalRent']);

            
            int daysInMonth = 31;
            try {
              if (monthName.contains('-')) {
                final parts = monthName.split('-');
                final y = int.parse(parts[0]);
                final m = int.parse(parts[1]);
                daysInMonth = DateTime(y, m + 1, 0).day;
              }
            } catch (_) {
              daysInMonth = 31;
            }

            
            Map<String, Map<int, double>> memberDailyMeals = {
              for (var uid in memberUids) uid: {}
            };
            Map<String, double> memberMealMap = {for (var uid in memberUids) uid: 0.0};

            backupMeals.forEach((key, val) {
              if (val is Map) {
                final uid = val['userId']?.toString() ?? val['memberId']?.toString() ?? val['userUid']?.toString() ?? '';
                final b = _parseNum(val['breakfast']);
                final l = _parseNum(val['lunch']);
                final d = _parseNum(val['dinner']);
                final count = _parseNum(val['count']) > 0 ? _parseNum(val['count']) : (b + l + d);

                int? day;
                final dateStr = val['date']?.toString() ?? '';
                if (dateStr.contains('-')) {
                  final parts = dateStr.split('-');
                  if (parts.length >= 3) day = int.tryParse(parts[2]);
                } else if (val['day'] != null) {
                  day = int.tryParse(val['day'].toString());
                }

                if (uid.isNotEmpty) {
                  if (!memberNames.containsKey(uid) && val['userName'] != null) {
                    memberNames[uid] = val['userName'].toString();
                    if (!memberUids.contains(uid)) memberUids.add(uid);
                    memberDailyMeals[uid] = {};
                  }
                  memberMealMap[uid] = (memberMealMap[uid] ?? 0.0) + count;
                  if (day != null && day >= 1 && day <= daysInMonth) {
                    memberDailyMeals[uid] ??= {};
                    memberDailyMeals[uid]![day] = (memberDailyMeals[uid]![day] ?? 0.0) + count;
                  }
                }
              }
            });

            
            double totalExtraExpenses = 0.0;
            backupSharedExpenses.forEach((key, val) {
              if (val is Map) {
                totalExtraExpenses += _parseNum(val['totalAmount']) > 0 
                    ? _parseNum(val['totalAmount']) 
                    : _parseNum(val['amount']);
              }
            });

            final double extraPerPerson = memberUids.isNotEmpty ? (totalExtraExpenses / memberUids.length) : 0.0;

            
            Map<String, double> memberDeposits = {for (var uid in memberUids) uid: 0.0};
            backupPayments.forEach((key, val) {
              if (val is Map) {
                final uid = val['userId']?.toString() ?? val['memberId']?.toString() ?? '';
                final status = (val['status']?.toString() ?? 'approved').toLowerCase();
                final category = (val['category']?.toString() ?? 'meal').toLowerCase();

                if (status == 'approved' && category == 'meal') {
                  final amount = _parseNum(val['amount']) > 0 ? _parseNum(val['amount']) : _parseNum(val['deposit']);
                  if (uid.isNotEmpty) {
                    memberDeposits[uid] = (memberDeposits[uid] ?? 0.0) + amount;
                  }
                }
              }
            });

            List membersReport = memberUids.map((uid) {
              final name = memberNames[uid] ?? 'Member';
              final double mMeals = memberMealMap[uid] ?? 0.0;
              final double mMealCost = mMeals * mealRate;
              final double deposited = memberDeposits[uid] ?? 0.0;
              final double totalCost = mMealCost + extraPerPerson;
              final double balance = deposited - totalCost;

              final bool hasRefund = balance > 0;
              final bool hasDue = balance < 0;
              final String statusStr = hasRefund 
                  ? 'Refund: ৳${balance.abs().toStringAsFixed(0)}' 
                  : hasDue 
                      ? 'Due: ৳${balance.abs().toStringAsFixed(0)}' 
                      : 'Settled';

              return {
                'name': name,
                'meals': mMeals.toStringAsFixed(1),
                'mealCost': mMealCost.toStringAsFixed(2),
                'extra': extraPerPerson.toStringAsFixed(2),
                'totalCost': totalCost.toStringAsFixed(0),
                'deposited': deposited.toStringAsFixed(0),
                'status': statusStr,
              };
            }).toList();

            final monthKey = data['month']?.toString() ?? '';
            final monthFullName = data['monthFullName']?.toString() ?? '';

            
            final List<Map<String, dynamic>> roomRentReport = memberUids.map((uid) {
              final mName = memberNames[uid] ?? 'Member';
              double payable = 0.0;
              double paid = 0.0;

              final rMap = backupSeatRents[uid] as Map<String, dynamic>?;
              if (rMap != null) {
                payable = _parseNum(rMap['totalPayable'] ?? rMap['payable'] ?? rMap['rent']);
                final paidAmounts = rMap['paid_amounts'] as Map<dynamic, dynamic>?;
                if (paidAmounts != null) {
                  paid = _parseNum(paidAmounts[monthFullName] ?? paidAmounts[monthKey] ?? 0);
                } else {
                  paid = _parseNum(rMap['paidAmount'] ?? 0);
                }
              }

              String status = 'Unpaid';
              if (payable > 0 && paid >= payable) {
                status = 'Paid';
              } else if (paid > 0) {
                status = 'Partial';
              }

              return {
                'name': mName,
                'payable': payable.toStringAsFixed(0),
                'paid': paid.toStringAsFixed(0),
                'status': status,
              };
            }).toList();

            final Map<String, dynamic> backupMonthlyBills = (backupData['monthly_bills'] as Map<String, dynamic>?) ?? {};
            final List<Map<String, dynamic>> monthlyBillsList = [];
            backupMonthlyBills.forEach((key, val) {
              if (val is Map) {
                monthlyBillsList.add(Map<String, dynamic>.from(val));
              }
            });

            
            final List<Map<String, dynamic>> bazaarsList = [];
            backupBazaars.forEach((key, val) {
              if (val is Map) {
                final Map<String, dynamic> bMap = Map<String, dynamic>.from(val);
                bMap['id'] = key;
                bazaarsList.add(bMap);
              }
            });

            bazaarsList.sort((a, b) {
              final aDate = a['date']?.toString() ?? '';
              final bDate = b['date']?.toString() ?? '';
              return bDate.compareTo(aDate);
            });

            return DefaultTabController(
              length: 4,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Archive: $monthName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.black87,
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        tabs: [
                          Tab(text: 'Summary & Balance'.tr()),
                          Tab(text: 'Bazaar Records'.tr()),
                          Tab(text: 'Meal Chart'.tr()),
                          Tab(text: 'Room Rent'.tr()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: TabBarView(
                        children: [
                          
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Archive Summary'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20))),
                                        const Divider(),
                                        _buildDetailRow('Total Approved Bazaar'.tr(), '৳ ${totalBazaar.toStringAsFixed(1)}'),
                                        _buildDetailRow('Total Mess Meals'.tr(), totalMeals.toStringAsFixed(1)),
                                        _buildDetailRow('Final Meal Rate'.tr(), '৳ ${mealRate.toStringAsFixed(2)}', isBold: true),
                                        _buildDetailRow('Total Extra Expenses:'.tr(), '৳ ${totalExtraExpenses.toStringAsFixed(1)}'),
                                        _buildDetailRow('Total Room Rent'.tr(), '৳ ${totalRent.toStringAsFixed(1)}', isBold: true),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text('Member Expense Summary'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
                                    columns: [
                                      DataColumn(label: Text('Member'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Meals'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Meal Cost'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Extra'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Total Cost'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Deposited'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status / Balance'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: membersReport.map((m) {
                                      final statusText = m['status']?.toString() ?? 'Settled';
                                      Color statusColor = Colors.green;
                                      if (statusText.startsWith('Due')) statusColor = Colors.red;
                                      if (statusText.startsWith('Refund')) statusColor = Colors.blue;

                                      return DataRow(cells: [
                                        DataCell(Text(m['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(m['meals']?.toString() ?? '0')),
                                        DataCell(Text('৳${m['mealCost'] ?? '0'}')),
                                        DataCell(Text('৳${m['extra'] ?? '0'}')),
                                        DataCell(Text('৳${m['totalCost'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text('৳${m['deposited'] ?? '0'}')),
                                        DataCell(Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor))),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          
                          bazaarsList.isEmpty
                              ? Center(
                                  child: Text('No bazaar records found for this month'.tr(), style: const TextStyle(color: Colors.grey)),
                                )
                              : ListView.builder(
                                  itemCount: bazaarsList.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        margin: const EdgeInsets.only(bottom: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1B5E20),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${'Total Approved Bazaar'.tr()} (${bazaarsList.length}):',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            Text(
                                              '৳ ${totalBazaar.toStringAsFixed(0)}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    final b = bazaarsList[index - 1];
                                    final buyer = b['buyerName'] ?? b['userName'] ?? b['addedByName'] ?? 'Buyer';
                                    final date = b['date'] ?? '';
                                    final double amount = _parseNum(b['amount']);
                                    final status = (b['status'] ?? 'approved').toString().toLowerCase();
                                    final isEdited = b['isEdited'] == true;
                                    final List items = b['items'] as List? ?? [];

                                    Color statusColor = Colors.green;
                                    String statusLabel = 'approved';
                                    if (status == 'rejected') {
                                      statusColor = Colors.red;
                                      statusLabel = 'rejected';
                                    } else if (status == 'pending') {
                                      statusColor = Colors.orange;
                                      statusLabel = 'pending';
                                    }

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Text(buyer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                      if (isEdited) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.amber.shade100,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Text('EDITED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.brown)),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  amount < 0 ? '-৳ ${amount.abs().toStringAsFixed(0)}' : '৳ ${amount.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: amount < 0 ? Colors.red : const Color(0xFF1B5E20),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    statusLabel,
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (items.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: items.map((it) {
                                                  if (it is Map) {
                                                    final iName = it['name'] ?? '';
                                                    final iPrice = it['price'] ?? '';
                                                    return Chip(
                                                      label: Text('$iName: ৳$iPrice', style: const TextStyle(fontSize: 11)),
                                                      padding: EdgeInsets.zero,
                                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      visualDensity: VisualDensity.compact,
                                                    );
                                                  }
                                                  return const SizedBox.shrink();
                                                }).toList(),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                          
                          SingleChildScrollView(
                            child: Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Daily Meal Chart (1 to 31)'.tr(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20)),
                                        ),
                                        Text('${'Total Mess Meals'.tr()}: ${totalMeals.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    const Divider(),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
                                        headingRowHeight: 38,
                                        dataRowMinHeight: 36,
                                        dataRowMaxHeight: 40,
                                        columns: [
                                          DataColumn(
                                            label: Text('Member'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                                          ),
                                          for (int i = 1; i <= daysInMonth; i++)
                                            DataColumn(
                                              label: Text('$i', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                          DataColumn(
                                            label: Text('Total'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                          ),
                                        ],
                                        rows: memberUids.map((uid) {
                                          final name = memberNames[uid] ?? 'Member';
                                          double memberMonthlyTotal = 0.0;

                                          List<DataCell> cells = [
                                            DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          ];

                                          for (int i = 1; i <= daysInMonth; i++) {
                                            double dayMeal = memberDailyMeals[uid]?[i] ?? 0.0;
                                            memberMonthlyTotal += dayMeal;

                                            cells.add(
                                              DataCell(
                                                Text(
                                                  dayMeal > 0
                                                      ? (dayMeal % 1 == 0 ? dayMeal.toInt().toString() : dayMeal.toStringAsFixed(1))
                                                      : '-',
                                                  style: TextStyle(
                                                    fontWeight: dayMeal > 0 ? FontWeight.bold : FontWeight.normal,
                                                    color: dayMeal > 0 ? const Color(0xFF1B5E20) : Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          cells.add(
                                            DataCell(
                                              Text(
                                                memberMonthlyTotal % 1 == 0
                                                    ? memberMonthlyTotal.toInt().toString()
                                                    : memberMonthlyTotal.toStringAsFixed(1),
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13),
                                              ),
                                            ),
                                          );

                                          return DataRow(cells: cells);
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (monthlyBillsList.isNotEmpty) ...[
                                  Card(
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Monthly Expense & Utility Bills'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                                          const Divider(),
                                          ...monthlyBillsList.map((b) {
                                            final title = b['title']?.toString() ?? 'Bill';
                                            final double amt = _parseNum(b['amount']);
                                            return _buildDetailRow(title, '৳ ${amt.toStringAsFixed(0)}');
                                          }),
                                          const Divider(),
                                          _buildDetailRow('Total Utility Bills'.tr(), '৳ ${totalRent.toStringAsFixed(0)}', isBold: true),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Room Rent & Utilities Summary'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                                        const Divider(),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
                                            columns: [
                                              DataColumn(label: Text('Member'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                              DataColumn(label: Text('Total Payable'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                              DataColumn(label: Text('Paid Amount'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                              DataColumn(label: Text('Status'.tr(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                            ],
                                            rows: roomRentReport.map((r) {
                                              final String st = r['status'] ?? 'Unpaid';
                                              Color stColor = Colors.redAccent;
                                              if (st == 'Paid') stColor = const Color(0xFF1B5E20);
                                              if (st == 'Partial') stColor = Colors.orange;

                                              return DataRow(cells: [
                                                DataCell(Text(r['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                                DataCell(Text('৳ ${r['payable'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                                DataCell(Text('৳ ${r['paid'] ?? '0'}')),
                                                DataCell(Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: stColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: stColor, width: 0.8),
                                                  ),
                                                  child: Text(st.tr(), style: TextStyle(color: stColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                                )),
                                              ]);
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black87)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: isBold ? const Color(0xFF1B5E20) : Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6F8FA),
          appBar: AppBar(title: const Text('Archives / History').tr(), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white, elevation: 0),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('messes')
                .doc(widget.messId)
                .collection('archived_months')
                .orderBy('closedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final allDocs = snapshot.data?.docs ?? [];
              final now = DateTime.now();

              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final bool isDeleted = data['isDeleted'] ?? false;
                if (!isDeleted) return true;

                final Timestamp? autoDeleteAt = data['autoDeleteAt'] as Timestamp?;
                if (autoDeleteAt != null && now.isAfter(autoDeleteAt.toDate())) {
                  doc.reference.delete();
                  return false;
                }
                return true;
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No archived months found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String month = data['monthFullName'] ?? data['month'] ?? doc.id;
                  final double totalBazaar = _parseNum(data['totalBazaar']);
                  final bool isDeleted = data['isDeleted'] ?? false;

                  if (isDeleted) {
                    return Opacity(
                      opacity: 0.5,
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.red.shade50,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const Icon(Icons.delete_sweep, color: Colors.red),
                          title: Text('$month (Marked for deletion)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                          subtitle: const Text('Will be permanently deleted after 1 month from request.'),
                        ),
                      ),
                    );
                  }

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0.8,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: const Icon(Icons.receipt_long, color: Colors.teal)),
                      title: Text(month, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text('${'Total Approved Bazaar'.tr()}: ৳ ${totalBazaar.toStringAsFixed(1)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_canDelete && data['canUndoUntil'] != null) ...[
                            Builder(
                              builder: (context) {
                                final canUndoUntil = (data['canUndoUntil'] as Timestamp?)?.toDate();
                                if (canUndoUntil != null && canUndoUntil.isAfter(DateTime.now())) {
                                  return IconButton(
                                    icon: const Icon(Icons.restore_rounded, color: Colors.blue, size: 22),
                                    tooltip: 'Restore Month (24h Undo)'.tr(),
                                    onPressed: () => _restoreMonthToActive(doc.id, month, data),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                          if (_canDelete)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              tooltip: 'Delete Archive Record'.tr(),
                              onPressed: () => _deleteArchiveRecord(doc.id, month),
                            ),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ],
                      ),
                      onTap: () => _viewArchivedSheetDetails(month, data),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

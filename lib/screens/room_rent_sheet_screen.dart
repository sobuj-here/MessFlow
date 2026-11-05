import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomRentSheetScreen extends StatefulWidget {
  final String messId;
  final bool isAdmin;

  const RoomRentSheetScreen({
    super.key,
    required this.messId,
    this.isAdmin = false,
  });

  @override
  State<RoomRentSheetScreen> createState() => _RoomRentSheetScreenState();
}

class _RoomRentSheetScreenState extends State<RoomRentSheetScreen> {
  late String currentMonthName;
  late List<String> availableMonths;
  final TextEditingController _noteController = TextEditingController();
  bool _isSavingNote = false;

  @override
  void initState() {
    super.initState();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final now = DateTime.now();
    currentMonthName = "${months[now.month - 1]} ${now.year}";

    availableMonths = [];
    for (int i = -60; i <= 120; i++) {
      final d = DateTime(now.year, now.month + i, 1);
      availableMonths.add("${months[d.month - 1]} ${d.year}");
    }
    _fetchMonthNote();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchMonthNote() async {
    final doc = await FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('room_rent_notes')
        .doc(currentMonthName)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _noteController.text = doc.data()?['note'] ?? '';
      });
    } else {
      setState(() {
        _noteController.text = '';
      });
    }
  }

  Future<void> _saveMonthNote() async {
    if (!widget.isAdmin) return;
    setState(() => _isSavingNote = true);

    try {
      await FirebaseFirestore.instance
          .collection('messes')
          .doc(widget.messId)
          .collection('room_rent_notes')
          .doc(currentMonthName)
          .set({
        'note': _noteController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingNote = false);
    }
  }

  void _editTotalPayable(String memberId, String memberName, double currentAmount) {
    if (!widget.isAdmin) return;

    final controller = TextEditingController(
      text: currentAmount > 0 ? currentAmount.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Set Total Rent for $memberName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter monthly fixed payable rent (This remains saved until you change it again):',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Total Rent (BDT)',
                prefixText: 'Tk ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            onPressed: () async {
              final amount = double.tryParse(controller.text.trim()) ?? 0.0;
              final firestore = FirebaseFirestore.instance;
              final batch = firestore.batch();

              final seatRentRef = firestore
                  .collection('messes')
                  .doc(widget.messId)
                  .collection('seat_rents')
                  .doc(memberId);
              batch.set(seatRentRef, {
                'userId': memberId,
                'totalPayable': amount,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              final userRef = firestore.collection('users').doc(memberId);
              batch.set(userRef, {
                'seatRent': amount,
              }, SetOptions(merge: true));

              await batch.commit();

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Rent', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editPaidAmount(String memberId, String memberName, double currentPaid) {
    if (!widget.isAdmin) return;

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Payment for $memberName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Paid: Tk ${currentPaid.toStringAsFixed(0)}\nEnter additional amount to add (Use minus e.g. -200 to reduce):',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount to Add/Reduce (BDT)',
                prefixText: 'Tk ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            onPressed: () async {
              final addAmount = double.tryParse(controller.text.trim()) ?? 0.0;
              if (addAmount == 0) {
                Navigator.pop(ctx);
                return;
              }

              final docRef = FirebaseFirestore.instance
                  .collection('messes')
                  .doc(widget.messId)
                  .collection('seat_rents')
                  .doc(memberId);

              final docSnap = await docRef.get();
              double existingPaid = 0.0;
              if (docSnap.exists) {
                final data = docSnap.data() as Map<String, dynamic>;
                final paidAmounts = data['paid_amounts'] as Map<dynamic, dynamic>?;
                existingPaid = (paidAmounts?[currentMonthName] as num?)?.toDouble() ?? 0.0;
              }

              double newTotalPaid = existingPaid + addAmount;
              if (newTotalPaid < 0) newTotalPaid = 0.0;

              await docRef.set({
                'paid_amounts': {currentMonthName: newTotalPaid},
                'paid_months': {currentMonthName: newTotalPaid > 0},
              }, SetOptions(merge: true));

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Update Payment', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddBillDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Monthly Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Expense Name (e.g. House Rent, WiFi, Cook)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (BDT)',
                prefixText: 'Tk ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            onPressed: () async {
              final title = titleController.text.trim();
              final amount = double.tryParse(amountController.text.trim()) ?? 0.0;

              if (title.isNotEmpty && amount != 0) {
                await FirebaseFirestore.instance
                    .collection('messes')
                    .doc(widget.messId)
                    .collection('monthly_bills')
                    .add({
                  'title': title,
                  'amount': amount,
                  'month': currentMonthName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBill(String docId) async {
    if (!widget.isAdmin) return;
    await FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('monthly_bills')
        .doc(docId)
        .delete();
  }

  Future<void> _archiveRentMonth(BuildContext context, double totalExpense) async {
    if (!widget.isAdmin) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive / Save to History?'),
        content: Text('Do you want to save the summary for $currentMonthName to history? Current sheet data will be archived and active payments for this month will reset to 0.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        final historyRef = firestore
            .collection('messes')
            .doc(widget.messId)
            .collection('room_rent_history')
            .doc(currentMonthName);

        batch.set(historyRef, {
          'month': currentMonthName,
          'totalExpense': totalExpense,
          'archivedAt': FieldValue.serverTimestamp(),
        });

        final usersSnap = await firestore
            .collection('users')
            .where('messId', isEqualTo: widget.messId)
            .get();

        for (var userDoc in usersSnap.docs) {
          final userId = userDoc.id;
          final seatRentRef = firestore
              .collection('messes')
              .doc(widget.messId)
              .collection('seat_rents')
              .doc(userId);

          batch.set(
            seatRentRef,
            {
              'userId': userId,
              'paid_amounts': {currentMonthName: 0.0},
              'paid_months': {currentMonthName: false},
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room rent sheet archived and active payments reset to 0!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!availableMonths.contains(currentMonthName)) {
      availableMonths.add(currentMonthName);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Rent & Utilities Sheet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Archive to History',
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('messes')
                    .doc(widget.messId)
                    .collection('monthly_bills')
                    .where('month', isEqualTo: currentMonthName)
                    .get()
                    .then((snap) {
                  double tExp = 0;
                  for (var doc in snap.docs) {
                    tExp += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
                  }
                  _archiveRentMonth(context, tExp);
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Billing Period:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  DropdownButton<String>(
                    value: currentMonthName,
                    underline: const SizedBox(),
                    items: availableMonths.map((month) {
                      return DropdownMenuItem(
                        value: month,
                        child: Text(
                          month,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                        ),
                      );
                    }).toList(),
                    onChanged: (newMonth) {
                      if (newMonth != null) {
                        setState(() {
                          currentMonthName = newMonth;
                        });
                        _fetchMonthNote();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messes')
                  .doc(widget.messId)
                  .collection('monthly_bills')
                  .where('month', isEqualTo: currentMonthName)
                  .snapshots(),
              builder: (context, billSnap) {
                final bills = billSnap.data?.docs ?? [];
                double totalExpense = 0;
                for (var doc in bills) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalExpense += (data['amount'] as num?)?.toDouble() ?? 0.0;
                }

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'MONTHLY EXPENSE SUMMARY',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20)),
                            ),
                            if (widget.isAdmin)
                              InkWell(
                                onTap: _showAddBillDialog,
                                child: const Row(
                                  children: [
                                    Icon(Icons.add_circle, color: Color(0xFF1B5E20), size: 18),
                                    SizedBox(width: 4),
                                    Text('Add Bill', style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (bills.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('No expenses recorded for this month.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          )
                        else
                          ...bills.map((b) {
                            final bData = b.data() as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      if (widget.isAdmin)
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                                          onPressed: () => _deleteBill(b.id),
                                        ),
                                      if (widget.isAdmin) const SizedBox(width: 6),
                                      Text(bData['title'] ?? '', style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                  Text('Tk ${(bData['amount'] as num?)?.toDouble().toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Tk ${totalExpense.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('messId', isEqualTo: widget.messId).snapshots(),
              builder: (context, userSnap) {
                final members = userSnap.data?.docs ?? [];

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('messes')
                      .doc(widget.messId)
                      .collection('seat_rents')
                      .snapshots(),
                  builder: (context, rentSnap) {
                    final Map<String, double> manualAmountMap = {};
                    final Map<String, double> paidAmountMap = {};

                    for (var doc in rentSnap.data?.docs ?? []) {
                      final rData = doc.data() as Map<String, dynamic>;
                      manualAmountMap[doc.id] = (rData['totalPayable'] as num?)?.toDouble() ?? 0.0;
                      
                      final paidAmounts = rData['paid_amounts'] as Map<dynamic, dynamic>?;
                      paidAmountMap[doc.id] = (paidAmounts?[currentMonthName] as num?)?.toDouble() ?? 0.0;
                    }

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('PAYMENT SUMMARY',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20))),
                                Text('(Tap member to edit)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: members.length,
                              separatorBuilder: (_, __) => const Divider(height: 16),
                              itemBuilder: (context, index) {
                                final mData = members[index].data() as Map<String, dynamic>;
                                final String uid = members[index].id;
                                final String name = mData['name'] ?? 'Member';

                                final double seatRentFromUser = (mData['seatRent'] as num?)?.toDouble() ?? 0.0;
                                final double totalPayable = (manualAmountMap[uid] != null && manualAmountMap[uid]! > 0)
                                    ? manualAmountMap[uid]!
                                    : seatRentFromUser;
                                final double paidAmount = paidAmountMap[uid] ?? 0.0;
                                final bool isPaid = paidAmount >= totalPayable && totalPayable > 0;

                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: InkWell(
                                        onTap: widget.isAdmin ? () => _editTotalPayable(uid, name, totalPayable) : null,
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name, 
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (widget.isAdmin) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.edit, size: 12, color: Colors.grey),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4), // 🌟 এখানে নেগেটিভ উইডথ ফিক্স করা হয়েছে
                                    Text(
                                      'Tk ${totalPayable.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: widget.isAdmin ? () => _editPaidAmount(uid, name, paidAmount) : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPaid ? Colors.green.shade50 : (paidAmount > 0 ? Colors.orange.shade50 : Colors.red.shade50),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: isPaid ? Colors.green : (paidAmount > 0 ? Colors.orange : Colors.redAccent)),
                                        ),
                                        child: Text(
                                          isPaid
                                              ? '${"Paid".tr()} ৳${paidAmount.toStringAsFixed(0)}'
                                              : (paidAmount > 0
                                                  ? '${"Paid".tr()} ৳${paidAmount.toStringAsFixed(0)} (${"Due".tr()} ৳${(totalPayable - paidAmount).toStringAsFixed(0)})'
                                                  : 'Unpaid'.tr()),
                                          style: TextStyle(
                                            color: isPaid ? const Color(0xFF1B5E20) : (paidAmount > 0 ? Colors.deepOrange : Colors.redAccent),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'MONTHLY NOTE / REMARK',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20)),
                        ),
                        if (widget.isAdmin)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF1B5E20),
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.save_rounded, size: 16),
                            label: Text(_isSavingNote ? 'Saving...' : 'Save Note', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: _isSavingNote ? null : _saveMonthNote,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      maxLength: 500,
                      readOnly: !widget.isAdmin,
                      decoration: InputDecoration(
                        hintText: widget.isAdmin ? 'Write a short note for this month (max 100 words)...' : 'No notes available.',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
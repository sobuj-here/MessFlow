import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auto_notification_service.dart';

class SharedItemInput {
  final TextEditingController titleController;
  final TextEditingController amountController;

  SharedItemInput({String title = '', String amount = ''})
      : titleController = TextEditingController(text: title),
        amountController = TextEditingController(text: amount);
}

class SharedExpenseScreen extends StatefulWidget {
  final String messId;
  final bool isManager;

  const SharedExpenseScreen({
    super.key,
    required this.messId,
    required this.isManager,
  });

  @override
  State<SharedExpenseScreen> createState() => _SharedExpenseScreenState();
}

class _SharedExpenseScreenState extends State<SharedExpenseScreen> {
  final List<SharedItemInput> _items = [SharedItemInput()];
  bool _isSaving = false;
  late String currentMonthName;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    currentMonthName = "${months[now.month - 1]} ${now.year}";
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.titleController.dispose();
      item.amountController.dispose();
    }
    super.dispose();
  }

  void _addNewRow() {
    setState(() => _items.add(SharedItemInput()));
  }

  void _removeRow(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].titleController.dispose();
        _items[index].amountController.dispose();
        _items.removeAt(index);
      });
    }
  }

  double _parseAmount(String text) {
    if (text.isEmpty) return 0.0;
    const bengaliDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    
    String cleaned = text.trim();
    for (int i = 0; i < bengaliDigits.length; i++) {
      cleaned = cleaned.replaceAll(bengaliDigits[i], englishDigits[i]);
    }
    cleaned = cleaned.replaceAll(',', '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  Future<void> _saveSharedExpenses() async {
    if (_isSaving) return;

    if (!widget.isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Only Admin and Manager can add extra expenses!').tr()),
      );
      return;
    }

    final List<Map<String, dynamic>> validItems = [];
    double calculatedTotal = 0.0;

    for (var item in _items) {
      final title = item.titleController.text.trim();
      final cost = _parseAmount(item.amountController.text);
      if (title.isNotEmpty && cost > 0) {
        validItems.add({'title': title, 'amount': cost});
        calculatedTotal += cost;
      }
    }

    if (validItems.isEmpty || calculatedTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one valid expense item with cost')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final batch = FirebaseFirestore.instance.batch();

      final docRef = FirebaseFirestore.instance
          .collection('messes')
          .doc(widget.messId)
          .collection('shared_expenses')
          .doc();

      batch.set(docRef, {
        'id': docRef.id,
        'totalAmount': calculatedTotal,
        'items': validItems,
        'month': currentMonthName,
        'addedBy': user?.uid,
        'addedByName': user?.displayName ?? 'Manager',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      final firstTitle = validItems.isNotEmpty ? validItems.first['title'] : 'Extra Expense';
      AutoNotificationService.sendNotification(
        messId: widget.messId,
        title: '📢 Extra Expense Added!',
        body: '৳${calculatedTotal.toStringAsFixed(0)} was recorded for $firstTitle.',
        type: 'shared_cost',
        senderUid: user?.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extra expenses saved successfully!')),
        );
        setState(() {
          for (var item in _items) {
            item.titleController.dispose();
            item.amountController.dispose();
          }
          _items.clear();
          _items.add(SharedItemInput());
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteExpense(String docId) async {
    if (!widget.isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Only Admin and Manager can delete extra expenses!').tr()),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete Expense?'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this expense record?'.tr(),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm Delete'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('messes')
            .doc(widget.messId)
            .collection('shared_expenses')
            .doc(docId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully!')),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text('${'Extra Expenses'.tr()} ($currentMonthName)'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('messes')
            .doc(widget.messId)
            .collection('shared_expenses')
            .where('month', isEqualTo: currentMonthName)
            .snapshots(),
        builder: (context, snapshot) {
          double totalMonthExpense = 0.0;
          final docs = snapshot.data?.docs ?? [];

          if (snapshot.hasData) {
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              totalMonthExpense += (data['totalAmount'] is num) ? (data['totalAmount'] as num).toDouble() : 0.0;
            }
          }

          return Column(
            children: [
              // Total Expense Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Extra Expenses:'.tr(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      '৳ ${totalMonthExpense.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              if (widget.isManager) ...[
                Expanded(
                  flex: 3,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _items[index].titleController,
                                  decoration: InputDecoration(
                                    hintText: 'Expense Name (e.g. WiFi, Maid, Gas)'.tr(),
                                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _items[index].amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Amount (৳)'.tr(),
                                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              if (_items.length > 1)
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  onPressed: () => _removeRow(index),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFF1B5E20)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add, color: Color(0xFF1B5E20)),
                          label: Text(
                            'Add Row'.tr(),
                            style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                          ),
                          onPressed: _addNewRow,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isSaving ? null : _saveSharedExpenses,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Save Expenses'.tr(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.amber.shade50,
                  width: double.infinity,
                  child: Text(
                    'Note: Only Admin and Manager can add or delete extra expenses.'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.brown, fontWeight: FontWeight.w500),
                  ),
                ),
              ],

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recorded Extra Expenses'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),

              Expanded(
                flex: 4,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : docs.isEmpty
                        ? Center(
                            child: Text(
                              'No extra expenses recorded for this month'.tr(),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final docId = doc.id;
                              
                              final double total = (data['totalAmount'] is num) ? (data['totalAmount'] as num).toDouble() : 0.0;
                              final List items = data['items'] ?? [];

                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ExpansionTile(
                                  leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1B5E20)),
                                  title: Text(
                                    '৳ ${total.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Text(
                                    'Items: ${items.length} (${'Shared equally among all members'.tr()})',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  trailing: widget.isManager
                                      ? IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          onPressed: () => _deleteExpense(docId),
                                        )
                                      : null,
                                  children: items.map((i) {
                                    final itemMap = i as Map<String, dynamic>;
                                    final itemTitle = itemMap['title'] ?? '';
                                    final double itemAmount = (itemMap['amount'] is num) ? (itemMap['amount'] as num).toDouble() : 0.0;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(itemTitle, style: const TextStyle(fontSize: 14)),
                                          Text('৳ ${itemAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
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

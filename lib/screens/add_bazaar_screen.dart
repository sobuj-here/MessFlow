import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auto_notification_service.dart';

class AddBazaarScreen extends StatefulWidget {
  final String messId;
  final bool isAdmin;
  final bool isManager;

  const AddBazaarScreen({
    super.key,
    required this.messId,
    this.isAdmin = false,
    required this.isManager,
  });

  @override
  State<AddBazaarScreen> createState() => _AddBazaarScreenState();
}

class _AddBazaarScreenState extends State<AddBazaarScreen> {
  final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

  bool get _canManage => widget.isAdmin || widget.isManager;

  void _showBazaarItemDialog({String? docId, Map<String, dynamic>? initialData}) {
    final bool isEditing = docId != null;

    DateTime selectedDate = isEditing && initialData?['date'] != null
        ? (DateTime.tryParse(initialData!['date']) ?? DateTime.now())
        : DateTime.now();

    List<Map<String, TextEditingController>> itemRows = [];

    if (isEditing && initialData != null && initialData['items'] is List && (initialData['items'] as List).isNotEmpty) {
      for (var it in initialData['items']) {
        itemRows.add({
          'name': TextEditingController(text: it['name']?.toString() ?? ''),
          'qty': TextEditingController(text: it['qty']?.toString() ?? ''),
          'price': TextEditingController(text: it['price'] != null ? it['price'].toString() : ''),
        });
      }
    } else {
      itemRows.add({
        'name': TextEditingController(),
        'qty': TextEditingController(),
        'price': TextEditingController(),
      });
    }

    double calculateTotal() {
      double total = 0.0;
      for (var row in itemRows) {
        final text = row['price']?.text.trim() ?? '';
        final p = double.tryParse(text.replaceAll(',', '')) ?? 0.0;
        total += p;
      }
      return total;
    }

    bool isSavingBazaar = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (statefulContext, setDialogState) {
          final currentTotal = calculateTotal();

          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.add_shopping_cart_rounded,
                  color: const Color(0xFF1B5E20),
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Bazaar Expense' : 'Add Bazaar Expense',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B5E20)),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.95,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Date: ${selectedDate.toIso8601String().split('T')[0]}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null && dialogContext.mounted) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                          child: const Text('Change', style: TextStyle(color: Color(0xFF1B5E20))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'bazaar_negative_note'.tr(),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items List:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              itemRows.add({
                                'name': TextEditingController(),
                                'qty': TextEditingController(),
                                'price': TextEditingController(),
                              });
                            });
                          },
                          icon: const Icon(Icons.add, size: 16, color: Color(0xFF1B5E20)),
                          label: const Text('Add Item', style: TextStyle(color: Color(0xFF1B5E20))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: itemRows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final row = itemRows[idx];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: row['name'],
                                  decoration: const InputDecoration(hintText: 'Item Name', border: InputBorder.none, isDense: true),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row['qty'],
                                  decoration: const InputDecoration(hintText: 'Qty', border: InputBorder.none, isDense: true),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row['price'],
                                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                  decoration: const InputDecoration(hintText: '৳ Cost (e.g. -500)', border: InputBorder.none, isDense: true),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ),
                              if (itemRows.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                                  onPressed: () {
                                    setDialogState(() {
                                      row['name']?.dispose();
                                      row['qty']?.dispose();
                                      row['price']?.dispose();
                                      itemRows.removeAt(idx);
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: currentTotal < 0 ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Calculated Cost:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text(
                            currentTotal < 0
                                ? '-৳ ${currentTotal.abs().toStringAsFixed(0)} (Deduction)'
                                : '৳ ${currentTotal.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: currentTotal < 0 ? Colors.red.shade800 : const Color(0xFF1B5E20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSavingBazaar ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                onPressed: isSavingBazaar
                    ? null
                    : () async {
                        final totalAmount = calculateTotal();
                        if (totalAmount == 0) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Please enter valid items and cost (or negative for return)!')),
                            );
                          }
                          return;
                        }

                        // 🌟 24-hour edit restriction check for editing
                        if (isEditing && initialData != null) {
                          DateTime? createdAt;
                          if (initialData['createdAt'] is Timestamp) {
                            createdAt = (initialData['createdAt'] as Timestamp).toDate();
                          } else if (initialData['date'] != null) {
                            createdAt = DateTime.tryParse(initialData['date'].toString());
                          }
                          final isExpired = createdAt != null && DateTime.now().difference(createdAt).inHours >= 24;
                          if (isExpired) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Editing time expired! Bazaar cannot be edited after 24 hours.')),
                              );
                            }
                            return;
                          }
                        }

                        // 🌟 ডাবল-ক্লিক প্রতিরোধ
                        setDialogState(() => isSavingBazaar = true);

                        try {
                          List<Map<String, dynamic>> savedItems = [];
                          List<String> summaryNames = [];

                          for (var r in itemRows) {
                            final n = r['name']?.text.trim() ?? '';
                            final q = r['qty']?.text.trim() ?? '';
                            final p = double.tryParse(r['price']?.text.trim() ?? '') ?? 0.0;
                            if (n.isNotEmpty || p != 0) {
                              savedItems.add({'name': n.isEmpty ? 'Item' : n, 'qty': q, 'price': p});
                              summaryNames.add('$n ${q.isNotEmpty ? "($q)" : ""}');
                            }
                          }

                          final titleSummary = summaryNames.join(', ');
                          final dateStr = selectedDate.toIso8601String().split('T')[0];
                          final messRef = FirebaseFirestore.instance.collection('messes').doc(widget.messId);

                          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
                          final userName = userDoc.data()?['name'] ?? 'Member';

                          if (isEditing) {
                            await messRef.collection('bazaars').doc(docId).update({
                              'title': titleSummary,
                              'items': savedItems,
                              'amount': totalAmount,
                              'date': dateStr,
                              'isEdited': true,
                              'editedAt': FieldValue.serverTimestamp(),
                              'editedBy': currentUid,
                            });

                            // 🌟 বাজার এডিট করার পর নোটিফিকেশন পাঠানো
                            await AutoNotificationService.sendNotification(
                              messId: widget.messId,
                              title: '✏️ Bazaar Expense Updated',
                              body: '$userName updated bazaar expense (Total: ৳${totalAmount.toStringAsFixed(0)}).',
                              type: 'bazaar_edit',
                              senderUid: currentUid,
                            );
                          } else {
                            final status = _canManage ? 'approved' : 'pending';

                            await messRef.collection('bazaars').add({
                              'title': titleSummary,
                              'items': savedItems,
                              'amount': totalAmount,
                              'date': dateStr,
                              'userId': currentUid,
                              'userName': userName,
                              'status': status,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            // 🌟 নতুন বাজার যোগ করার নোটিফিকেশন
                            await AutoNotificationService.sendNotification(
                              messId: widget.messId,
                              title: '🛒 New Bazaar Added!',
                              body: '$userName added bazaar expense of ৳${totalAmount.toStringAsFixed(0)}.',
                              type: 'bazaar_add',
                              senderUid: currentUid,
                            );
                          }

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Bazaar updated successfully!' : 'Bazaar added successfully!')),
                            );
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setDialogState(() => isSavingBazaar = false);
                          }
                        }
                      },
                child: isSavingBazaar
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _approveBazaar(String docId) async {
    await FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('bazaars')
        .doc(docId)
        .update({'status': 'approved'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bazaar approved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bazaar Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text('Add Bazaar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showBazaarItemDialog(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('messes')
            .doc(widget.messId)
            .collection('bazaars')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No bazaar expenses recorded yet.', style: TextStyle(color: Colors.grey)));
          }

          final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
          sortedDocs.sort((a, b) {
            final aDate = (a.data() as Map<String, dynamic>)['date'] ?? '';
            final bDate = (b.data() as Map<String, dynamic>)['date'] ?? '';
            return bDate.compareTo(aDate);
          });

          double totalApproved = 0.0;
          for (var doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            final status = (d['status']?.toString() ?? 'approved').toLowerCase().trim();
            if (status == 'approved') {
              final amount = d['amount'];
              if (amount is num) {
                totalApproved += amount.toDouble();
              } else if (amount is String) {
                totalApproved += double.tryParse(amount.replaceAll(',', '').trim()) ?? 0.0;
              }
            }
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Approved Bazaar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          totalApproved < 0
                              ? '-৳ ${totalApproved.abs().toStringAsFixed(0)}'
                              : '৳ ${totalApproved.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: totalApproved < 0 ? Colors.red : const Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: Text('All Bazaar Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = sortedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                      final date = data['date'] ?? '';
                      final userName = data['userName'] ?? 'Member';
                      final status = (data['status'] ?? 'approved').toString().toLowerCase();
                      final bool isApproved = status == 'approved';
                      final bool isEdited = data['isEdited'] == true;
                      final List itemList = (data['items'] is List) ? (data['items'] as List) : [];

                      // 🌟 24-hour check: If created >= 24 hours ago, NO ONE can edit
                      DateTime? createdAt;
                      if (data['createdAt'] is Timestamp) {
                        createdAt = (data['createdAt'] as Timestamp).toDate();
                      } else if (data['date'] != null) {
                        createdAt = DateTime.tryParse(data['date'].toString());
                      }
                      final bool isExpired = createdAt != null && DateTime.now().difference(createdAt).inHours >= 24;
                      final bool canEdit = !isExpired && (_canManage || (!isApproved && data['userId'] == currentUid));

                      // 🌟 Approved bazaar can NEVER be deleted until month close
                      final bool canDelete = !isApproved;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    amount < 0
                                        ? '-৳ ${amount.abs().toStringAsFixed(0)}'
                                        : '৳ ${amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: amount < 0 ? Colors.red : const Color(0xFF1B5E20),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isEdited) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: const Text(
                                            'EDITED',
                                            style: TextStyle(
                                              color: Color(0xFF1976D2),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isApproved ? Colors.green.shade50 : Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: isApproved ? Colors.green.shade800 : Colors.orange.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (itemList.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: itemList.map<Widget>((it) {
                                    final n = it['name'] ?? '';
                                    final q = it['qty'] ?? '';
                                    final p = it['price'] != null ? ' (৳${it['price']})' : '';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F8E9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$n ${q.isNotEmpty ? "[$q]" : ""}$p',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text('By: $userName | $date', style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isApproved && _canManage)
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                                          onPressed: () => _approveBazaar(doc.id),
                                        ),
                                      const SizedBox(width: 4),
                                      if (canEdit)
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF1976D2), size: 24),
                                          onPressed: () => _showBazaarItemDialog(docId: doc.id, initialData: data),
                                        ),
                                      const SizedBox(width: 4),
                                      if (canDelete)
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                          onPressed: () async {
                                            // 🌟 Extra safety check: prevent deleting if approved
                                            if (isApproved) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Approved bazaar cannot be deleted until the month is closed!')),
                                              );
                                              return;
                                            }
                                            await FirebaseFirestore.instance
                                                .collection('messes')
                                                .doc(widget.messId)
                                                .collection('bazaars')
                                                .doc(doc.id)
                                                .delete();
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: sortedDocs.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

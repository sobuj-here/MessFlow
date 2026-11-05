import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'live_mess_sheet_screen.dart'; // MessHomeDashboardScreen-এর সঠিক রুট নিশ্চিত করার জন্য

class AssignBazaarScreen extends StatefulWidget {
  final String messId;
  final bool isManager;

  const AssignBazaarScreen({
    super.key,
    required this.messId,
    required this.isManager,
  });

  @override
  State<AssignBazaarScreen> createState() => _AssignBazaarScreenState();
}

class _AssignBazaarScreenState extends State<AssignBazaarScreen> {
  final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
  DateTime _selectedDate = DateTime.now();

  String get _dateStr => _selectedDate.toIso8601String().split('T')[0];

  final List<Map<String, TextEditingController>> _itemControllers = [];
  List<DocumentSnapshot> _members = [];
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('messId', isEqualTo: widget.messId)
          .get();
      if (mounted) {
        setState(() {
          _members = snap.docs;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanupControllers();
    super.dispose();
  }

  void _addNewItemField(StateSetter setDialogState) {
    setDialogState(() {
      _itemControllers.add({
        'name': TextEditingController(),
        'qty': TextEditingController(),
      });
    });
  }

  void _removeItemField(int index, StateSetter setDialogState) {
    setDialogState(() {
      _itemControllers[index]['name']?.dispose();
      _itemControllers[index]['qty']?.dispose();
      _itemControllers.removeAt(index);
    });
  }

  void _cleanupControllers() {
    for (var m in _itemControllers) {
      m['name']?.dispose();
      m['qty']?.dispose();
    }
    _itemControllers.clear();
  }

  void _showAssignDutyDialog(List<DocumentSnapshot> members) {
    String? selectedUid = members.isNotEmpty ? members.first.id : null;
    String selectedName = members.isNotEmpty
        ? (members.first.data() as Map<String, dynamic>)['name'] ?? 'Member'
        : 'Member';
    final estBudgetController = TextEditingController();
    final instructionsController = TextEditingController();

    _itemControllers.clear();
    _itemControllers.add({
      'name': TextEditingController(),
      'qty': TextEditingController(),
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF1B5E20), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Assign Bazaar Duty'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1B5E20)),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Member:'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedUid,
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF1B5E20)),
                      ),
                      items: members.map((m) {
                        final data = m.data() as Map<String, dynamic>;
                        return DropdownMenuItem(value: m.id, child: Text(data['name'] ?? 'Member', style: const TextStyle(color: Colors.black87)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedUid = val;
                            final mDoc = members.firstWhere((e) => e.id == val);
                            selectedName = (mDoc.data() as Map<String, dynamic>)['name'] ?? 'Member';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    Text('Estimated Budget:'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: estBudgetController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'e.g. 1500',
                        prefixText: '৳ ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text('Notes / Instructions:'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: instructionsController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'e.g. Buy fresh vegetables from morning bazar',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Items Checklist:'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                        ),
                        InkWell(
                          onTap: () => _addNewItemField(setDialogState),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF1B5E20)),
                                const SizedBox(width: 4),
                                Text(
                                  'Add Item'.tr(),
                                  style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Column(
                      children: List.generate(_itemControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _itemControllers[index]['name'],
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    decoration: const InputDecoration(
                                      hintText: 'Item (e.g. Potato)',
                                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                Container(height: 20, width: 1, color: Colors.grey.shade300),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _itemControllers[index]['qty'],
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    decoration: const InputDecoration(
                                      hintText: 'Qty (e.g. 2kg)',
                                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                if (_itemControllers.length > 1)
                                  GestureDetector(
                                    onTap: () => _removeItemField(index, setDialogState),
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _cleanupControllers();
                  Navigator.pop(dialogContext);
                },
                child: Text('Cancel'.tr(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (selectedUid == null) return;

                  final estBudget = double.tryParse(estBudgetController.text.trim()) ?? 0.0;
                  final instructions = instructionsController.text.trim();

                  List<Map<String, dynamic>> items = [];
                  for (var item in _itemControllers) {
                    final name = item['name']?.text.trim() ?? '';
                    final qty = item['qty']?.text.trim() ?? '';
                    if (name.isNotEmpty) {
                      items.add({
                        'name': name,
                        'qty': qty,
                        'isBought': false,
                      });
                    }
                  }

                  final messRef = FirebaseFirestore.instance.collection('messes').doc(widget.messId);
                  final batch = FirebaseFirestore.instance.batch();

                  final dutyDoc = messRef.collection('bazaar_duties').doc();
                  batch.set(dutyDoc, {
                    'assignedTo': selectedUid,
                    'assignedName': selectedName,
                    'date': _dateStr,
                    'estimatedBudget': estBudget,
                    'instructions': instructions,
                    'items': items,
                    'status': 'pending_acceptance',
                    'issueReason': '',
                    'assignedBy': currentUid,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  final notifDoc = messRef.collection('notifications').doc();
                  batch.set(notifDoc, {
                    'targetUid': selectedUid,
                    'title': '🛒 Bazaar Duty Assigned!',
                    'body': 'You have been assigned bazaar duty for $_dateStr. Please accept or report.',
                    'type': 'bazaar_duty',
                    'createdAt': FieldValue.serverTimestamp(),
                    'readBy': [],
                  });

                  await batch.commit();
                  _cleanupControllers();

                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Duty assigned to $selectedName!')),
                    );
                  }
                },
                child: Text('Confirm Duty'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _acceptDuty(String docId) async {
    final messRef = FirebaseFirestore.instance.collection('messes').doc(widget.messId);
    await messRef.collection('bazaar_duties').doc(docId).update({
      'status': 'accepted',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have accepted the bazaar duty!')),
      );
    }
  }

  void _showReportIssueDialog(String docId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.report_problem_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('Cannot Go for Bazaar'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: 'Reason'.tr(),
            hintText: 'e.g. Exam, Sick, Urgent work...',
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              final messRef = FirebaseFirestore.instance.collection('messes').doc(widget.messId);
              final batch = FirebaseFirestore.instance.batch();

              batch.update(messRef.collection('bazaar_duties').doc(docId), {
                'status': 'issue',
                'issueReason': reason,
              });

              final notifDoc = messRef.collection('notifications').doc();
              batch.set(notifDoc, {
                'targetRole': 'manager',
                'title': '⚠️ Bazaar Duty Problem!',
                'body': 'Assigned member reported an issue for $_dateStr: "$reason"',
                'type': 'bazaar_duty',
                'createdAt': FieldValue.serverTimestamp(),
                'readBy': [],
              });

              await batch.commit();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Submit Report'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDuty(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Duty?'.tr()),
        content: Text('Are you sure you want to delete this bazaar duty schedule?'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('messes')
          .doc(widget.messId)
          .collection('bazaar_duties')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bazaar duty deleted successfully!'.tr())),
        );
      }
    }
  }

  void _toggleItemStatus(String docId, List<dynamic> currentItems, int index) {
    List<dynamic> updated = List.from(currentItems);
    final currentStatus = updated[index]['isBought'] ?? false;
    updated[index]['isBought'] = !currentStatus;

    FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('bazaar_duties')
        .doc(docId)
        .update({'items': updated});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messId.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Bazaar Duty'.tr())),
        body: Center(child: Text('Error: Mess ID is empty!'.tr())),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text('Bazaar Duty & Checklist'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Color(0xFF1B5E20), size: 22),
                      const SizedBox(width: 8),
                      Text('Date: $_dateStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18, color: Color(0xFF1B5E20)),
                    label: Text('Select Date'.tr(), style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null && mounted) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (widget.isManager) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isLoadingMembers
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.add_task_rounded, color: Colors.white),
                label: Text(
                  'Assign Bazaar Duty & Create List'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () async {
                  if (_members.isEmpty) {
                    setState(() => _isLoadingMembers = true);
                    await _fetchMembers();
                    if (mounted) setState(() => _isLoadingMembers = false);
                  }
                  if (mounted) _showAssignDutyDialog(_members);
                },
              ),
              const SizedBox(height: 16),
            ],

                Text('Duties Scheduled for this Date'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('messes')
                      .doc(widget.messId)
                      .collection('bazaar_duties')
                      .where('date', isEqualTo: _dateStr)
                      .snapshots(),
                  builder: (context, dutySnap) {
                    if (dutySnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF1B5E20))));
                    }

                    final allDuties = dutySnap.data?.docs ?? [];
                    
                    final duties = widget.isManager 
                        ? allDuties 
                        : allDuties.where((d) => (d.data() as Map<String, dynamic>)['assignedTo'] == currentUid).toList();

                    if (duties.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Center(
                          child: Text('No bazaar duty scheduled for you on this date.'.tr(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: duties.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final dutyDoc = duties[index];
                        final data = dutyDoc.data() as Map<String, dynamic>;
                        final dutyId = dutyDoc.id;

                        final assignedUid = data['assignedTo'] ?? '';
                        final assignedName = data['assignedName'] ?? 'Member';
                        final estBudget = (data['estimatedBudget'] as num?)?.toDouble() ?? 0.0;
                        final instructions = data['instructions'] ?? '';
                        final status = (data['status'] ?? 'pending_acceptance').toString().toLowerCase();
                        final issueReason = data['issueReason'] ?? '';
                        final List items = data['items'] ?? [];

                        final bool isAssignedToMe = assignedUid == currentUid;
                        final bool canManage = widget.isManager;

                        return Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Color(0xFFE8F5E9),
                                          child: Icon(Icons.person_rounded, color: Color(0xFF1B5E20), size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(assignedName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: status == 'issue' ? Colors.red.shade50 : (status == 'accepted' ? Colors.green.shade50 : Colors.amber.shade50),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: status == 'issue' ? Colors.red : (status == 'accepted' ? Colors.green : Colors.amber)),
                                          ),
                                          child: Text(
                                            status == 'pending_acceptance' ? 'PENDING'.tr() : status.toUpperCase(),
                                            style: TextStyle(color: status == 'issue' ? Colors.red : (status == 'accepted' ? Colors.green.shade700 : Colors.amber.shade800), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (canManage) ...[
                                          const SizedBox(width: 6),
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                            onPressed: () => _deleteDuty(dutyId),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Est. Budget: ৳${estBudget.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1B5E20))),
                                    ],
                                  ),
                                ),

                                if (instructions.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text('Note: $instructions', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                ],

                                if (items.isNotEmpty) ...[
                                  const Divider(height: 16),
                                  Text('Checklist:'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: items.length,
                                    itemBuilder: (context, i) {
                                      final item = items[i] as Map<String, dynamic>;
                                      final isBought = item['isBought'] ?? false;
                                      return InkWell(
                                        onTap: (canManage || isAssignedToMe) ? () => _toggleItemStatus(dutyId, items, i) : null,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                                          child: Row(
                                            children: [
                                              Icon(isBought ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                                  color: isBought ? const Color(0xFF1B5E20) : Colors.grey, size: 18),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item['name'] ?? '',
                                                  style: TextStyle(
                                                    decoration: isBought ? TextDecoration.lineThrough : null,
                                                    color: isBought ? Colors.grey : Colors.black87,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              Text(item['qty'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                if (status == 'issue' && issueReason.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                    child: Text('Issue: $issueReason', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],

                                if (isAssignedToMe && status == 'pending_acceptance') ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
                                          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                          label: Text('Ready to Go'.tr(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          onPressed: () => _acceptDuty(dutyId),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                                          icon: const Icon(Icons.close_rounded, size: 16),
                                          label: Text('Cannot Go'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          onPressed: () => _showReportIssueDialog(dutyId),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                if (isAssignedToMe && status == 'accepted') ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.report_problem_rounded, color: Colors.redAccent, size: 16),
                                        label: Text('Report Issue'.tr(), style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                        onPressed: () => _showReportIssueDialog(dutyId),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }
}
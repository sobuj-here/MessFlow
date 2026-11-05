import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auto_notification_service.dart';

class PaymentScreen extends StatefulWidget {
  final String messId;
  final bool isAdmin;
  final bool isManager;

  const PaymentScreen({
    super.key,
    required this.messId,
    required this.isAdmin,
    required this.isManager,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

  final _mealAmountController = TextEditingController();
  final _mealTrxController = TextEditingController();
  String _mealMethod = 'bKash';

  final _rentAmountController = TextEditingController();
  final _rentTrxController = TextEditingController();
  String _rentMethod = 'bKash';

  final List<String> _mfsList = ['bKash', 'Nagad', 'Rocket', 'Upay', 'Bank Transfer'];

  // 🌟 ডাবল-ক্লিক ও ডুপ্লিকেট পেমেন্ট ট্র্যাকিং গার্ড
  bool _isSubmittingPayment = false;
  final Set<String> _processingPaymentIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mealAmountController.dispose();
    _mealTrxController.dispose();
    _rentAmountController.dispose();
    _rentTrxController.dispose();
    super.dispose();
  }

  void _showEditSpecificMfsDialog({
    required bool forAdmin,
    required String mfsName,
    required Map<String, dynamic> currentMfsData,
  }) {
    final phoneCtrl = TextEditingController(text: currentMfsData['phone'] ?? '');
    String selectedType = currentMfsData['type'] ?? 'Personal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, color: Color(0xFF1976D2), size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Configure $mfsName (${forAdmin ? "Admin Rent" : "Manager Meal"})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter mobile number and select account type:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: '$mfsName Number (e.g. 017xxxxxxxx)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: Theme.of(context).cardColor,
                  decoration: const InputDecoration(
                    labelText: 'Account Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Personal', child: Text('Personal (Send Money)')),
                    DropdownMenuItem(value: 'Merchant', child: Text('Merchant (Payment)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedType = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)),
              onPressed: () async {
                final newPhone = phoneCtrl.text.trim();
                if (newPhone.isEmpty) return;

                final fieldKey = forAdmin ? 'admin_mfs_$mfsName' : 'manager_mfs_$mfsName';

                await FirebaseFirestore.instance.collection('messes').doc(widget.messId).set({
                  fieldKey: {
                    'phone': newPhone,
                    'type': selectedType,
                  }
                }, SetOptions(merge: true));

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$mfsName info updated successfully!')),
                  );
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePaymentAction({
    required String mfsName,
    required Map<String, dynamic> mfsData,
    required String amountStr,
  }) async {
    final phone = mfsData['phone'] ?? '';
    final accountType = mfsData['type'] ?? 'Personal';

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$mfsName account number has not been set yet! Please configure it.')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: phone));

    final isMerchant = accountType.toLowerCase() == 'merchant';
    final actionType = isMerchant ? 'Payment (Merchant)' : 'Send Money (Personal)';
    final amountNote = amountStr.isNotEmpty ? 'of Tk $amountStr ' : '';

    Color brandColor;
    if (mfsName == 'bKash') {
      brandColor = const Color(0xFFE2136E);
    } else if (mfsName == 'Nagad') {
      brandColor = const Color(0xFFF7941D);
    } else if (mfsName == 'Rocket') {
      brandColor = const Color(0xFF8C349B);
    } else {
      brandColor = const Color(0xFF00A651);
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: brandColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$mfsName $actionType',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Copied Number: $phone', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
              const SizedBox(height: 8),
              Text('Open your $mfsName app and complete the $actionType ${amountNote}to this number.'),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandColor),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _showAddCashDialog(bool forAdmin, List<DocumentSnapshot> members) {
    String? selectedMemberId = members.isNotEmpty ? members.first.id : null;
    String selectedMemberName = members.isNotEmpty ? (members.first.data() as Map)['name'] ?? 'Member' : 'Member';
    final cashAmountCtrl = TextEditingController();

    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final currentMonthName = "${months[now.month - 1]} ${now.year}";
    bool isSavingCash = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            forAdmin ? 'Receive Rent Cash (Admin)' : 'Receive Meal Cash (Manager)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMemberId,
                  dropdownColor: Theme.of(context).cardColor,
                  decoration: const InputDecoration(labelText: 'Select Member', border: OutlineInputBorder()),
                  items: members.map((m) {
                    final mData = m.data() as Map<String, dynamic>;
                    return DropdownMenuItem(value: m.id, child: Text(mData['name'] ?? 'Member'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedMemberId = val;
                        final mDoc = members.firstWhere((e) => e.id == val);
                        selectedMemberName = (mDoc.data() as Map<String, dynamic>)['name'] ?? 'Member';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cashAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  decoration: const InputDecoration(labelText: 'Cash Amount (BDT)', prefixText: 'Tk ', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSavingCash ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)),
              onPressed: isSavingCash
                  ? null
                  : () async {
                      final amount = double.tryParse(cashAmountCtrl.text.trim()) ?? 0.0;
                      if (amount == 0 || selectedMemberId == null) return;

                      // 🌟 ডাবল-ক্লিক সুরক্ষা
                      setDialogState(() => isSavingCash = true);

                      try {
                        final category = forAdmin ? 'rent' : 'meal';
                        final messRef = FirebaseFirestore.instance.collection('messes').doc(widget.messId);

                        final payRef = messRef.collection('payments').doc();
                        await payRef.set({
                          'userId': selectedMemberId,
                          'userName': selectedMemberName,
                          'amount': amount,
                          'category': category,
                          'method': 'Cash in Hand',
                          'trxId': 'CASH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                          'status': 'approved',
                          'createdAt': DateTime.now().millisecondsSinceEpoch,
                          'date': DateTime.now().toIso8601String().split('T')[0],
                        });

                        if (forAdmin) {
                          final seatRentRef = messRef.collection('seat_rents').doc(selectedMemberId);
                          final seatSnap = await seatRentRef.get();
                          double existingPaid = 0.0;
                          if (seatSnap.exists) {
                            final data = seatSnap.data() as Map<String, dynamic>;
                            final paidAmounts = data['paid_amounts'] as Map<dynamic, dynamic>?;
                            existingPaid = (paidAmounts?[currentMonthName] as num?)?.toDouble() ?? 0.0;
                          }

                          await seatRentRef.set({
                            'paid_amounts': {currentMonthName: existingPaid + amount},
                            'paid_months': {currentMonthName: (existingPaid + amount) > 0},
                          }, SetOptions(merge: true));
                        } else {
                          final userRef = FirebaseFirestore.instance.collection('users').doc(selectedMemberId);
                          await userRef.update({
                            'deposit': FieldValue.increment(amount),
                          });
                        }

                        await AutoNotificationService.sendNotification(
                          messId: widget.messId,
                          title: '💵 Cash Payment Added',
                          body: '৳$amount received in cash for $selectedMemberName ($category).',
                          type: 'payment_approved',
                          senderUid: currentUid,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tk $amount Cash recorded successfully!')));
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isSavingCash = false);
                        }
                      }
                    },
              child: isSavingCash
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Add Cash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPayment(bool forAdmin) async {
    if (_isSubmittingPayment) return;

    final amountCtrl = forAdmin ? _rentAmountController : _mealAmountController;
    final trxCtrl = forAdmin ? _rentTrxController : _mealTrxController;
    final method = forAdmin ? _rentMethod : _mealMethod;
    final category = forAdmin ? 'rent' : 'meal';

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
    final trxId = trxCtrl.text.trim();

    if (amount == 0 || trxId.isEmpty || currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter amount and TrxID')));
      return;
    }

    setState(() => _isSubmittingPayment = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      final userName = userDoc.data()?['name'] ?? 'Member';

      final messRef = FirebaseFirestore.instance.collection('messes').doc(widget.messId);
      final payRef = messRef.collection('payments').doc();
      
      await payRef.set({
        'userId': currentUid,
        'userName': userName,
        'amount': amount,
        'category': category,
        'method': method,
        'trxId': trxId,
        'status': 'pending',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'date': DateTime.now().toIso8601String().split('T')[0],
      });

      await AutoNotificationService.sendNotification(
        messId: widget.messId,
        title: '💵 Payment Slip Submitted!',
        body: '$userName submitted a $category payment of ৳$amount via $method.',
        type: 'payment_request',
        senderUid: currentUid,
      );

      amountCtrl.clear();
      trxCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment slip submitted successfully!')));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Payment & Transfers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_rounded), text: 'Manager (Meal)'),
            Tab(icon: Icon(Icons.home_rounded), text: 'Admin (Rent)'),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('messes').doc(widget.messId).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('messId', isEqualTo: widget.messId).snapshots(),
            builder: (context, userSnap) {
              final members = userSnap.data?.docs ?? [];

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildTabContent(forAdmin: false, messData: data, members: members),
                  _buildTabContent(forAdmin: true, messData: data, members: members),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTabContent({
    required bool forAdmin,
    required Map<String, dynamic> messData,
    required List<DocumentSnapshot> members,
  }) {
    final amountCtrl = forAdmin ? _rentAmountController : _mealAmountController;
    final trxCtrl = forAdmin ? _rentTrxController : _mealTrxController;
    final selectedMethod = forAdmin ? _rentMethod : _mealMethod;
    final bool canEdit = forAdmin ? widget.isAdmin : (widget.isManager || widget.isAdmin);

    final bkash = messData[forAdmin ? 'admin_mfs_bKash' : 'manager_mfs_bKash'] as Map<String, dynamic>? ?? {'phone': '', 'type': 'Personal'};
    final nagad = messData[forAdmin ? 'admin_mfs_Nagad' : 'manager_mfs_Nagad'] as Map<String, dynamic>? ?? {'phone': '', 'type': 'Personal'};
    final rocket = messData[forAdmin ? 'admin_mfs_Rocket' : 'manager_mfs_Rocket'] as Map<String, dynamic>? ?? {'phone': '', 'type': 'Personal'};
    final upay = messData[forAdmin ? 'admin_mfs_Upay' : 'manager_mfs_Upay'] as Map<String, dynamic>? ?? {'phone': '', 'type': 'Personal'};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        forAdmin ? 'Admin Rent Accounts' : 'Manager Meal Accounts',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1976D2)),
                      ),
                      if (canEdit)
                        const Text(
                          'Tap item to edit',
                          style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildMfsAccountTile('bKash', bkash, const Color(0xFFE2136E), forAdmin, canEdit),
                  const Divider(height: 12),
                  _buildMfsAccountTile('Nagad', nagad, const Color(0xFFF7941D), forAdmin, canEdit),
                  const Divider(height: 12),
                  _buildMfsAccountTile('Rocket', rocket, const Color(0xFF8C349B), forAdmin, canEdit),
                  const Divider(height: 12),
                  _buildMfsAccountTile('Upay', upay, const Color(0xFF00A651), forAdmin, canEdit),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (canEdit) ...[
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1976D2),
                  child: Icon(Icons.payments_rounded, color: Colors.white),
                ),
                title: Text(forAdmin ? 'Receive Rent Cash' : 'Receive Meal Cash', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Direct cash in hand record', style: TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Add Cash', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddCashDialog(forAdmin, members),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Submit Online Payment Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    dropdownColor: Theme.of(context).cardColor,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: _mfsList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          if (forAdmin) {
                            _rentMethod = v;
                          } else {
                            _mealMethod = v;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    decoration: const InputDecoration(labelText: 'Transferred Amount (BDT)', prefixText: 'Tk ', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: trxCtrl,
                    decoration: const InputDecoration(labelText: 'Transaction ID (TrxID)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), padding: const EdgeInsets.symmetric(vertical: 13)),
                    onPressed: _isSubmittingPayment ? null : () => _submitPayment(forAdmin),
                    child: _isSubmittingPayment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Confirm & Send Slip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (forAdmin ? widget.isAdmin : (widget.isManager || widget.isAdmin)) ...[
            Text(
              forAdmin ? 'Pending Rent Payment Requests' : 'Pending Meal Payment Requests',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1976D2)),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messes')
                  .doc(widget.messId)
                  .collection('payments')
                  .where('category', isEqualTo: forAdmin ? 'rent' : 'meal')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, paySnap) {
                if (!paySnap.hasData) return const Center(child: CircularProgressIndicator());
                final pendingList = paySnap.data?.docs ?? [];

                if (pendingList.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No pending payment requests found.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingList.length,
                  itemBuilder: (context, index) {
                    final pDoc = pendingList[index];
                    final pData = pDoc.data() as Map<String, dynamic>;
                    final userId = pData['userId'];
                    final userName = pData['userName'] ?? 'Member';
                    final amount = (pData['amount'] as num?)?.toDouble() ?? 0.0;
                    final method = pData['method'] ?? '';
                    final trxId = pData['trxId'] ?? '';
                    final category = pData['category'] ?? '';
                    final bool isProcessing = _processingPaymentIds.contains(pDoc.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('$userName - Tk $amount', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Method: $method\nTrxID: $trxId\nCategory: ${category.toUpperCase()}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isProcessing)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () async {
                                  if (_processingPaymentIds.contains(pDoc.id)) return;
                                  setState(() => _processingPaymentIds.add(pDoc.id));

                                  try {
                                    await pDoc.reference.update({'status': 'rejected'});
                                    await AutoNotificationService.sendNotification(
                                      messId: widget.messId,
                                      title: '❌ Payment Rejected',
                                      body: 'Payment request of ৳$amount ($category) was rejected.',
                                      type: 'payment_rejected',
                                      senderUid: currentUid,
                                    );
                                  } finally {
                                    if (mounted) setState(() => _processingPaymentIds.remove(pDoc.id));
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () async {
                                  if (_processingPaymentIds.contains(pDoc.id)) return;
                                  setState(() => _processingPaymentIds.add(pDoc.id));

                                  try {
                                    // 🌟 ডাবল ক্লিক প্রতিরোধ: ইতিমধ্যে অনুমোদিত কিনা রিচেক করা
                                    final freshSnap = await pDoc.reference.get();
                                    final freshData = freshSnap.data() as Map<String, dynamic>?;
                                    if (freshSnap.exists && freshData?['status'] == 'approved') {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Payment already approved!')),
                                        );
                                      }
                                      return;
                                    }

                                    final now = DateTime.now();
                                    const months = [
                                      'January', 'February', 'March', 'April', 'May', 'June',
                                      'July', 'August', 'September', 'October', 'November', 'December'
                                    ];
                                    final currentMonthName = "${months[now.month - 1]} ${now.year}";

                                    await pDoc.reference.update({'status': 'approved'});

                                    if (category == 'rent') {
                                      final seatRentRef = FirebaseFirestore.instance
                                          .collection('messes')
                                          .doc(widget.messId)
                                          .collection('seat_rents')
                                          .doc(userId);

                                      final seatSnap = await seatRentRef.get();
                                      double existingPaid = 0.0;
                                      if (seatSnap.exists) {
                                        final data = seatSnap.data() as Map<String, dynamic>;
                                        final paidAmounts = data['paid_amounts'] as Map<dynamic, dynamic>?;
                                        existingPaid = (paidAmounts?[currentMonthName] as num?)?.toDouble() ?? 0.0;
                                      }

                                      await seatRentRef.set({
                                        'paid_amounts': {currentMonthName: existingPaid + amount},
                                        'paid_months': {currentMonthName: (existingPaid + amount) > 0},
                                      }, SetOptions(merge: true));
                                    } else {
                                      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
                                      await userRef.update({
                                        'deposit': FieldValue.increment(amount),
                                      });
                                    }

                                    await AutoNotificationService.sendNotification(
                                      messId: widget.messId,
                                      title: '✅ Payment Approved!',
                                      body: 'Your payment of ৳$amount ($category) has been approved.',
                                      type: 'payment_approved',
                                      senderUid: currentUid,
                                    );

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Payment approved successfully and added to total!')),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to approve payment: $e')),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _processingPaymentIds.remove(pDoc.id));
                                  }
                                },
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
        ],
      ),
    );
  }

  Widget _buildMfsAccountTile(String name, Map<String, dynamic> data, Color color, bool forAdmin, bool canEdit) {
    final phone = data['phone'] ?? '';
    final type = data['type'] ?? 'Personal';
    final bool isMerchant = type.toLowerCase() == 'merchant';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              CircleAvatar(radius: 14, backgroundColor: color.withOpacity(0.15), child: Text(name[0], style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name: ${phone.isEmpty ? "Not Set" : phone}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                    Text('${type.toUpperCase()} (${isMerchant ? "Payment" : "Send Money"})', style: TextStyle(fontSize: 10, color: isMerchant ? Colors.purple : Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (phone.isNotEmpty)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.copy_rounded, size: 12, color: color),
                label: Text('Copy', style: TextStyle(fontSize: 11, color: color)),
                onPressed: () => _handlePaymentAction(mfsName: name, mfsData: data, amountStr: ''),
              ),
            if (canEdit) ...[
              const SizedBox(width: 6),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF1976D2)),
                onPressed: () => _showEditSpecificMfsDialog(forAdmin: forAdmin, mfsName: name, currentMfsData: data),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

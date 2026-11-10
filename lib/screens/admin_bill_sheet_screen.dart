import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBillSheetScreen extends StatefulWidget {
  final String messId;
  const AdminBillSheetScreen({super.key, required this.messId});

  @override
  State<AdminBillSheetScreen> createState() => _AdminBillSheetScreenState();
}

class _AdminBillSheetScreenState extends State<AdminBillSheetScreen> {
  
  final TextEditingController _rentCtrl = TextEditingController(text: "18000");
  final TextEditingController _gasCtrl = TextEditingController(text: "1000");
  final TextEditingController _electricCtrl = TextEditingController(text: "1600");
  final TextEditingController _wifiCtrl = TextEditingController(text: "500");
  final TextEditingController _garbageCtrl = TextEditingController(text: "200");

  String _selectedMonth = "October 2026";
  String _activeFormula = '=ROUND(2030+(SUM(\$B\$5:\$B\$8)/9))';

  
  final Map<String, String> _expenseStatus = {
    'House Rent': 'Unpaid',
    'Gas Bill': 'Unpaid',
    'Electricity Bill': 'Unpaid',
    'Wi-Fi Bill': 'Unpaid',
    'Garbage Collection Fee': 'Unpaid',
  };

  
  final Map<String, String> _memberStatus = {};

  double get utilitiesSum {
    double gas = double.tryParse(_gasCtrl.text.trim()) ?? 0;
    double electric = double.tryParse(_electricCtrl.text.trim()) ?? 0;
    double wifi = double.tryParse(_wifiCtrl.text.trim()) ?? 0;
    double garbage = double.tryParse(_garbageCtrl.text.trim()) ?? 0;
    return gas + electric + wifi + garbage;
  }

  double get totalExpense {
    double rent = double.tryParse(_rentCtrl.text.trim()) ?? 0;
    return rent + utilitiesSum;
  }

  void _saveSheetData() async {
    await FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('monthly_sheets')
        .doc(_selectedMonth)
        .set({
      'month': _selectedMonth,
      'houseRent': _rentCtrl.text.trim(),
      'gas': _gasCtrl.text.trim(),
      'electric': _electricCtrl.text.trim(),
      'wifi': _wifiCtrl.text.trim(),
      'garbage': _garbageCtrl.text.trim(),
      'totalExpense': totalExpense,
      'expenseStatus': _expenseStatus,
      'memberStatus': _memberStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sheet data for $_selectedMonth successfully saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            tooltip: 'Save to Cloud',
            onPressed: _saveSheetData,
          ),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.redo, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFC8E6C9),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Text(
                      'MONTHLY EXPENSE SUMMARY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFFFCDD2),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selectedMonth,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18, color: Colors.red),
                      ],
                    ),
                  ),

                  
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade400, width: 0.8),
                    columnWidths: const {
                      0: FlexColumnWidth(2.3),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1.6),
                    },
                    children: [
                      _buildHeaderRow(['Expense', 'Amount (৳)', 'Status']),
                      _buildExpenseInputRow('House Rent', _rentCtrl, 'B4'),
                      _buildExpenseInputRow('Gas Bill', _gasCtrl, 'B5'),
                      _buildExpenseInputRow('Electricity Bill', _electricCtrl, 'B6'),
                      _buildExpenseInputRow('Wi-Fi Bill', _wifiCtrl, 'B7'),
                      _buildExpenseInputRow('Garbage Collection Fee', _garbageCtrl, 'B8'),
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFFFF9C4)),
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                            child: Text(
                              'Total Expense',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                            child: Text(
                              totalExpense.toStringAsFixed(0),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFC8E6C9),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Text(
                      'PAYMENT SUMMARY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('messId', isEqualTo: widget.messId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final members = snapshot.hasData ? snapshot.data!.docs : [];
                      final int totalMembers = members.isEmpty ? 9 : members.length;
                      final double sharedUtilityPerHead = utilitiesSum / totalMembers;

                      return Table(
                        border: TableBorder.all(color: Colors.grey.shade400, width: 0.8),
                        columnWidths: const {
                          0: FlexColumnWidth(2.3),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.6),
                        },
                        children: [
                          _buildHeaderRow(['Name', 'Total Payable (৳)', 'Status']),
                          if (members.isNotEmpty)
                            ...members.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final uid = doc.id;
                              final name = data['name'] ?? 'Member';
                              final double seat = (data['seatRent'] ?? 2030).toDouble();
                              final int totalPayable = (seat + sharedUtilityPerHead).round();
                              final status = _memberStatus[uid] ?? (data['isPaid'] == true ? 'Paid' : 'Unpaid');

                              return _buildMemberRow(uid, name, totalPayable, seat, status, totalMembers);
                            }).toList()
                          else
                            ..._buildFallbackMembers(sharedUtilityPerHead),
                        ],
                      );
                    },
                  ),

                  
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFFFEBEE),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: const Text(
                      'Note: All payments must be completed by the 10th of each month.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          
          Container(
            color: const Color(0xFF1E1E1E),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'fx',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _activeFormula,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF81D4FA),
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  TableRow _buildHeaderRow(List<String> titles) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFD1C4E9)),
      children: titles
          .map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                child: Text(
                  t,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                ),
              ))
          .toList(),
    );
  }

  
  TableRow _buildExpenseInputRow(String title, TextEditingController controller, String cellRef) {
    final status = _expenseStatus[title] ?? 'Unpaid';
    return TableRow(
      children: [
        InkWell(
          onTap: () => setState(() => _activeFormula = '=$cellRef'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: Text(title, style: const TextStyle(fontSize: 13, color: Colors.black)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13, color: Colors.black),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            onTap: () => setState(() => _activeFormula = '=$cellRef'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        _buildStatusCapsule(status, (newStatus) {
          setState(() => _expenseStatus[title] = newStatus);
        }),
      ],
    );
  }

  
  TableRow _buildMemberRow(String uid, String name, int payable, double seat, String status, int totalMembers) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
          child: Text(name, style: const TextStyle(fontSize: 13, color: Colors.black)),
        ),
        InkWell(
          onTap: () {
            setState(() {
              _activeFormula = '=ROUND(${seat.toInt()}+(SUM(\$B\$5:\$B\$8)/$totalMembers))';
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: Text('$payable', style: const TextStyle(fontSize: 13, color: Colors.black)),
          ),
        ),
        _buildStatusCapsule(status, (newStatus) {
          setState(() => _memberStatus[uid] = newStatus);
        }),
      ],
    );
  }

  
  Widget _buildStatusCapsule(String status, Function(String) onChanged) {
    final bool isPaid = status == 'Paid';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 6.0),
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: isPaid ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
          borderRadius: BorderRadius.circular(14),
        ),
        child: PopupMenuButton<String>(
          initialValue: status,
          onSelected: onChanged,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                status,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 14),
            ],
          ),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'Paid', child: Text('Paid', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
            PopupMenuItem(value: 'Unpaid', child: Text('Unpaid', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  
  List<TableRow> _buildFallbackMembers(double sharedUtility) {
    final dummyData = [
      {'name': 'Jahidur Roshid Jisan', 'seat': 2030.0, 'status': 'Unpaid'},
      {'name': 'Mahidur Roshid Lijan', 'seat': 2030.0, 'status': 'Unpaid'},
      {'name': 'Nahid Hasan Sourov', 'seat': 2030.0, 'status': 'Unpaid'},
      {'name': 'Najmul Hasan Nahid', 'seat': 2060.0, 'status': 'Unpaid'},
      {'name': 'Md. Sobuj Ali', 'seat': 2060.0, 'status': 'Paid'},
      {'name': 'Md Mukta Mia', 'seat': 2060.0, 'status': 'Unpaid'},
      {'name': 'Riaj', 'seat': 1912.0, 'status': 'Unpaid'},
      {'name': 'Ami', 'seat': 1912.0, 'status': 'Unpaid'},
      {'name': 'Alhaj', 'seat': 1912.0, 'status': 'Unpaid'},
    ];

    return dummyData.map((d) {
      final seat = d['seat'] as double;
      final int payable = (seat + sharedUtility).round();
      final name = d['name'] as String;
      final status = _memberStatus[name] ?? d['status'] as String;
      return _buildMemberRow(name, name, payable, seat, status, 9);
    }).toList();
  }
}
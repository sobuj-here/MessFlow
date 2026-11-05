import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';

class ExpenseSheetScreen extends StatelessWidget {
  final String messId;
  const ExpenseSheetScreen({super.key, required this.messId});

  double _parseNum(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '')) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _generateAndDownloadPdf(BuildContext context, String monthName, List<Map<String, dynamic>> reportData) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pw_pdf.PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Mess Live Sheet Report - $monthName',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Member', 'Meals', 'Meal Cost', 'Extra', 'Total Cost', 'Deposited', 'Balance'],
                data: reportData.map((row) => [
                  row['name'],
                  row['meals'],
                  row['mealCost'],
                  row['extra'],
                  row['totalCost'],
                  row['deposited'],
                  row['status'],
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pw_pdf.PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: pw_pdf.PdfColor.fromInt(0xFF107C41)),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Mess_Live_Sheet_$monthName.pdf");
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Saved successfully to: ${file.path}')),
        );
      }

      await OpenFile.open(file.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final currentMonthName = "${months[now.month - 1]} ${now.year}";
    final String currentMonthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Mess Live Sheet Table',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF107C41),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('messId', isEqualTo: messId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userDocs = userSnapshot.data?.docs ?? [];
          if (userDocs.isEmpty) {
            return const Center(child: Text('No members found.'));
          }

          final List<String> memberUids = userDocs.map((doc) => doc.id).toList();
          Map<String, String> memberNames = {};
          for (var doc in userDocs) {
            final data = doc.data() as Map<String, dynamic>;
            memberNames[doc.id] = data['name']?.toString() ?? 'Member';
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('messes')
                .doc(messId)
                .collection('bazaars')
                .snapshots(),
            builder: (context, bazaarSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('messes')
                    .doc(messId)
                    .collection('meals')
                    .snapshots(),
                builder: (context, mealSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('messes')
                        .doc(messId)
                        .collection('shared_expenses')
                        .where('month', isEqualTo: currentMonthName)
                        .snapshots(),
                    builder: (context, extraExpenseSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('messes')
                            .doc(messId)
                            .collection('payments')
                            .where('status', isEqualTo: 'approved')
                            .where('category', isEqualTo: 'meal')
                            .snapshots(),
                        builder: (context, paymentSnapshot) {
                          if (bazaarSnapshot.connectionState == ConnectionState.waiting ||
                              mealSnapshot.connectionState == ConnectionState.waiting ||
                              extraExpenseSnapshot.connectionState == ConnectionState.waiting ||
                              paymentSnapshot.connectionState == ConnectionState.waiting ||
                              !bazaarSnapshot.hasData ||
                              !mealSnapshot.hasData ||
                              !extraExpenseSnapshot.hasData ||
                              !paymentSnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF107C41)));
                          }

                          double totalApprovedBazaar = 0.0;
                          Map<String, double> memberBazaarSpent = {for (var uid in memberUids) uid: 0.0};
                          Map<String, double> memberDeposits = {for (var uid in memberUids) uid: 0.0};

                          if (bazaarSnapshot.hasData) {
                            for (var doc in bazaarSnapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final status = (data['status']?.toString() ?? 'approved').toLowerCase().trim();
                              if (status == 'approved') {
                                final amount = _parseNum(data['amount']);
                                totalApprovedBazaar += amount;
                                final uid = data['userId'] as String? ?? '';
                                if (memberBazaarSpent.containsKey(uid)) {
                                  memberBazaarSpent[uid] = (memberBazaarSpent[uid] ?? 0.0) + amount;
                                }
                                if (data['userName'] != null && uid.isNotEmpty) {
                                  memberNames[uid] = data['userName'];
                                }
                              }
                            }
                          }

                          if (paymentSnapshot.hasData) {
                            for (var doc in paymentSnapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final uid = data['userId'] as String? ?? '';
                              final amount = _parseNum(data['amount']);

                              if (memberDeposits.containsKey(uid)) {
                                memberDeposits[uid] = (memberDeposits[uid] ?? 0.0) + amount;
                              }
                              if (data['userName'] != null && uid.isNotEmpty) {
                                memberNames[uid] = data['userName'];
                              }
                            }
                          }

                          double totalMessMeals = 0.0;
                          Map<String, double> memberTotalMeals = {for (var uid in memberUids) uid: 0.0};

                          if (mealSnapshot.hasData) {
                            for (var doc in mealSnapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final uid = data['userUid'] as String? ?? data['userId'] as String? ?? '';
                              
                              final b = _parseNum(data['breakfast']);
                              final l = _parseNum(data['lunch']);
                              final d = _parseNum(data['dinner']);
                              final directTotal = _parseNum(data['total']) > 0 
                                  ? _parseNum(data['total']) 
                                  : (_parseNum(data['count']) > 0 ? _parseNum(data['count']) : (b + l + d));

                              totalMessMeals += directTotal;
                              if (memberTotalMeals.containsKey(uid)) {
                                memberTotalMeals[uid] = (memberTotalMeals[uid] ?? 0.0) + directTotal;
                              } else {
                                for (var mUid in memberUids) {
                                  if (mUid == uid || doc.id == mUid) {
                                    memberTotalMeals[mUid] = (memberTotalMeals[mUid] ?? 0.0) + directTotal;
                                    break;
                                  }
                                }
                              }
                              if (data['userName'] != null) {
                                memberNames[uid] = data['userName'];
                              }
                            }
                          }

                          final double mealRate = totalMessMeals > 0 ? (totalApprovedBazaar / totalMessMeals) : 0.0;

                          double totalExtraExpenses = 0.0;
                          if (extraExpenseSnapshot.hasData) {
                            for (var doc in extraExpenseSnapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final amount = _parseNum(data['totalAmount']) > 0 
                                  ? _parseNum(data['totalAmount']) 
                                  : _parseNum(data['amount']);
                              totalExtraExpenses += amount;
                            }
                          }

                          final double extraPerPerson = memberUids.isNotEmpty ? (totalExtraExpenses / memberUids.length) : 0.0;

                          List<Map<String, dynamic>> reportList = [];
                          for (var uid in memberUids) {
                            final name = memberNames[uid] ?? 'Member';
                            final meals = memberTotalMeals[uid] ?? 0.0;
                            final mealCost = meals * mealRate;
                            final deposited = memberDeposits[uid] ?? 0.0;
                            final totalCost = mealCost + extraPerPerson;
                            final balance = deposited - totalCost;

                            final bool hasRefund = balance > 0;
                            final bool hasDue = balance < 0;
                            final String statusStr = hasRefund 
                                ? 'Refund: ${balance.abs().toStringAsFixed(0)}' 
                                : hasDue 
                                    ? 'Due: ${balance.abs().toStringAsFixed(0)}' 
                                    : 'Settled';

                            reportList.add({
                              'name': name,
                              'meals': meals.toStringAsFixed(1),
                              'mealCost': mealCost.toStringAsFixed(2),
                              'extra': extraPerPerson.toStringAsFixed(2),
                              'totalCost': totalCost.toStringAsFixed(0),
                              'deposited': deposited.toStringAsFixed(0),
                              'status': statusStr,
                            });
                          }

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF107C41),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 45),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.picture_as_pdf_rounded),
                                  label: const Text('Download Live Sheet PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () => _generateAndDownloadPdf(context, currentMonthName, reportList),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Card(
                                    elevation: 2,
                                    color: Theme.of(context).cardColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          headingRowColor: WidgetStateProperty.all(isDark ? Colors.grey.shade800 : const Color(0xFFE8F5E9)),
                                          columns: [
                                            DataColumn(label: Text('Member', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : const Color(0xFF107C41)))),
                                            DataColumn(label: Text('Meals', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
                                            DataColumn(label: Text('Meal Cost', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
                                            DataColumn(label: Text('Extra', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
                                            DataColumn(label: Text('Total Cost', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
                                            DataColumn(label: Text('Deposited', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
                                            DataColumn(label: Text('Status / Balance', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
                                          ],
                                          rows: memberUids.map((uid) {
                                            final name = memberNames[uid] ?? 'Member';
                                            final meals = memberTotalMeals[uid] ?? 0.0;
                                            final mealCost = meals * mealRate;
                                            final deposited = memberDeposits[uid] ?? 0.0;
                                            final totalCost = mealCost + extraPerPerson;
                                            final balance = deposited - totalCost;

                                            final bool hasRefund = balance > 0;
                                            final bool hasDue = balance < 0;
                                            final String statusStr = hasRefund 
                                                ? 'Refund: ৳${balance.abs().toStringAsFixed(0)}' 
                                                : hasDue 
                                                    ? 'Due: ৳${balance.abs().toStringAsFixed(0)}' 
                                                    : 'Settled';

                                            return DataRow(
                                              cells: [
                                                DataCell(Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                                DataCell(Text(meals.toStringAsFixed(1), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                                                DataCell(Text('৳${mealCost.toStringAsFixed(2)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                                                DataCell(Text('৳${extraPerPerson.toStringAsFixed(2)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                                                DataCell(Text('৳${totalCost.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                                DataCell(Text('৳${deposited.toStringAsFixed(0)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                                                DataCell(
                                                  Text(
                                                    statusStr,
                                                    style: TextStyle(
                                                      color: hasRefund ? Colors.green.shade400 : (hasDue ? Colors.red.shade400 : (isDark ? Colors.blue.shade200 : Colors.blueGrey)),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
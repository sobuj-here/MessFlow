import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'live_mess_sheet_screen.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';

class FullMonthMealChartScreen extends StatefulWidget {
  final String messId;

  const FullMonthMealChartScreen({super.key, required this.messId});

  @override
  State<FullMonthMealChartScreen> createState() => _FullMonthMealChartScreenState();
}

class _FullMonthMealChartScreenState extends State<FullMonthMealChartScreen> {
  late DateTime _selectedDate;
  late String _currentMonthKey;
  late int _daysInMonth;
  late String _currentMonthName;

  final List<String> _monthsList = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _updateMonthVariables();
  }

  void _updateMonthVariables() {
    _currentMonthKey = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
    _daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    _currentMonthName = "${_monthsList[_selectedDate.month - 1]} ${_selectedDate.year}";
  }

  void _changeMonth(int increment) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + increment, 1);
      _updateMonthVariables();
    });
  }

  double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val.trim()) ?? 0.0;
    return 0.0;
  }

  Future<void> _generateAndDownloadMealChartPdf(BuildContext context, List<String> memberUids, Map<String, String> memberNames, Map<String, Map<int, double>> memberDailyMeals) async {
    try {
      final pdf = pw.Document();

      List<String> headers = ['Member', for (int i = 1; i <= _daysInMonth; i++) '$i', 'Total'];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pw_pdf.PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Daily Meal Chart Report - $_currentMonthName',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: headers,
                data: memberUids.map((uid) {
                  final name = memberNames[uid] ?? 'Member';
                  double total = 0.0;
                  List<String> rowValues = [name];
                  for (int i = 1; i <= _daysInMonth; i++) {
                    double m = memberDailyMeals[uid]?[i] ?? 0.0;
                    total += m;
                    rowValues.add(m > 0 ? (m % 1 == 0 ? m.toInt().toString() : m.toStringAsFixed(1)) : '-');
                  }
                  rowValues.add(total % 1 == 0 ? total.toInt().toString() : total.toStringAsFixed(1));
                  return rowValues;
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pw_pdf.PdfColors.white, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: pw_pdf.PdfColor.fromInt(0xFF1B5E20)),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 8),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Meal_Chart_Report_$_currentMonthName.pdf");
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meal Chart PDF Saved to: ${file.path}')),
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Daily Meal Chart - $_currentMonthName'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  _currentMonthName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MessHomeDashboardScreen(messId: widget.messId),
                        ),
                      );
                    },
                    child: const Text('Mess Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {},
                    child: const Text('Meal Chart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('messId', isEqualTo: widget.messId).snapshots(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userDocs = userSnap.data?.docs ?? [];
                if (userDocs.isEmpty) {
                  return const Center(child: Text('No members found.'));
                }

                Map<String, String> memberNames = {};
                List<String> memberUids = [];
                for (var doc in userDocs) {
                  memberUids.add(doc.id);
                  final data = doc.data() as Map<String, dynamic>;
                  memberNames[doc.id] = data['name']?.toString() ?? 'Member';
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('messes')
                      .doc(widget.messId)
                      .collection('meals')
                      .snapshots(),
                  builder: (context, mealSnap) {
                    if (mealSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    Map<String, Map<int, double>> memberDailyMeals = {
                      for (var uid in memberUids) uid: {}
                    };

                    for (var doc in mealSnap.data?.docs ?? []) {
                      final data = doc.data() as Map<String, dynamic>;
                      final uid = data['userId']?.toString() ?? '';
                      final dateStr = data['date']?.toString() ?? '';

                      if (dateStr.startsWith(_currentMonthKey)) {
                        final parts = dateStr.split('-');
                        if (parts.length >= 3) {
                          int? day = int.tryParse(parts[2]);
                          if (day != null && memberDailyMeals.containsKey(uid)) {
                            final count = _parseNum(data['count']);
                            memberDailyMeals[uid]![day] = (memberDailyMeals[uid]![day] ?? 0.0) + count;
                          }
                        }
                      }
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            label: const Text('Download Meal Chart PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => _generateAndDownloadMealChartPdf(context, memberUids, memberNames, memberDailyMeals),
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
                                    headingRowHeight: 40,
                                    dataRowMinHeight: 40,
                                    dataRowMaxHeight: 45,
                                    columns: [
                                      DataColumn(
                                        label: Text('Member Name', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : const Color(0xFF1B5E20))),
                                      ),
                                      for (int i = 1; i <= _daysInMonth; i++)
                                        DataColumn(
                                          label: Text('$i', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                                        ),
                                      const DataColumn(
                                        label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                                      ),
                                    ],
                                    rows: memberUids.map((uid) {
                                      final name = memberNames[uid] ?? 'Member';
                                      double memberMonthlyTotal = 0.0;

                                      List<DataCell> cells = [
                                        DataCell(Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                                      ];

                                      for (int i = 1; i <= _daysInMonth; i++) {
                                        double dayMeal = memberDailyMeals[uid]?[i] ?? 0.0;
                                        memberMonthlyTotal += dayMeal;

                                        cells.add(
                                          DataCell(
                                            Text(
                                              dayMeal > 0 ? (dayMeal % 1 == 0 ? dayMeal.toInt().toString() : dayMeal.toStringAsFixed(1)) : '-',
                                              style: TextStyle(
                                                color: dayMeal > 0 ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade500,
                                                fontWeight: dayMeal > 0 ? FontWeight.w500 : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      cells.add(
                                        DataCell(
                                          Text(
                                            memberMonthlyTotal % 1 == 0 ? memberMonthlyTotal.toInt().toString() : memberMonthlyTotal.toStringAsFixed(1),
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                          ),
                                        ),
                                      );

                                      return DataRow(cells: cells);
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
            ),
          ),
        ],
      ),
    );
  }
}
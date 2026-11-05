import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MealScreen extends StatefulWidget {
  final String messId;
  final bool isManager; // Admin ও Manager উভয়ের ক্ষেত্রে true

  const MealScreen({
    super.key,
    required this.messId,
    required this.isManager,
  });

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String get _formattedDate {
    final y = _selectedDate.year;
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _shiftDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  // মিল আপডেট করার ফাংশন (শুধু Admin ও Manager অনুমতি পাবেন)
  Future<void> _updateMeal(String memberId, double newCount, {String? memberName}) async {
    if (!widget.isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Admin and Manager can edit meals!')),
      );
      return;
    }

    if (newCount < 0) return;

    final docRef = FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('meals')
        .doc('${_formattedDate}_$memberId');

    if (newCount == 0) {
      await docRef.delete();
    } else {
      await docRef.set({
        'date': _formattedDate,
        'userId': memberId,
        'userName': memberName ?? '',
        'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'count': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Daily Meals Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // তারিখ সিলেকশন বার
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                  color: const Color(0xFF1B5E20),
                  tooltip: 'Previous Day',
                  onPressed: () => _shiftDate(-1),
                ),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: Color(0xFF1B5E20), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _formattedDate,
                          style: const TextStyle(
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1B5E20), size: 18),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  color: const Color(0xFF1B5E20),
                  tooltip: 'Next Day',
                  onPressed: () => _shiftDate(1),
                ),
              ],
            ),
          ),

          // মোট মিল ও সদস্য তালিকা
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('messId', isEqualTo: widget.messId)
                  .snapshots(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)));
                }

                final members = userSnap.data?.docs ?? [];
                if (members.isEmpty) {
                  return const Center(
                    child: Text('No members found in this mess.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('messes')
                      .doc(widget.messId)
                      .collection('meals')
                      .where('date', isEqualTo: _formattedDate)
                      .snapshots(),
                  builder: (context, mealSnap) {
                    final mealDocs = mealSnap.data?.docs ?? [];
                    final Map<String, double> mealCountMap = {};
                    double dayTotalMeals = 0.0;

                    for (var doc in mealDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final uid = data['userId'] ?? '';
                      final count = (data['count'] as num?)?.toDouble() ?? 0.0;
                      mealCountMap[uid] = count;
                      dayTotalMeals += count;
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // মোট মিল সামারি কার্ড
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TOTAL MEALS TODAY',
                                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${dayTotalMeals.toStringAsFixed(1)} Meals',
                                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 28),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Members Daily Count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            if (!widget.isManager)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('View Only', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // মেম্বারদের কার্ড
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: members.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final mData = members[index].data() as Map<String, dynamic>;
                            final String uid = members[index].id;
                            final String name = mData['name'] ?? 'Member';
                            final String photoUrl = mData['photoUrl'] ?? '';
                            final double currentCount = mealCountMap[uid] ?? 0.0;

                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 1.5,
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: const Color(0xFFE8F5E9),
                                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                          child: photoUrl.isEmpty
                                              ? Text(
                                                  name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                                  style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 16),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),

                                        // ম্যানেজার/অ্যাডমিনের জন্য সক্রিয় কন্ট্রোলার, মেম্বারের জন্য লকড
                                        if (widget.isManager)
                                          Row(
                                            children: [
                                              InkWell(
                                                onTap: () => _updateMeal(uid, currentCount - 0.5, memberName: name),
                                                borderRadius: BorderRadius.circular(20),
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.red.shade200),
                                                  ),
                                                  child: const Icon(Icons.remove, color: Colors.red, size: 18),
                                                ),
                                              ),
                                              Container(
                                                width: 50,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  currentCount.toStringAsFixed(1),
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => _updateMeal(uid, currentCount + 0.5, memberName: name),
                                                borderRadius: BorderRadius.circular(20),
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.green.shade200),
                                                  ),
                                                  child: const Icon(Icons.add, color: Color(0xFF1B5E20), size: 18),
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F5E9),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '${currentCount.toStringAsFixed(1)} Meals',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20), fontSize: 14),
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Quick Select অপশন শুধু Admin/Manager-দের দেখাবে
                                    if (widget.isManager) ...[
                                      const SizedBox(height: 10),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Quick Select:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          Row(
                                            children: [0.0, 1.0, 2.0, 3.0].map((quickVal) {
                                              final isSelected = currentCount == quickVal;
                                              return Padding(
                                                padding: const EdgeInsets.only(left: 6.0),
                                                child: InkWell(
                                                  onTap: () => _updateMeal(uid, quickVal, memberName: name),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      quickVal.toInt().toString(),
                                                      style: TextStyle(
                                                        color: isSelected ? Colors.white : Colors.black87,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

class ManagerBalanceWidget extends StatelessWidget {
  final String messId;

  const ManagerBalanceWidget({super.key, required this.messId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messes')
          .doc(messId)
          .collection('payments')
          .where('category', isEqualTo: 'meal')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, paymentSnap) {
        double totalReceived = 0.0;
        if (paymentSnap.hasData) {
          for (final doc in paymentSnap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final amount = data['amount'];
            if (amount is num) {
              totalReceived += amount.toDouble();
            } else if (amount is String) {
              totalReceived += double.tryParse(amount.replaceAll(',', '').trim()) ?? 0.0;
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('messes')
              .doc(messId)
              .collection('bazaars')
              .snapshots(),
          builder: (context, bazaarSnap) {
            double totalBazaarCost = 0.0;
            if (bazaarSnap.hasData) {
              for (final doc in bazaarSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final status = (data['status']?.toString() ?? 'approved').toLowerCase().trim();
                if (status == 'approved') {
                  final amount = data['amount'];
                  if (amount is num) {
                    totalBazaarCost += amount.toDouble();
                  } else if (amount is String) {
                    totalBazaarCost += double.tryParse(amount.replaceAll(',', '').trim()) ?? 0.0;
                  }
                }
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messes')
                  .doc(messId)
                  .collection('shared_expenses')
                  .snapshots(),
              builder: (context, extraExpenseSnap) {
                double totalExtraExpense = 0.0;
                if (extraExpenseSnap.hasData) {
                  for (final doc in extraExpenseSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final amount = data['totalAmount'] ?? data['amount'];
                    if (amount is num) {
                      totalExtraExpense += amount.toDouble();
                    } else if (amount is String) {
                      totalExtraExpense += double.tryParse(amount.replaceAll(',', '').trim()) ?? 0.0;
                    }
                  }
                }

                if (paymentSnap.connectionState == ConnectionState.waiting ||
                    bazaarSnap.connectionState == ConnectionState.waiting ||
                    extraExpenseSnap.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF1B5E20), size: 22),
                            const SizedBox(width: 10),
                            const Text(
                              'Manager Fund Balance',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20)),
                            ).tr(),
                          ],
                        ),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B5E20)),
                        ),
                      ],
                    ),
                  );
                }

                final double remainingBalance = totalReceived - (totalBazaarCost + totalExtraExpense);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF1B5E20), size: 22),
                          const SizedBox(width: 10),
                          const Text(
                            'Manager Fund Balance',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20)),
                          ).tr(),
                        ],
                      ),
                      Text(
                        '৳${remainingBalance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: remainingBalance >= 0 ? const Color(0xFF1B5E20) : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

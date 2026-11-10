import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

class ManagerBalanceWidget extends StatelessWidget {
  final String messId;

  const ManagerBalanceWidget({super.key, required this.messId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

                final bool isLoading = paymentSnap.connectionState == ConnectionState.waiting ||
                    bazaarSnap.connectionState == ConnectionState.waiting ||
                    extraExpenseSnap.connectionState == ConnectionState.waiting;

                final double remainingBalance = totalReceived - (totalBazaarCost + totalExtraExpense);
                final bool isPositive = remainingBalance >= 0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: (isPositive ? const Color(0xFF1B5E20) : Colors.red)
                                  .withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: isPositive ? const Color(0xFF2E7D32) : Colors.redAccent,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Manager Fund Balance'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      if (isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B5E20)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isPositive ? const Color(0xFF1B5E20) : Colors.red)
                                .withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '৳${remainingBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.3,
                              color: isPositive ? const Color(0xFF2E7D32) : Colors.redAccent,
                            ),
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

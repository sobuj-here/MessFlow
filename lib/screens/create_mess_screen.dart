import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class CreateMessScreen extends StatefulWidget {
  const CreateMessScreen({super.key});

  @override
  State<CreateMessScreen> createState() => _CreateMessScreenState();
}

class _CreateMessScreenState extends State<CreateMessScreen> {
  final TextEditingController _messNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _rentController = TextEditingController();

  bool _isLoading = false;

  String _generateMessCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _handleCreateMess() async {
    if (_isLoading) return;

    final messName = _messNameController.text.trim();
    final address = _addressController.text.trim();
    final rentText = _rentController.text.trim();

    final defaultRent = rentText.isEmpty ? 0.0 : double.tryParse(rentText);
    final user = FirebaseAuth.instance.currentUser;

    if (messName.isEmpty) {
      _showMessage('Please enter mess name');
      return;
    }

    if (defaultRent == null || defaultRent < 0) {
      _showMessage('Please enter a valid monthly rent');
      return;
    }

    if (user == null) {
      _showMessage('Please login first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final messDocRef = firestore.collection('messes').doc();
      final String messId = messDocRef.id;

      if (messId.isEmpty) {
        _showMessage('Failed to generate Mess ID');
        return;
      }

      final messCode = _generateMessCode();
      final batch = firestore.batch();

      batch.set(messDocRef, {
        'messId': messId,
        'name': messName,
        'address': address,
        'inviteCode': messCode,
        'adminUid': user.uid,
        'managerUid': user.uid,
        'members': [user.uid],
        'totalBazaarCost': 0.0,
        'totalMeals': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final userDocRef = firestore.collection('users').doc(user.uid);
      batch.set(
        userDocRef,
        {
          'uid': user.uid,
          'name': user.displayName ?? 'Admin',
          'email': user.email ?? '',
          'messId': messId,
          'role': 'admin',
          'status': 'active',
          'seatRent': defaultRent,
          'isPaid': false,
          'deposit': 0.0,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(messId: messId)),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        _showMessage('Error creating mess: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _messNameController.dispose();
    _addressController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create New Mess'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: Color(0xFF1B5E20), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'As the creator, you will automatically become the Mess Admin.',
                      style: TextStyle(color: Colors.green.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _messNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Mess Name',
                hintText: 'e.g., Green Valley Villa',
                prefixIcon: const Icon(Icons.home_work_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Location / Address',
                hintText: 'e.g., Road 12, Dhanmondi',
                prefixIcon: const Icon(Icons.place_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Default Monthly Seat Rent (৳)',
                hintText: 'e.g., 2000',
                prefixIcon: const Icon(Icons.attach_money_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _handleCreateMess,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Create & Initialize Mess',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

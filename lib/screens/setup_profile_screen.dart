import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'home_screen.dart';
import 'join_mess_screen.dart';

class SetupProfileScreen extends StatefulWidget {
  final String messId; 
  const SetupProfileScreen({super.key, required this.messId}); 

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late final TextEditingController _nameController;
  final TextEditingController _phoneController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: currentUser?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }

    if (phone.isEmpty || phone.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a valid 11-digit mobile number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String photoUrl = currentUser?.photoURL ?? '';

      if (_selectedImage != null && currentUser != null) {
        final ref = FirebaseStorage.instance.ref().child('user_photos').child('${currentUser!.uid}.jpg');
        await ref.putFile(_selectedImage!);
        photoUrl = await ref.getDownloadURL();
        await currentUser!.updatePhotoURL(photoUrl);
      }

      await currentUser?.updateDisplayName(name);

      if (currentUser != null) {
        final existingDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
        final existingData = existingDoc.data() ?? {};

        Map<String, dynamic> updateData = {
          'uid': currentUser!.uid,
          'name': name,
          'email': currentUser!.email ?? '',
          'phone': phone,
          'photoUrl': photoUrl,
        };

        if (!existingDoc.exists || !existingData.containsKey('role')) {
          updateData['role'] = 'member';
        }
        if (!existingDoc.exists || !existingData.containsKey('messId')) {
          updateData['messId'] = widget.messId;
        }
        if (!existingDoc.exists || !existingData.containsKey('status')) {
          updateData['status'] = widget.messId.isNotEmpty ? 'approved' : '';
        }
        if (!existingDoc.exists) {
          updateData['createdAt'] = FieldValue.serverTimestamp();
          updateData['seatRent'] = 0.0;
          updateData['isPaid'] = false;
          updateData['deposit'] = 0.0;
        }

        await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set(updateData, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => widget.messId.isNotEmpty
                ? HomeScreen(messId: widget.messId)
                : const JoinMessScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (currentUser?.photoURL != null && currentUser!.photoURL!.isNotEmpty)
                            ? NetworkImage(currentUser!.photoURL!) as ImageProvider
                            : null,
                    child: (_selectedImage == null && (currentUser?.photoURL == null || currentUser!.photoURL!.isEmpty))
                        ? const Icon(Icons.person, size: 55, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: InkWell(
                      onTap: _pickImage,
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF1877F2),
                        child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Change Profile Picture',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 28),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              readOnly: true,
              controller: TextEditingController(text: currentUser?.email ?? ''),
              decoration: InputDecoration(
                labelText: 'Verified Google Email',
                prefixIcon: const Icon(Icons.verified, color: Colors.green),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Number (e.g. 017xxxxxxxx)',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Confirm & Enter MessFlow',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
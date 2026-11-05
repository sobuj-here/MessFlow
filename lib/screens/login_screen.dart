import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'setup_profile_screen.dart';
import 'join_mess_screen.dart';
import 'waiting_approval_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/permission_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppPermissionService.checkAndRequestInitialPermissions(context);
    });
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final userCredential = await AuthService.signInWithGoogle();
      if (userCredential != null && userCredential.user != null && mounted) {
        final uid = userCredential.user!.uid;
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
        
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          await userDocRef.set({
            'uid': uid,
            'name': userCredential.user!.displayName ?? 'Member',
            'email': userCredential.user!.email ?? '',
            'phone': '',
            'messId': '',
            'role': 'member',
            'status': '',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SetupProfileScreen(messId: '')),
          );
          return;
        }

        final data = userDoc.data() ?? {};
        final String messId = data['messId']?.toString().trim() ?? '';
        final String phone = data['phone']?.toString().trim() ?? '';
        final String status = data['status']?.toString().trim() ?? '';

        if (!mounted) return;

        // 🌟 Safe Routing Logic: Prothom e phone check korbe, tarpor messId ebong pending status
        if (phone.isEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SetupProfileScreen(messId: messId)),
          );
        } else if (messId.isEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const JoinMessScreen()),
          );
        } else if (status == 'pending') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const WaitingApprovalScreen()),
          );
        } else {
          // 🌟 MessId thakle ebong active holeiHomeScreen-e pathabe
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(messId: messId)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9),
              Color(0xFFF8FAFC),
              Colors.white,
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Center(
                  child: Container(
                    height: 105,
                    width: 105,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B5E20).withValues(alpha: 0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF1B5E20),
                        size: 50,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'MessFlow',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Smart & Transparent Mess Management',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow(
                        icon: Icons.auto_graph_rounded,
                        text: 'Live Meal Rate & Instant Audit Sheets',
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureRow(
                        icon: Icons.qr_code_2_rounded,
                        text: 'Secure QR Payments Without Exposing Mobile Numbers',
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureRow(
                        icon: Icons.diversity_3_rounded,
                        text: 'Equal Splitting for Utilities & Shared Bills',
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFF1B5E20),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                height: 22,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.g_mobiledata,
                                  size: 32,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                    SizedBox(width: 6),
                    Text(
                      'End-to-end verified via Google Auth',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF1B5E20), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}
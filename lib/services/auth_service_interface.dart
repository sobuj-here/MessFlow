import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthServiceInterface {
  Stream<User?> get authStateChanges;

  User? get currentUser;

  Future<UserCredential?> signInWithGoogle();

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    File? profileImage,
  });

  Future<void> sendPasswordResetEmail({
    required String email,
  });

  Future<void> resetPassword({
    required String email,
  });

  Future<void> signOut();
}
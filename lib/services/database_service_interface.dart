import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class DatabaseServiceInterface {
  
  Future<String> createMess({required String messName, required String creatorUid});
  Future<bool> joinMess({required String messCode, required String userUid});

  
  Future<void> addBazaarBatch({
    required String messId,
    required String userUid,
    required String userName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required DateTime date,
  });

  Future<void> updateBazaarStatus({
    required String messId,
    required String bazaarId,
    required String status,
  });

  Future<void> updateBazaarEntry({
    required String messId,
    required String bazaarId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  });

  Stream<List<Map<String, dynamic>>> getBazaarList(String messId);

  
  Future<void> sendChatMessage({
    required String messId,
    required String senderUid,
    required String senderName,
    String? text,
    File? mediaFile,
    String? mediaType,
  });

  Future<void> editChatMessage({
    required String messId,
    required String messageId,
    required String newText,
  });

  Future<void> reactToMessage({
    required String messId,
    required String messageId,
    required String userUid,
    required String reaction,
  });

  Stream<List<Map<String, dynamic>>> getMessages(String messId);

  
  Future<void> updateMemberMeal({
    required String messId,
    required String userUid,
    required String userName,
    required String dateId,
    required double breakfast,
    required double lunch,
    required double dinner,
  });

  Stream<List<Map<String, dynamic>>> getMonthlyMeals(String messId);

  
  Future<void> setIndividualRent({
    required String messId,
    required String userUid,
    required double rentAmount,
  });

  Future<void> saveSharedUtilities({
    required String messId,
    required double electricity,
    required double gas,
    required double wifi,
    required double khalaBill,
    required double otherBill,
  });

  Stream<DocumentSnapshot> getMessUtilities(String messId);

  
  Future<void> savePaymentDetails({
    required String messId,
    required String paymentType,
    required String paymentPayload,
  });

  Future<void> submitPaymentRequest({
    required String messId,
    required String userUid,
    required String userName,
    required double amount,
    required String trxId,
  });

  Future<void> approvePaymentRequest({
    required String messId,
    required String paymentId,
  });

  Stream<DocumentSnapshot> getPaymentConfig(String messId);
  Stream<List<Map<String, dynamic>>> getPendingPayments(String messId);

  
  Future<void> closeCurrentMonthAndArchive({
    required String messId,
    required String monthYearName,
    required Map<String, dynamic> summarySnapshot,
  });

  Stream<List<Map<String, dynamic>>> getMonthHistory(String messId);

  
  Future<void> transferManagerRole({
    required String messId,
    required String currentManagerUid,
    required String newManagerUid,
  });

  
  Future<void> sendInAppNotification({
    required String messId,
    required String title,
    required String body,
  });

  Stream<List<Map<String, dynamic>>> getNotifications(String messId);
}

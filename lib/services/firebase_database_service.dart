import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'database_service_interface.dart';
import 'auto_notification_service.dart';

class FirebaseDatabaseService implements DatabaseServiceInterface {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Future<String> createMess({required String messName, required String creatorUid}) async {
    if (messName.trim().isEmpty || creatorUid.trim().isEmpty) {
      throw Exception('Mess name and Creator UID cannot be empty');
    }

    DocumentReference docRef = await _firestore.collection('messes').add({
      'name': messName,
      'managerUid': creatorUid,
      'members': [creatorUid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(creatorUid).update({
      'messId': docRef.id,
      'role': 'manager',
    });

    return docRef.id;
  }

  @override
  Future<bool> joinMess({required String messCode, required String userUid}) async {
    if (messCode.trim().isEmpty || userUid.trim().isEmpty) return false;

    DocumentReference messRef = _firestore.collection('messes').doc(messCode);
    DocumentSnapshot snap = await messRef.get();

    if (snap.exists) {
      await messRef.update({
        'members': FieldValue.arrayUnion([userUid]),
      });
      await _firestore.collection('users').doc(userUid).update({
        'messId': messCode,
        'role': 'member',
      });
      return true;
    }
    return false;
  }

  @override
  Future<void> addBazaarBatch({
    required String messId,
    required String userUid,
    required String userName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required DateTime date,
  }) async {
    if (messId.trim().isEmpty) return;

    await _firestore.collection('messes').doc(messId).collection('bazaar').add({
      'userUid': userUid,
      'userName': userName,
      'items': items,
      'totalAmount': totalAmount,
      'status': 'pending',
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await sendInAppNotification(
      messId: messId,
      title: 'Notun bajar khoroch joma hoyeche',
      body: '$userName ৳$totalAmount takar bajar joma diyecheen (অনুমোদনের অপেক্ষায়)।',
    );
  }

  @override
  Future<void> updateBazaarStatus({
    required String messId,
    required String bazaarId,
    required String status,
  }) async {
    if (messId.trim().isEmpty || bazaarId.trim().isEmpty) return;

    await _firestore
        .collection('messes')
        .doc(messId)
        .collection('bazaar')
        .doc(bazaarId)
        .update({'status': status});
  }

  @override
  Future<void> updateBazaarEntry({
    required String messId,
    required String bazaarId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    if (messId.trim().isEmpty || bazaarId.trim().isEmpty) return;

    await _firestore
        .collection('messes')
        .doc(messId)
        .collection('bazaar')
        .doc(bazaarId)
        .update({
      'items': items,
      'totalAmount': totalAmount,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> getBazaarList(String messId) {
    if (messId.trim().isEmpty) return Stream.value([]);

    return _firestore
        .collection('messes')
        .doc(messId)
        .collection('bazaar')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  @override
  Future<void> sendChatMessage({
    required String messId,
    required String senderUid,
    required String senderName,
    String? text,
    File? mediaFile,
    String? mediaType,
  }) async {
    if (messId.trim().isEmpty) return;

    String? mediaUrl;

    if (mediaFile != null) {
      String ext = mediaType == 'video' ? 'mp4' : 'jpg';
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      Reference ref = _storage.ref().child('mess_media/$messId/$fileName');
      UploadTask task = ref.putFile(mediaFile);
      TaskSnapshot snapshot = await task;
      mediaUrl = await snapshot.ref.getDownloadURL();
    }

    await _firestore.collection('messes').doc(messId).collection('chats').add({
      'senderUid': senderUid,
      'senderName': senderName,
      'text': text ?? '',
      'mediaUrl': mediaUrl ?? '',
      'mediaType': mediaType ?? 'text',
      'isEdited': false,
      'reactions': {},
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> editChatMessage({
    required String messId,
    required String messageId,
    required String newText,
  }) async {
    if (messId.trim().isEmpty || messageId.trim().isEmpty) return;

    await _firestore
        .collection('messes')
        .doc(messId)
        .collection('chats')
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true,
    });
  }

  @override
  Future<void> reactToMessage({
    required String messId,
    required String messageId,
    required String userUid,
    required String reaction,
  }) async {
    if (messId.trim().isEmpty || messageId.trim().isEmpty) return;

    DocumentReference docRef = _firestore
        .collection('messes')
        .doc(messId)
        .collection('chats')
        .doc(messageId);

    DocumentSnapshot snap = await docRef.get();
    if (snap.exists) {
      Map<String, dynamic> reactions = Map<String, dynamic>.from(snap.get('reactions') ?? {});
      if (reactions[userUid] == reaction) {
        reactions.remove(userUid);
      } else {
        reactions[userUid] = reaction;
      }
      await docRef.update({'reactions': reactions});
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> getMessages(String messId) {
    if (messId.trim().isEmpty) return Stream.value([]);

    return _firestore
        .collection('messes')
        .doc(messId)
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  @override
  Future<void> updateMemberMeal({
    required String messId,
    required String userUid,
    required String userName,
    required String dateId,
    required double breakfast,
    required double lunch,
    required double dinner,
  }) async {
    if (messId.trim().isEmpty || userUid.trim().isEmpty) return;

    await _firestore
        .collection('messes')
        .doc(messId)
        .collection('meals')
        .doc('${userUid}_$dateId')
        .set({
      'userUid': userUid,
      'userName': userName,
      'dateString': dateId,
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'total': breakfast + lunch + dinner,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<List<Map<String, dynamic>>> getMonthlyMeals(String messId) {
    if (messId.trim().isEmpty) return Stream.value([]);

    return _firestore
        .collection('messes')
        .doc(messId)
        .collection('meals')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  @override
  Future<void> setIndividualRent({
    required String messId,
    required String userUid,
    required double rentAmount,
  }) async {
    if (messId.trim().isEmpty || userUid.trim().isEmpty) return;

    await _firestore
        .collection('messes')
        .doc(messId)
        .collection('custom_rents')
        .doc(userUid)
        .set({
      'rent': rentAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveSharedUtilities({
    required String messId,
    required double electricity,
    required double gas,
    required double wifi,
    required double khalaBill,
    required double otherBill,
  }) async {
    if (messId.trim().isEmpty) return;

    await _firestore
        .collection('messes')
        .doc(messId)
        .collection('utilities')
        .doc('current_month')
        .set({
      'electricity': electricity,
      'gas': gas,
      'wifi': wifi,
      'khalaBill': khalaBill,
      'otherBill': otherBill,
      'totalUtility': electricity + gas + wifi + khalaBill + otherBill,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<DocumentSnapshot> getMessUtilities(String messId) {
    if (messId.trim().isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection('messes')
        .doc(messId)
        .collection('utilities')
        .doc('current_month')
        .snapshots();
  }

  @override
  Future<void> savePaymentDetails({
    required String messId,
    required String paymentType,
    required String paymentPayload,
  }) async {
    if (messId.trim().isEmpty) return;

    await _firestore
        .collection('messes')
        .doc(messId)
        .collection('config')
        .doc('payment')
        .set({
      'type': paymentType,
      'payload': paymentPayload,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> submitPaymentRequest({
    required String messId,
    required String userUid,
    required String userName,
    required double amount,
    required String trxId,
  }) async {
    if (messId.trim().isEmpty) return;

    await _firestore.collection('messes').doc(messId).collection('payments').add({
      'userUid': userUid,
      'userName': userName,
      'amount': amount,
      'trxId': trxId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await sendInAppNotification(
      messId: messId,
      title: 'Payment request',
      body: '$userName ৳$amount takar TrxID: $trxId joma diyecheen.',
    );
  }

  @override
  Future<void> approvePaymentRequest({
    required String messId,
    required String paymentId,
  }) async {
    if (messId.trim().isEmpty || paymentId.trim().isEmpty) return;

    await _firestore
        .collection('messes')
        .doc(messId)
        .collection('payments')
        .doc(paymentId)
        .update({'status': 'approved'});
  }

  @override
  Stream<DocumentSnapshot> getPaymentConfig(String messId) {
    if (messId.trim().isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection('messes')
        .doc(messId)
        .collection('config')
        .doc('payment')
        .snapshots();
  }

  @override
  Stream<List<Map<String, dynamic>>> getPendingPayments(String messId) {
    if (messId.trim().isEmpty) return Stream.value([]);

    return _firestore
        .collection('messes')
        .doc(messId)
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  @override
  Future<void> closeCurrentMonthAndArchive({
    required String messId,
    required String monthYearName,
    required Map<String, dynamic> summarySnapshot,
  }) async {
    if (messId.trim().isEmpty) return;

    final messRef = _firestore.collection('messes').doc(messId);

    await messRef.collection('month_history').add({
      'monthYear': monthYearName,
      'closedAt': FieldValue.serverTimestamp(),
      'summary': summarySnapshot,
    });

    final bzDocs = await messRef.collection('bazaar').get();
    for (var doc in bzDocs.docs) {
      await doc.reference.delete();
    }

    final mealDocs = await messRef.collection('meals').get();
    for (var doc in mealDocs.docs) {
      await doc.reference.delete();
    }

    final payDocs = await messRef.collection('payments').get();
    for (var doc in payDocs.docs) {
      await doc.reference.delete();
    }

    await sendInAppNotification(
      messId: messId,
      title: 'Notun mas shuru hoyeche',
      body: '$monthYearName er hisab archive e songrokhito hoyeche.',
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> getMonthHistory(String messId) {
    if (messId.trim().isEmpty) return Stream.value([]);

    return _firestore
        .collection('messes')
        .doc(messId)
        .collection('month_history')
        .orderBy('closedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  @override
  Future<void> transferManagerRole({
    required String messId,
    required String currentManagerUid,
    required String newManagerUid,
  }) async {
    if (messId.trim().isEmpty) return;

    final batch = _firestore.batch();

    batch.update(_firestore.collection('messes').doc(messId), {
      'managerUid': newManagerUid,
    });

    if (currentManagerUid.trim().isNotEmpty) {
      batch.update(_firestore.collection('users').doc(currentManagerUid), {'role': 'member'});
    }
    if (newManagerUid.trim().isNotEmpty) {
      batch.update(_firestore.collection('users').doc(newManagerUid), {'role': 'manager'});
    }

    await batch.commit();

    await sendInAppNotification(
      messId: messId,
      title: 'Manager poriborton',
      body: 'Meser notun manager er dayitto hostantor somponno hoyeche.',
    );
  }

  @override
  Future<void> sendInAppNotification({
    required String messId,
    required String title,
    required String body,
  }) async {
    if (messId.trim().isEmpty) return;

    await AutoNotificationService.sendNotification(
      messId: messId,
      title: title,
      body: body,
      type: 'notice',
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> getNotifications(String messId) {
    if (messId.trim().isEmpty) return Stream.value([]);

    return _firestore
        .collection('messes')
        .doc(messId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }
}
import 'auto_notification_service.dart';

class NotificationService {
  /// Unified notification dispatch proxy
  static Future<void> send({
    required String messId,
    required String title,
    required String body,
    required String type,
    String? senderUid,
    String? targetUid,
    String? targetRole,
  }) async {
    await AutoNotificationService.sendNotification(
      messId: messId,
      title: title,
      body: body,
      type: type,
      senderUid: senderUid,
      targetUid: targetUid,
      targetRole: targetRole,
    );
  }
}

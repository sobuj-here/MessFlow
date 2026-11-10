const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Dispatches high-priority push notification for new mess activity.
 */
exports.sendPushOnNewNotification = functions.firestore
  .document("messes/{messId}/notifications/{notifId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const messId = context.params.messId;
    const title = data.title || "MessFlow Alert";
    const body = data.body || "You have a new update in your mess.";
    const type = data.type || "notice";
    const targetUid = data.targetUid || "";
    const senderUid = data.senderUid || "";

    // Dispatch to targeted member topic or broadcast to entire mess
    const topic = targetUid ? `user_${targetUid}` : `mess_${messId}`;

    const message = {
      topic: topic,
      notification: {
        title: title,
        body: body,
      },
      data: {
        messId: messId,
        type: type,
        senderUid: senderUid,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: type.includes("chat")
            ? "mess_chat_channel"
            : type.includes("meal")
            ? "mess_meal_channel"
            : type.includes("payment") || type.includes("bazaar")
            ? "mess_payment_channel"
            : "mess_notice_channel",
          sound: "default",
          priority: "high",
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log(`Successfully sent notification to topic ${topic}:`, response);
      return response;
    } catch (error) {
      console.error("Error sending push notification:", error);
      return null;
    }
  });

/**
 * Dispatches push notification for incoming group chat messages.
 */
exports.sendPushOnNewChatMessage = functions.firestore
  .document("messes/{messId}/group_chats/{chatId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const messId = context.params.messId;
    const senderName = data.senderName || "Roommate";
    const senderId = data.senderId || "";
    const text = data.text || "";
    const mediaType = data.mediaType || "";

    const body = text.length > 0 
      ? text 
      : (mediaType ? `Sent an attachment (${mediaType})` : "New message");

    const message = {
      topic: `mess_${messId}`,
      notification: {
        title: `${senderName} (Group Chat)`,
        body: body,
      },
      data: {
        messId: messId,
        type: "chat",
        senderUid: senderId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "mess_chat_channel",
          sound: "default",
          priority: "high",
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log(`Successfully sent chat push to mess_${messId}:`, response);
      return response;
    } catch (error) {
      console.error("Error sending chat push notification:", error);
      return null;
    }
  });

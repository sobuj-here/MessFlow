import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/auto_notification_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String messId;

  const GroupChatScreen({super.key, required this.messId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  Map<String, dynamic>? _replyingToMessage;
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    AutoNotificationService.isChatScreenActive = true;
    _markMessagesAsSeen();
  }

  @override
  void dispose() {
    AutoNotificationService.isChatScreenActive = false;
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsSeen() async {
    if (currentUid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
    final String photoUrl = userDoc.data()?['photoUrl'] ?? '';
    final String name = userDoc.data()?['name'] ?? 'Member';

    final unreadQuery = await FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('group_chats')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    bool hasUpdates = false;
    for (var doc in unreadQuery.docs) {
      final data = doc.data();
      final List seenBy = data['seenBy'] ?? [];
      final bool alreadySeen = seenBy.any((element) => element is Map && element['uid'] == currentUid);

      if (!alreadySeen) {
        hasUpdates = true;
        batch.update(doc.reference, {
          'seenBy': FieldValue.arrayUnion([
            {
              'uid': currentUid,
              'name': name,
              'photoUrl': photoUrl,
            }
          ]),
          'readByUids': FieldValue.arrayUnion([currentUid]),
        });
      }
    }
    if (hasUpdates) {
      await batch.commit();
    }
  }

  String _getTodayDateKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<bool> _checkAndUpdateDailyLimit({bool isImage = false, bool isVideo = false, bool isDoc = false}) async {
    if (currentUid == null) return false;
    final todayKey = _getTodayDateKey();

    final userLimitRef = FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('chat_limits')
        .doc('${currentUid}_$todayKey');

    return await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userLimitRef);

      int chatCount = 0;
      int imageCount = 0;
      int videoCount = 0;
      int docCount = 0;

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        chatCount = data['chatCount'] ?? 0;
        imageCount = data['imageCount'] ?? 0;
        videoCount = data['videoCount'] ?? 0;
        docCount = data['docCount'] ?? 0;
      }

      if (!isImage && !isVideo && !isDoc && chatCount >= 50) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Daily limit reached! You can only send 50 messages per day.')),
          );
        }
        return false;
      }

      if (isImage && imageCount >= 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Daily limit reached! You can only upload 2 photos per day.')),
          );
        }
        return false;
      }

      if (isVideo && videoCount >= 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Daily limit reached! You can only upload 1 video per day.')),
          );
        }
        return false;
      }

      if (isDoc && docCount >= 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Daily limit reached! You can only upload 2 documents per day.')),
          );
        }
        return false;
      }

      transaction.set(userLimitRef, {
        'chatCount': (isImage || isVideo || isDoc) ? chatCount : chatCount + 1,
        'imageCount': isImage ? imageCount + 1 : imageCount,
        'videoCount': isVideo ? videoCount + 1 : videoCount,
        'docCount': isDoc ? docCount + 1 : docCount,
        'date': todayKey,
      }, SetOptions(merge: true));

      return true;
    });
  }

  Future<void> _openOrDownloadFile(String url, String fileName) async {
    try {
      if (io.Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          await Permission.manageExternalStorage.request();
        }
      }

      final outputDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final cleanFileName = fileName.isNotEmpty ? fileName : 'downloaded_file';
      final savePath = "${outputDir.path}/$cleanFileName";

      final file = io.File(savePath);
      if (await file.exists()) {
        await OpenFile.open(savePath);
        return;
      }

      Dio dio = Dio();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading $cleanFileName...')),
        );
      }

      await dio.download(url.trim(), savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Downloaded successfully!'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => OpenFile.open(savePath),
            ),
          ),
        );
      }

      await OpenFile.open(savePath);
    } catch (e) {
      try {
        final Uri uri = Uri.parse(url.trim());
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: $e')),
          );
        }
      }
    }
  }



  Future<void> _sendMessage({String? text, String? mediaUrl, String? mediaType, String? fileName}) async {
    final msg = text ?? _messageController.text.trim();
    if (msg.isEmpty && mediaUrl == null) return;
    if (currentUid == null) return;

    if (_editingMessageId != null) {
      await FirebaseFirestore.instance
          .collection('messes')
          .doc(widget.messId)
          .collection('group_chats')
          .doc(_editingMessageId)
          .update({
        'text': msg,
        'isEdited': true,
      });

      setState(() {
        _editingMessageId = null;
        _messageController.clear();
      });
      return;
    }

    bool isImage = mediaType == 'image';
    bool isVideo = mediaType == 'video';
    bool isDoc = mediaType == 'document';

    bool allowed = await _checkAndUpdateDailyLimit(isImage: isImage, isVideo: isVideo, isDoc: isDoc);
    if (!allowed) return;

    _messageController.clear();
    setState(() => _replyingToMessage = null);

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
    final userName = userDoc.data()?['name'] ?? 'Member';
    final userPhoto = userDoc.data()?['photoUrl'] ?? '';

    await FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('group_chats')
        .add({
      'text': msg,
      'mediaUrl': mediaUrl ?? '',
      'mediaType': mediaType ?? '',
      'fileName': fileName ?? '',
      'senderId': currentUid,
      'senderName': userName,
      'senderPhoto': userPhoto,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
      'replyTo': _replyingToMessage != null
          ? {
              'senderName': _replyingToMessage!['senderName'],
              'text': _replyingToMessage!['text'] ?? (_replyingToMessage!['mediaType'] == 'image' ? 'Photo' : 'Document'),
            }
          : null,
      'isEdited': false,
      'deletedFor': [],
      'seenBy': [
        {
          'uid': currentUid,
          'name': userName,
          'photoUrl': userPhoto,
        }
      ],
      'readByUids': [currentUid],
    });
  }

  Future<void> _pickAndUploadMedia(String type) async {
    String? downloadUrl;
    String? originalFileName;

    if (type == 'image' || type == 'video') {
      final XFile? file = type == 'video'
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

      if (file == null) return;
      originalFileName = file.name;
      final fileObj = io.File(file.path);
      
      setState(() => _isUploading = true);
      try {
        const cloudName = 'kedrygkt';
        const uploadPreset = 'mess_chat_preset';
        final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$type/upload');
        var request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(await http.MultipartFile.fromPath('file', fileObj.path));

        var response = await request.send();
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final jsonData = json.decode(responseData);
          downloadUrl = jsonData['secure_url'];
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    } else if (type == 'document') {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;

      originalFileName = result.files.single.name;
      io.File fileObj = io.File(result.files.single.path!);

      setState(() => _isUploading = true);
      try {
        const cloudName = 'kedrygkt';
        const uploadPreset = 'mess_chat_preset';
        final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/raw/upload');
        var request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(await http.MultipartFile.fromPath('file', fileObj.path));

        var response = await request.send();
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final jsonData = json.decode(responseData);
          downloadUrl = jsonData['secure_url'];
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document upload failed: $e')));
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }

    if (downloadUrl != null) {
      await _sendMessage(text: '', mediaUrl: downloadUrl, mediaType: type, fileName: originalFileName);
    }
  }

  Future<void> _addReaction(String docId, String emoji, Map<String, dynamic> currentReactions) async {
    if (currentUid == null) return;

    final updated = Map<String, dynamic>.from(currentReactions);
    if (updated[currentUid] == emoji) {
      updated.remove(currentUid);
    } else {
      updated[currentUid!] = emoji;
    }

    await FirebaseFirestore.instance
        .collection('messes')
        .doc(widget.messId)
        .collection('group_chats')
        .doc(docId)
        .update({'reactions': updated});
  }

  Future<void> _deleteMessage(String docId, String senderId, Timestamp? timestamp, bool deleteForEveryone) async {
    if (currentUid == null) return;

    if (deleteForEveryone && senderId == currentUid) {
      if (timestamp != null) {
        final difference = DateTime.now().difference(timestamp.toDate());
        if (difference.inHours >= 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You can only delete messages for everyone within 2 hours.')),
            );
          }
          return;
        }
      }
      await FirebaseFirestore.instance
          .collection('messes')
          .doc(widget.messId)
          .collection('group_chats')
          .doc(docId)
          .delete();
    } else {
      await FirebaseFirestore.instance
          .collection('messes')
          .doc(widget.messId)
          .collection('group_chats')
          .doc(docId)
          .update({
        'deletedFor': FieldValue.arrayUnion([currentUid]),
      });
    }
  }

  void _showReactionDetails(Map<String, dynamic> reactions) async {
    Map<String, String> userNames = {};
    for (String uid in reactions.keys) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      userNames[uid] = doc.data()?['name'] ?? 'Member';
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 300),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView(
                children: reactions.entries.map((entry) {
                  final uid = entry.key;
                  final emoji = entry.value;
                  final name = userNames[uid] ?? 'Member';
                  return ListTile(
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: Text(emoji, style: const TextStyle(fontSize: 18)),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeenByDialog(List seenByList) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 350),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seen by everyone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: seenByList.length,
                itemBuilder: (context, index) {
                  final user = seenByList[index];
                  final name = user['name'] ?? 'Member';
                  final photoUrl = user['photoUrl'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'M',
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(String docId, String text, bool isMe, String senderId, Map<String, dynamic> reactions, Timestamp? timestamp, Map<String, dynamic> messageData) {
    bool canEdit = false;
    if (isMe && timestamp != null) {
      final difference = DateTime.now().difference(timestamp.toDate());
      if (difference.inHours < 1) {
        canEdit = true;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['👍', '❤️', '😂', '😮', '😢'].map((emoji) {
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _addReaction(docId, emoji, reactions);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: Color(0xFF0084FF)),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyingToMessage = messageData);
                },
              ),
              if (canEdit && text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.green),
                  title: const Text('Edit Message'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessageId = docId;
                      _messageController.text = text;
                    });
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.orange),
                title: const Text('Delete for Me'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(docId, senderId, timestamp, false);
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: const Text('Delete for Everyone', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(docId, senderId, timestamp, true);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).cardColor,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0084FF), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messes')
                  .doc(widget.messId)
                  .collection('group_chats')
                  .orderBy('timestamp', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                int badgeCount = 0;
                if (snapshot.hasData && currentUid != null) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final List readBy = data['readByUids'] ?? [];
                    if (!readBy.contains(currentUid)) {
                      badgeCount++;
                    }
                  }
                }
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)]),
                      ),
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.forum_rounded, color: Color(0xFF0084FF), size: 20),
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mess Group Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('messes')
                      .doc(widget.messId)
                      .collection('group_chats')
                      .orderBy('timestamp', descending: true)
                      .limit(30)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int unreadCount = 0;
                    if (snapshot.hasData && currentUid != null) {
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final List readBy = data['readByUids'] ?? [];
                        if (!readBy.contains(currentUid)) {
                          unreadCount++;
                        }
                      }
                    }
                    return Text(
                      unreadCount > 0 ? '$unreadCount new messages' : 'Active Now',
                      style: TextStyle(color: unreadCount > 0 ? Colors.redAccent : Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(color: Color(0xFF0084FF), backgroundColor: Colors.white),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messes')
                  .doc(widget.messId)
                  .collection('group_chats')
                  .orderBy('timestamp', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0084FF)));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                          child: const Icon(Icons.mark_chat_unread_rounded, size: 50, color: Color(0xFF0084FF)),
                        ),
                        const SizedBox(height: 12),
                        const Text('No messages yet. Say hi to your roommates!', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final List deletedFor = data['deletedFor'] ?? [];
                    if (currentUid != null && deletedFor.contains(currentUid)) {
                      return const SizedBox.shrink();
                    }

                    final bool isMe = data['senderId'] == currentUid;
                    final String senderId = data['senderId'] ?? '';
                    final String senderName = data['senderName'] ?? 'Member';
                    final String senderPhoto = data['senderPhoto'] ?? '';
                    final String text = data['text'] ?? '';
                    final String mediaUrl = data['mediaUrl'] ?? '';
                    final String mediaType = data['mediaType'] ?? '';
                    final String fileName = data['fileName'] ?? 'Document';
                    final bool isEdited = data['isEdited'] ?? false;
                    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
                    final Map<String, dynamic> reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
                    final List seenByList = (data['seenBy'] as List?) ?? [];
                    final Map<String, dynamic>? replyTo = data['replyTo'];

                    String timeFormatted = '';
                    if (timestamp != null) {
                      timeFormatted = DateFormat('hh:mm a').format(timestamp.toDate());
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => _showMessageOptions(doc.id, text, isMe, senderId, reactions, timestamp, data),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe) ...[
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.grey.shade400,
                                      backgroundImage: senderPhoto.isNotEmpty
                                          ? ResizeImage(NetworkImage(senderPhoto), width: 60, height: 60)
                                          : null,
                                      child: senderPhoto.isEmpty
                                          ? Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : 'M',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54))
                                          : null,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: isMe
                                            ? const LinearGradient(
                                                colors: [Color(0xFF0084FF), Color(0xFF00C6FF)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        color: isMe ? null : (isDark ? Colors.grey.shade800 : Colors.white),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(18),
                                          topRight: const Radius.circular(18),
                                          bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          if (!isMe)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 3.0),
                                              child: Text(
                                                senderName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0084FF)),
                                              ),
                                            ),
                                          if (replyTo != null)
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.black12,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border(left: BorderSide(color: isMe ? Colors.white : Colors.blue, width: 3)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(replyTo['senderName'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.blue)),
                                                  Text(replyTo['text'] ?? '', style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                ],
                                              ),
                                            ),
                                          if (mediaUrl.isNotEmpty && mediaType == 'image')
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.network(
                                                    mediaUrl,
                                                    height: 200,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    cacheWidth: 800,
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return Container(
                                                        height: 200,
                                                        width: double.infinity,
                                                        color: Colors.black12,
                                                        child: const Center(
                                                          child: SizedBox(
                                                            width: 24,
                                                            height: 24,
                                                            child: CircularProgressIndicator(strokeWidth: 2),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (context, error, stackTrace) => Container(
                                                      height: 200,
                                                      width: double.infinity,
                                                      color: Colors.black12,
                                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 32),
                                                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                                                  onPressed: () => _openOrDownloadFile(mediaUrl, fileName.isNotEmpty ? fileName : 'image.jpg'),
                                                ),
                                              ],
                                            ),
                                          if (mediaUrl.isNotEmpty && mediaType == 'document')
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.insert_drive_file_rounded, color: Colors.white),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 13, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                                                  onPressed: () => _openOrDownloadFile(mediaUrl, fileName),
                                                ),
                                              ],
                                            ),
                                          if (mediaUrl.isNotEmpty && text.isNotEmpty) const SizedBox(height: 6),
                                          if (text.isNotEmpty)
                                            Text(text, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)), fontSize: 14)),
                                          const SizedBox(height: 3),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(timeFormatted, style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : Colors.grey)),
                                              if (isEdited) ...[
                                                const SizedBox(width: 4),
                                                Text('(Edited)', style: TextStyle(fontSize: 8, fontStyle: FontStyle.italic, color: isMe ? Colors.white60 : Colors.grey)),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (reactions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, right: 6, left: 6),
                                  child: GestureDetector(
                                    onTap: () => _showReactionDetails(reactions),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.grey.shade800 : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: reactions.values.toSet().map((emoji) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 1),
                                            child: Text(emoji, style: const TextStyle(fontSize: 12)),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),

                              if (isMe && seenByList.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3.0, right: 4.0),
                                  child: InkWell(
                                    onTap: () => _showSeenByDialog(seenByList),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ...seenByList.where((u) => u is Map && u['uid'] != currentUid).take(4).map((user) {
                                          final pUrl = user['photoUrl'] ?? '';
                                          final uName = user['name'] ?? 'M';
                                          return Padding(
                                            padding: const EdgeInsets.only(left: 2.0),
                                            child: Tooltip(
                                              message: 'Seen by $uName',
                                              child: CircleAvatar(
                                                radius: 7,
                                                backgroundColor: Colors.blue.shade100,
                                                backgroundImage: pUrl.isNotEmpty ? NetworkImage(pUrl) : null,
                                                child: pUrl.isEmpty
                                                    ? Text(uName[0].toUpperCase(), style: const TextStyle(fontSize: 6, color: Colors.blue, fontWeight: FontWeight.bold))
                                                    : null,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        if (seenByList.length - 1 > 4)
                                          Text(' +${seenByList.length - 5}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                        if (seenByList.length <= 1)
                                          const Text('Sent', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 18, color: Color(0xFF0084FF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingToMessage!['senderName']}: ${_replyingToMessage!['text'] ?? 'Media'}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _replyingToMessage = null),
                  ),
                ],
              ),
            ),

          if (_editingMessageId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Editing message...',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() {
                      _editingMessageId = null;
                      _messageController.clear();
                    }),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF0084FF)),
                    onPressed: () => _pickAndUploadMedia('document'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_camera_rounded, color: Color(0xFF0084FF)),
                    onPressed: () => _pickAndUploadMedia('image'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade800 : const Color(0xFFF0F2F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFF0084FF), Color(0xFF00C6FF)]),
                      ),
                      child: Icon(_editingMessageId != null ? Icons.check_rounded : Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
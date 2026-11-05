import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessNoticeBoardWidget extends StatelessWidget {
  final String messId;
  final String currentNote;
  final bool isAdmin;
  final bool isManager;

  const MessNoticeBoardWidget({
    super.key,
    required this.messId,
    required this.currentNote,
    this.isAdmin = false,
    this.isManager = false,
  });

  void _showEditNoteDialog(BuildContext context) {
    final noteController = TextEditingController(text: currentNote);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Mess Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: 'Write shared mess notice here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            onPressed: () async {
              final newNote = noteController.text.trim();
              await FirebaseFirestore.instance.collection('messes').doc(messId).set({
                'messNote': newNote,
                'noteUpdatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Notice', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: Color(0xFF1B5E20), size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Mess Notice & Notes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B5E20)),
                    ),
                  ],
                ),
                if (isAdmin || isManager) // 🌟 Admin ও Manager উভয়েই নোটিশ এডিট করতে পারবেন
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF1B5E20)),
                    onPressed: () => _showEditNoteDialog(context),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                currentNote,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
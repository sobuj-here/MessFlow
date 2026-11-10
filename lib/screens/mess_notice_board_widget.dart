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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: Color(0xFF2E7D32), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Mess Notice & Notes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
              if (isAdmin || isManager)
                InkWell(
                  onTap: () => _showEditNoteDialog(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withValues(alpha: isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 14, color: Color(0xFF2E7D32)),
                        SizedBox(width: 4),
                        Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.green.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.green.shade100,
              ),
            ),
            child: Text(
              currentNote,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.grey.shade300 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

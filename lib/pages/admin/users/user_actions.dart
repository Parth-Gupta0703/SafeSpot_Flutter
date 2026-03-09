// User action helpers — confirmation dialogs, text prompts, and helper utilities
// used by the admin users page when handling moderation actions on accounts.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Dialogs ───────────────────────────────────────────────────────────────────

/// Shows a yes/no confirmation dialog. Returns true if confirmed.
Future<bool> showUserConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title:
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content:
          Text(message, style: const TextStyle(color: Color(0xFF677489))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child:
              const Text('Confirm', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a text input dialog. Returns the entered text, or null if cancelled.
Future<String?> showUserTextInputDialog(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final c = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title:
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: c,
        maxLines: 3,
        decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10))),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Submit', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  c.dispose();
  return result;
}

// ── User detail sheet ─────────────────────────────────────────────────────────

/// Opens a bottom sheet with full details for a user (post count, ban info, etc.).
Future<void> showUserDetailsSheet(
  BuildContext context, {
  required String email,
  required String username,
  required String role,
  required String status,
  required String banReason,
  Timestamp? bannedAt,
}) async {
  int postCount = 0;
  int flagCount = 0;
  try {
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('User Posts')
          .where('UserEmail', isEqualTo: email)
          .count()
          .get(),
      FirebaseFirestore.instance
          .collection('Moderated Posts')
          .where('UserEmail', isEqualTo: email)
          .count()
          .get(),
    ]);
    postCount = results[0].count ?? 0;
    flagCount = results[1].count ?? 0;
  } catch (_) {}

  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7DCE5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: role == 'admin'
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF00B4D8),
                child: Text(
                  email.isNotEmpty ? email[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                    if (username.isNotEmpty)
                      Text('@$username',
                          style: const TextStyle(
                              color: Color(0xFF677489), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _detailRow(Icons.badge_rounded, 'Role',
              role == 'admin' ? 'Admin' : 'Member'),
          _detailRow(Icons.circle_rounded, 'Status',
              status == 'banned' ? '🚫 Banned' : '✅ Active'),
          if (status == 'banned' && banReason.isNotEmpty)
            _detailRow(
                Icons.info_outline_rounded, 'Ban Reason', banReason),
          if (bannedAt != null)
            _detailRow(Icons.calendar_today_rounded, 'Banned At',
                _formatDate(bannedAt)),
          _detailRow(
              Icons.article_rounded, 'Posts Published', '$postCount'),
          _detailRow(Icons.flag_rounded, 'Posts Flagged', '$flagCount'),
        ],
      ),
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _detailRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CACCF)),
        const SizedBox(width: 10),
        Text('$label: ',
            style:
                const TextStyle(color: Color(0xFF677489), fontSize: 13)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Color(0xFF2D3142),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

String _formatDate(Timestamp ts) {
  final d = ts.toDate();
  return '${d.day}/${d.month}/${d.year}';
}

// ── Firestore helpers ─────────────────────────────────────────────────────────

/// Queues an email via Firestore (requires Firebase email extension).
Future<void> queueEmail(
  String to,
  String subject,
  String body, {
  required String fromAdmin,
}) async {
  await FirebaseFirestore.instance.collection('mail').add({
    'to': [to],
    'message': {'subject': subject, 'text': body},
    'createdBy': fromAdmin,
    'createdAt': Timestamp.now(),
  });
}

/// Adds all documents in [collection] matching [email] to [batch] for deletion.
Future<void> collectForDeletion(
    WriteBatch batch, String collection, String email) async {
  final snap = await FirebaseFirestore.instance
      .collection(collection)
      .where('UserEmail', isEqualTo: email)
      .get();
  for (final doc in snap.docs) {
    batch.delete(doc.reference);
  }
}

/// Deletes all documents in a collection group matching [email].
Future<void> deleteCollectionGroup(
    String collectionGroup, String email) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collectionGroup(collectionGroup)
        .where('UserEmail', isEqualTo: email)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  } catch (_) {}
}

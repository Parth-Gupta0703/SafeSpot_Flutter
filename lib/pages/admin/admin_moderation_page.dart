import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key});

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF4FF), Color(0xFFFFF1F6), Color(0xFFFFF8EE)],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 154,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(background: _buildHeader()),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFF6B6B),
                indicatorWeight: 3,
                labelColor: const Color(0xFFFF6B6B),
                unselectedLabelColor: const Color(0xFF677489),
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'Flagged Posts'),
                  Tab(text: 'Flagged Comments'),
                ],
              ),
            ),
          ],
          body: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ModerationList(
                      collection: 'Moderated Posts',
                      emptyLabel: 'No flagged posts',
                      icon: Icons.article_rounded,
                      searchQuery: _searchQuery,
                    ),
                    _ModerationList(
                      collection: 'Moderated Comments',
                      emptyLabel: 'No flagged comments',
                      icon: Icons.comment_rounded,
                      searchQuery: _searchQuery,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        style: const TextStyle(color: Color(0xFF2D3142)),
        decoration: InputDecoration(
          hintText: 'Search by reason, content, or user email...',
          hintStyle: const TextStyle(color: Color(0xFF7D8A9C)),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Color(0xFF7D8A9C), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon:
                      const Icon(Icons.close_rounded, color: Color(0xFF7D8A9C)),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE6EC), Color(0xFFFFF1D9)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            top: -15,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Moderation Queue',
                      style: TextStyle(
                        color: Color(0xFF2D3142),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('Moderated Posts')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            return _CountPill('$count posts', const Color(0xFFFF6B6B));
                          },
                        ),
                        const SizedBox(width: 6),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('Moderated Comments')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            return _CountPill(
                              '$count comments',
                              const Color(0xFFFF9F43),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationList extends StatelessWidget {
  const _ModerationList({
    required this.collection,
    required this.emptyLabel,
    required this.icon,
    required this.searchQuery,
  });

  final String collection;
  final String emptyLabel;
  final IconData icon;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('TimeStamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B6B)),
          );
        }

        var items = snapshot.data?.docs ?? const [];

        if (searchQuery.isNotEmpty) {
          items = items.where((doc) {
            final data = doc.data();
            final message = _extractMessage(data).toLowerCase();
            final reason = _extractReason(data).toLowerCase();
            final email = _extractEmail(data).toLowerCase();
            final type = _extractType(data).toLowerCase();
            return message.contains(searchQuery) ||
                reason.contains(searchQuery) ||
                email.contains(searchQuery) ||
                type.contains(searchQuery);
          }).toList();
        }

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C49A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF00C49A), size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'All clear',
                  style: TextStyle(
                    color: Color(0xFF2D3142),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emptyLabel,
                  style: const TextStyle(color: Color(0xFF677489), fontSize: 14),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded,
                            color: Color(0xFFFF6B6B), size: 13),
                        const SizedBox(width: 5),
                        Text(
                          '${items.length} item${items.length > 1 ? 's' : ''} pending',
                          style: const TextStyle(
                            color: Color(0xFFFF6B6B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _clearAll(context, items),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD7DCE5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.clear_all_rounded,
                              color: Color(0xFF677489), size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Clear All',
                            style: TextStyle(
                              color: Color(0xFF677489),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _ModerationCard(doc: items[index], icon: icon),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _extractMessage(Map<String, dynamic> data) {
    const keys = ['Message', 'Text', 'Comment', 'Reply', 'Content'];
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return 'No content';
  }

  static String _extractReason(Map<String, dynamic> data) {
    final value = data['Reason'];
    if (value == null) return 'Unspecified';
    final text = value.toString().trim();
    return text.isEmpty ? 'Unspecified' : text;
  }

  static String _extractEmail(Map<String, dynamic> data) {
    final value = data['UserEmail'] ?? data['email'];
    if (value == null) return 'unknown';
    final text = value.toString().trim();
    return text.isEmpty ? 'unknown' : text;
  }

  static String _extractType(Map<String, dynamic> data) {
    final value = data['Type'];
    if (value == null) return '';
    return value.toString().trim();
  }

  void _clearAll(
      BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD7DCE5)),
        ),
        title: const Text('Clear all items?',
            style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.w700)),
        content: Text(
          'This will remove all ${docs.length} items from this moderation queue.',
          style: const TextStyle(color: Color(0xFF677489)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7D8A9C))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final batch = FirebaseFirestore.instance.batch();
              for (final doc in docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ModerationCard extends StatefulWidget {
  const _ModerationCard({required this.doc, required this.icon});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final IconData icon;

  @override
  State<_ModerationCard> createState() => _ModerationCardState();
}

class _ModerationCardState extends State<_ModerationCard> {
  bool _loading = false;
  bool _expanded = false;

  Color _reasonColor(String reason) {
    final text = reason.toLowerCase();
    if (text.contains('spam')) return const Color(0xFF9B59B6);
    if (text.contains('hate') || text.contains('abuse')) return const Color(0xFFFF6B6B);
    if (text.contains('violence') || text.contains('threat')) return const Color(0xFFEE5A24);
    if (text.contains('explicit') || text.contains('adult')) return const Color(0xFFFF9F43);
    if (text.contains('misinform')) return const Color(0xFF00B4D8);
    return const Color(0xFF6C63FF);
  }

  IconData _reasonIcon(String reason) {
    final text = reason.toLowerCase();
    if (text.contains('spam')) return Icons.mark_email_unread_rounded;
    if (text.contains('hate') || text.contains('abuse')) {
      return Icons.sentiment_very_dissatisfied_rounded;
    }
    if (text.contains('violence') || text.contains('threat')) {
      return Icons.dangerous_rounded;
    }
    if (text.contains('explicit') || text.contains('adult')) {
      return Icons.no_adult_content_rounded;
    }
    if (text.contains('misinform')) return Icons.info_outline_rounded;
    return Icons.flag_rounded;
  }

  String _readFirst(Map<String, dynamic> data, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp is! Timestamp) return '';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final message = _readFirst(data, ['Message', 'Text', 'Comment', 'Reply', 'Content'],
        fallback: 'No content');
    final reason = _readFirst(data, ['Reason'], fallback: 'Unspecified');
    final userEmail = _readFirst(data, ['UserEmail', 'email'], fallback: 'unknown');
    final itemType = _readFirst(data, ['Type'], fallback: 'post');
    final timestamp = data['TimeStamp'] ?? data['Time'];

    final color = _reasonColor(reason);
    final reasonIcon = _reasonIcon(reason);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(reasonIcon, color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _ReasonChip(reason: reason, color: color),
                            _TypeChip(text: itemType),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Color(0xFF677489),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: const Color(0xFF677489),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE6EAF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONTENT',
                    style: TextStyle(
                      color: Color(0xFF7D8A9C),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF3C4659),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userEmail,
                    style: const TextStyle(
                      color: Color(0xFF677489),
                      fontSize: 12,
                    ),
                  ),
                  if (_timeAgo(timestamp).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(timestamp),
                      style: const TextStyle(
                        color: Color(0xFF7D8A9C),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _loading
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFFF6B6B)),
                                ),
                              )
                            : OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFFF6B6B)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.delete_forever_rounded,
                                    color: Color(0xFFFF6B6B), size: 16),
                                label: const Text(
                                  'Delete Item',
                                  style: TextStyle(
                                      color: Color(0xFFFF6B6B), fontSize: 12),
                                ),
                                onPressed: () async {
                                  final ok = await _confirmAction(
                                    title: 'Delete this flagged item?',
                                    message:
                                        'This permanently removes the queued item.',
                                    confirmLabel: 'Delete',
                                    danger: true,
                                  );
                                  if (!ok) return;
                                  setState(() => _loading = true);
                                  await widget.doc.reference.delete();
                                },
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C49A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 16),
                          label: const Text(
                            'Dismiss',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          onPressed: () async {
                            final ok = await _confirmAction(
                              title: 'Dismiss this report?',
                              message:
                                  'This removes the report without further action.',
                              confirmLabel: 'Dismiss',
                              danger: false,
                            );
                            if (!ok) return;
                            setState(() => _loading = true);
                            await widget.doc.reference.delete();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    required bool danger,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  danger ? const Color(0xFFFF6B6B) : const Color(0xFF00C49A),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason, required this.color});

  final String reason;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        reason,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC9D9F9)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4B70B1),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_dashboard.dart'; // AdminPageHeader

class AdminPostsPage extends StatefulWidget {
  const AdminPostsPage({super.key});

  @override
  State<AdminPostsPage> createState() => _AdminPostsPageState();
}

// FIX: Renamed enum values and added descriptions so purpose is clear
enum _PostFilter {
  all,         // All posts — shows everything
  liked,       // Engaged posts — posts with 1+ likes (popular/viral content)
  noLikes,     // Zero-engagement posts — no likes yet (potential spam or new)
}

class _AdminPostsPageState extends State<AdminPostsPage> {
  String _searchQuery = '';
  int _totalPosts = 0;
  _PostFilter _filter = _PostFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDDF2FF), Color(0xFFFFEAF2)],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 150,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: AdminPageHeader(
                  title: 'Content Manager',
                  subtitle: '$_totalPosts posts total',
                  iconData: Icons.article_rounded,
                  fromColor: const Color(0xFF00B4D8),
                  toColor: const Color(0xFFFF8FAB),
                ),
              ),
            ),
          ],
          body: Column(
            children: [
              _buildFilters(),
              Expanded(child: _buildPostList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            style: const TextStyle(color: Color(0xFF2D3142)),
            decoration: InputDecoration(
              hintText: 'Search posts by content or author…',
              hintStyle: const TextStyle(color: Color(0xFF7D8A9C)),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Color(0xFF7D8A9C)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF7D8A9C), size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD7DCE5))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD7DCE5))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF00B4D8), width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            onChanged: (v) =>
                setState(() => _searchQuery = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),
          // FIX: Each filter chip now has a tooltip explaining its purpose
          Row(
            children: [
              Tooltip(
                message: 'Show all posts regardless of engagement',
                child: _chip('All', _PostFilter.all),
              ),
              const SizedBox(width: 8),
              Tooltip(
                // FIX: "With Likes" now clearly explains what it filters
                message:
                    'Posts with 1+ likes — popular or viral content worth monitoring',
                child: _chip('With likes', _PostFilter.liked),
              ),
              const SizedBox(width: 8),
              Tooltip(
                // FIX: "No Likes" now clearly explains its moderation use case
                message:
                    'Posts with 0 likes — new content or potential spam to review',
                child: _chip('No likes', _PostFilter.noLikes),
              ),
            ],
          ),
          // FIX: Helper text explaining the currently active filter
          if (_filter != _PostFilter.all) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00B4D8).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF00B4D8).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 13, color: Color(0xFF007B97)),
                  const SizedBox(width: 6),
                  Text(
                    _filter == _PostFilter.liked
                        ? 'Showing engaged posts — useful for identifying trending or viral content'
                        : 'Showing zero-engagement posts — useful for spam checks and new content review',
                    style: const TextStyle(
                        color: Color(0xFF007B97), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, _PostFilter filter) {
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = filter),
      side: BorderSide(
          color: selected
              ? const Color(0xFF00B4D8)
              : const Color(0xFFD7DCE5)),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFE4F8FF),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF007B97) : const Color(0xFF677489),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  Widget _buildPostList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('User Posts')
          .orderBy('TimeStamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF00B4D8)));
        }

        var posts = snap.data?.docs ?? const [];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _totalPosts != posts.length) {
            setState(() => _totalPosts = posts.length);
          }
        });

        if (_searchQuery.isNotEmpty) {
          posts = posts.where((doc) {
            final data = doc.data();
            final msg =
                _str(data, ['Message', 'Text']).toLowerCase();
            final email =
                _str(data, ['UserEmail', 'email']).toLowerCase();
            return msg.contains(_searchQuery) ||
                email.contains(_searchQuery);
          }).toList();
        }

        if (_filter != _PostFilter.all) {
          posts = posts.where((doc) {
            final likes = _count(doc.data()['Likes']);
            return _filter == _PostFilter.liked ? likes > 0 : likes == 0;
          }).toList();
        }

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined,
                    size: 60,
                    color: const Color(0xFF7D8A9C)
                        .withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No posts matching "$_searchQuery"'
                      : 'No posts in this view',
                  style: const TextStyle(
                      color: Color(0xFF677489), fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _PostCard(doc: posts[i]),
        );
      },
    );
  }

  static String _str(Map<String, dynamic> data, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      final v = data[key];
      if (v == null) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty) return t;
    }
    return fallback;
  }

  static int _count(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is Iterable) return value.length;
    if (value is Map) return value.length;
    return int.tryParse(value.toString()) ?? 0;
  }
}

// ── Post card ─────────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  const _PostCard({required this.doc});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _expanded = false;

  String _timeAgo(dynamic ts) {
    if (ts is! Timestamp) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  String _initials(String email) {
    if (email.isEmpty) return '?';
    final part = email.split('@').first;
    return part.length >= 2
        ? part.substring(0, 2).toUpperCase()
        : part[0].toUpperCase();
  }

  String _str(List<String> keys, {String fallback = ''}) {
    final data = widget.doc.data();
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty) return t;
    }
    return fallback;
  }

  int _count(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is Iterable) return v.length;
    if (v is Map) return v.length;
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final message = _str(['Message', 'Text'], fallback: 'No content');
    final email = _str(['UserEmail', 'email'], fallback: 'unknown');
    final likes = _count(data['Likes']);
    final comments = _count(data['CommentCount'] ??
        data['CommentsCount'] ??
        data['Comments']);
    final timestamp = data['TimeStamp'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7DCE5)),
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
          // ── Header row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF00B4D8), Color(0xFF0077B6)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(_initials(email),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email,
                          style: const TextStyle(
                              color: Color(0xFF2D3142),
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      Text(_timeAgo(timestamp),
                          style: const TextStyle(
                              color: Color(0xFF7D8A9C), fontSize: 11)),
                    ],
                  ),
                ),
                // Expand/collapse toggle
                IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: const Color(0xFF677489),
                  ),
                  onPressed: () =>
                      setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          // ── Content preview ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFE),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFE6EAF2)),
              ),
              child: Text(
                message,
                style: const TextStyle(
                    color: Color(0xFF3C4659),
                    fontSize: 13,
                    height: 1.5),
                maxLines: _expanded ? null : 3,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
          ),
          // ── Stats row ──────────────────────────────────────────────────
          if (likes > 0 || comments > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  if (likes > 0)
                    _Stat(Icons.favorite_rounded, '$likes likes',
                        const Color(0xFFFF6B6B)),
                  if (likes > 0 && comments > 0)
                    const SizedBox(width: 14),
                  if (comments > 0)
                    _Stat(Icons.comment_rounded, '$comments comments',
                        const Color(0xFF00B4D8)),
                ],
              ),
            ),
          // ── Expanded admin actions ────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded,
                          size: 14, color: Color(0xFF677489)),
                      const SizedBox(width: 6),
                      const Text('Admin Actions',
                          style: TextStyle(
                              color: Color(0xFF677489),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.content_copy_rounded,
                          label: 'Copy Post ID',
                          color: const Color(0xFF6C63FF),
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text: widget.doc.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Post ID copied'),
                                  behavior: SnackBarBehavior.floating),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.flag_rounded,
                          label: 'Flag for Review',
                          color: const Color(0xFFFFB84D),
                          onTap: () => _flagPost(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DeleteButton(doc: widget.doc),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            // When collapsed: show just the delete button
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DeleteButton(doc: widget.doc, compact: true),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _flagPost(BuildContext context) async {
    final data = widget.doc.data();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String selected = 'Spam';
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Flag for Review',
                style: TextStyle(fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['Spam', 'Hate Speech', 'Misinformation',
                'Explicit Content', 'Violence', 'Other']
                  .map((r) => RadioListTile<String>(
                        value: r,
                        groupValue: selected,
                        onChanged: (v) => setS(() => selected = v!),
                        title: Text(r, style: const TextStyle(fontSize: 13)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, selected),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB84D),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Flag',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (reason == null || !mounted) return;

    // Add to Moderated Posts collection
    await FirebaseFirestore.instance.collection('Moderated Posts').add({
      'Message': data['Message'] ?? data['Text'] ?? '',
      'UserEmail': data['UserEmail'] ?? data['email'] ?? '',
      'OriginalPostId': widget.doc.id,
      'Reason': reason,
      'Type': 'post',
      'FlaggedBy': 'admin',
      'TimeStamp': Timestamp.now(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Post flagged for review'),
          behavior: SnackBarBehavior.floating),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteButton extends StatefulWidget {
  const _DeleteButton({required this.doc, this.compact = false});
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool compact;

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Color(0xFFFF6B6B)),
      );
    }

    if (widget.compact) {
      return GestureDetector(
        onTap: () => _confirm(context),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.delete_rounded,
              color: Color(0xFFFF6B6B), size: 16),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _confirm(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.30)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded,
                size: 13, color: Color(0xFFFF6B6B)),
            SizedBox(width: 5),
            Text('Delete',
                style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _confirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFD7DCE5))),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFFF6B6B)),
            SizedBox(width: 8),
            Text('Delete post?',
                style: TextStyle(
                    color: Color(0xFF2D3142),
                    fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
            'This permanently removes the post and cannot be undone.',
            style: TextStyle(color: Color(0xFF677489))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF7D8A9C)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(this.context);
              setState(() => _loading = true);
              try {
                await widget.doc.reference.delete();
              } catch (_) {
                if (!mounted) return;
                setState(() => _loading = false);
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Unable to delete post'),
                      behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
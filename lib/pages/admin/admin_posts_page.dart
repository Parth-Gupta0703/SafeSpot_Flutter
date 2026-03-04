import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPostsPage extends StatefulWidget {
  const AdminPostsPage({super.key});

  @override
  State<AdminPostsPage> createState() => _AdminPostsPageState();
}

enum _PostVisibilityFilter { all, liked, noLikes }

class _AdminPostsPageState extends State<AdminPostsPage> {
  String _searchQuery = '';
  int _totalPosts = 0;
  _PostVisibilityFilter _visibilityFilter = _PostVisibilityFilter.all;

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
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(),
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

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDF2FF), Color(0xFFFFEAF2)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -12,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00B4D8).withValues(alpha: 0.08),
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
                      colors: [Color(0xFF00B4D8), Color(0xFFFF8FAB)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.article_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Content Manager',
                      style: TextStyle(
                        color: Color(0xFF2D3142),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$_totalPosts posts total',
                      style:
                          const TextStyle(color: Color(0xFF677489), fontSize: 12),
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

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: Color(0xFF2D3142)),
            decoration: InputDecoration(
              hintText: 'Search posts by content or author...',
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
                borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF00B4D8), width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (value) =>
                setState(() => _searchQuery = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildFilterChip('All', _PostVisibilityFilter.all),
              const SizedBox(width: 8),
              _buildFilterChip('With likes', _PostVisibilityFilter.liked),
              const SizedBox(width: 8),
              _buildFilterChip('No likes', _PostVisibilityFilter.noLikes),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _PostVisibilityFilter filter) {
    final selected = _visibilityFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _visibilityFilter = filter),
      side: BorderSide(
        color: selected ? const Color(0xFF00B4D8) : const Color(0xFFD7DCE5),
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFE4F8FF),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF007B97) : const Color(0xFF677489),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPostList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('User Posts')
          .orderBy('TimeStamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
          );
        }

        var posts = snapshot.data?.docs ?? const [];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _totalPosts != posts.length) {
            setState(() => _totalPosts = posts.length);
          }
        });

        if (_searchQuery.isNotEmpty) {
          posts = posts.where((doc) {
            final data = doc.data();
            final message = _readString(data, ['Message', 'Text']).toLowerCase();
            final email = _readString(data, ['UserEmail', 'email']).toLowerCase();
            return message.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }

        if (_visibilityFilter != _PostVisibilityFilter.all) {
          posts = posts.where((doc) {
            final likesCount = _countFromDynamic(doc.data()['Likes']);
            return _visibilityFilter == _PostVisibilityFilter.liked
                ? likesCount > 0
                : likesCount == 0;
          }).toList();
        }

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined,
                    size: 60, color: const Color(0xFF7D8A9C).withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No posts matching search'
                      : 'No posts yet',
                  style:
                      const TextStyle(color: Color(0xFF677489), fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _PostCard(doc: posts[index]),
        );
      },
    );
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  int _countFromDynamic(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is Iterable) return value.length;
    if (value is Map) return value.length;
    return int.tryParse(value.toString()) ?? 0;
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      if (timestamp is! Timestamp) return '';
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return '';
    }
  }

  String _initials(String email) {
    if (email.isEmpty) return '?';
    final parts = email.split('@').first;
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) return parts.substring(0, 2).toUpperCase();
    return parts[0].toUpperCase();
  }

  String _readString(Map<String, dynamic> data, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  int _countFromDynamic(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is Iterable) return value.length;
    if (value is Map) return value.length;
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final message = _readString(data, ['Message', 'Text'], fallback: 'No content');
    final email = _readString(data, ['UserEmail', 'email'], fallback: 'unknown');
    final timestamp = data['TimeStamp'];

    final likes = _countFromDynamic(data['Likes']);
    final comments = _countFromDynamic(
      data['CommentCount'] ?? data['CommentsCount'] ?? data['Comments'],
    );

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _initials(email),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: const TextStyle(
                          color: Color(0xFF2D3142),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _timeAgo(timestamp),
                        style: const TextStyle(
                            color: Color(0xFF7D8A9C), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                _DeleteButton(doc: doc),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE6EAF2)),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF3C4659),
                  fontSize: 13,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (likes > 0 || comments > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (likes > 0)
                    _PostStat(
                        Icons.favorite_rounded, '$likes', const Color(0xFFFF6B6B)),
                  if (likes > 0 && comments > 0) const SizedBox(width: 12),
                  if (comments > 0)
                    _PostStat(Icons.comment_rounded, '$comments',
                        const Color(0xFF00B4D8)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostStat extends StatelessWidget {
  const _PostStat(this.icon, this.count, this.color);

  final IconData icon;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DeleteButton extends StatefulWidget {
  const _DeleteButton({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

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
          strokeWidth: 2,
          color: Color(0xFFFF6B6B),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showDeleteDialog(context),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.delete_rounded, color: Color(0xFFFF6B6B), size: 16),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD7DCE5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFFF6B6B)),
            SizedBox(width: 8),
            Text(
              'Delete post',
              style: TextStyle(
                color: Color(0xFF2D3142),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          'This action cannot be undone. The post will be permanently removed.',
          style: TextStyle(color: Color(0xFF677489)),
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
              final messenger = ScaffoldMessenger.of(this.context);
              setState(() => _loading = true);
              try {
                await widget.doc.reference.delete();
              } catch (_) {
                if (!mounted) return;
                setState(() => _loading = false);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Unable to delete post right now'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


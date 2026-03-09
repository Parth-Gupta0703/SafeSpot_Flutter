import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_dashboard.dart'; // AdminPageHeader

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

// FIX: Added 'makeAdmin' as a distinct action; 'promoteOrDemote' kept for
// toggling. Added viewDetails so admin can inspect any account fully.
enum _UserAction {
  viewDetails,
  promoteToAdmin,
  demoteFromAdmin,
  banUser,
  unbanUser,
  changeUsername,
  removeUserData,
}

class _AdminUsersPageState extends State<AdminUsersPage>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  Future<Set<String>>? _activityEmailsFuture;
  late TabController _tabController;
  String _filterRole = 'all';

  String get _myEmail =>
      FirebaseAuth.instance.currentUser?.email ?? 'admin@safespot.local';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _filterRole = switch (_tabController.index) {
          1 => 'admin',
          2 => 'user',
          _ => 'all',
        };
      });
    });
    _activityEmailsFuture = _fetchActivityEmails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Set<String>> _fetchActivityEmails() async {
    try {
      final snaps = await Future.wait([
        FirebaseFirestore.instance.collection('User Posts').get(),
        FirebaseFirestore.instance.collection('Moderated Posts').get(),
        FirebaseFirestore.instance.collection('Moderated Comments').get(),
        FirebaseFirestore.instance.collectionGroup('Comments').get(),
        FirebaseFirestore.instance.collectionGroup('Replies').get(),
      ]);
      final emails = <String>{};
      for (final snap in snaps) {
        for (final doc in snap.docs) {
          final raw =
              (doc.data()['UserEmail'] ?? doc.data()['email'] ?? '').toString();
          final email = raw.trim().toLowerCase();
          if (email.contains('@')) emails.add(email);
        }
      }
      return emails;
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1220) : const Color(0xFFF3F6FF);
    final card = isDark ? const Color(0xFF1A1F34) : Colors.white;
    final text =
        isDark ? const Color(0xFFE7EDFF) : const Color(0xFF2D3142);
    final muted =
        isDark ? const Color(0xFF9CACCF) : const Color(0xFF667086);
    final border =
        isDark ? const Color(0xFF2B3656) : const Color(0xFFD6DCEE);

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: isDark
                ? const Color(0xFF151C31)
                : const Color(0xFFE7EDFF),
            flexibleSpace: FlexibleSpaceBar(
              background: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Users')
                    .snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? const [];
                  final admins = docs
                      .where((d) =>
                          (d.data()['role'] ?? '').toString().toLowerCase() ==
                          'admin')
                      .length;
                  final banned = docs
                      .where((d) =>
                          (d.data()['status'] ?? '').toString().toLowerCase() ==
                          'banned')
                      .length;
                  return AdminPageHeader(
                    title: 'User Management',
                    subtitle:
                        '${docs.length} total · $admins admins · $banned banned',
                    iconData: Icons.people_rounded,
                    fromColor: const Color(0xFF6C63FF),
                    toColor: const Color(0xFFFF8FAB),
                  );
                },
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF6C63FF),
              labelColor: const Color(0xFF6C63FF),
              unselectedLabelColor: muted,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Admins'),
                Tab(text: 'Members'),
              ],
            ),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  TextField(
                    style: TextStyle(color: text),
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search by email or username…',
                      hintStyle: TextStyle(color: muted),
                      prefixIcon:
                          Icon(Icons.search_rounded, color: muted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, color: muted),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: card,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFF6C63FF))),
                    ),
                  ),
                  
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Users')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final byEmail = <String, _AdminUser>{};
                  for (final doc in snap.data?.docs ?? const []) {
                    final data = doc.data();
                    final email =
                        (data['email'] ?? '').toString().trim().toLowerCase();
                    if (!email.contains('@')) continue;
                    byEmail[email] = _AdminUser(
                      email: email,
                      username: (data['username'] ?? '').toString(),
                      role: (data['role'] ?? 'user')
                                  .toString()
                                  .toLowerCase() ==
                              'admin'
                          ? 'admin'
                          : 'user',
                      status: (data['status'] ?? 'active')
                                  .toString()
                                  .toLowerCase() ==
                              'banned'
                          ? 'banned'
                          : 'active',
                      ref: doc.reference,
                      banReason:
                          (data['banReason'] ?? '').toString(),
                      bannedAt: data['bannedAt'] as Timestamp?,
                      postCount: null,
                    );
                  }

                  List<_AdminUser> filterAndSort(
                      Iterable<_AdminUser> input) {
                    final filtered = input.where((u) {
                      if (_filterRole != 'all' && u.role != _filterRole) {
                        return false;
                      }
                      if (_searchQuery.isEmpty) return true;
                      return u.email.contains(_searchQuery) ||
                          u.username
                              .toLowerCase()
                              .contains(_searchQuery);
                    }).toList()
                      ..sort((a, b) => a.email.compareTo(b.email));
                    return filtered;
                  }

                  Widget buildList(List<_AdminUser> users) {
                    if (users.isEmpty) {
                      return Center(
                          child: Text('No users found',
                              style: TextStyle(color: muted)));
                    }
                    return ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: users.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _UserTile(
                        user: users[i],
                        myEmail: _myEmail,
                        cardColor: card,
                        textColor: text,
                        mutedColor: muted,
                        borderColor: border,
                        onAction: (action) => _handleAction(users[i], action),
                      ),
                    );
                  }
                  return buildList(filterAndSort(byEmail.values));
                  
                  // return FutureBuilder<Set<String>>(
                  //   future: _activityEmailsFuture,
                  //   builder: (_, activity) {
                  //     for (final email in activity.data ?? <String>{}) {
                  //       byEmail.putIfAbsent(
                  //         email,
                  //         () => _AdminUser(
                  //           email: email,
                  //           username: '',
                  //           role: 'user',
                  //           status: 'active',
                  //           ref: null,
                  //           banReason: '',
                  //           bannedAt: null,
                  //           postCount: null,
                  //         ),
                  //       );
                  //     }
                  //     return buildList(filterAndSort(byEmail.values));
                  //   },
                  // );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action handler ────────────────────────────────────────────────────────

  Future<void> _handleAction(_AdminUser user, _UserAction action) async {
    switch (action) {
      // ── View full details ──────────────────────────────────────────────────
      case _UserAction.viewDetails:
        await _showDetailsSheet(user);
        break;

      // ── Promote regular user to admin ──────────────────────────────────────
      // FIX: This action is now ONLY available for regular users (role='user')
      case _UserAction.promoteToAdmin:
        if (!await _confirm(
          'Promote to Admin?',
          'Grant full admin access to ${user.email}? They will be able to manage all users and content.',
        )) return;
        await user.ref!.update({'role': 'admin'});
        _snack('✅ ${user.email} promoted to admin');
        break;

      // ── Demote admin back to user ──────────────────────────────────────────
      // FIX: This action is now ONLY available for admins (role='admin')
      case _UserAction.demoteFromAdmin:
        if (user.email == _myEmail) {
          _snack('⚠️ You cannot demote yourself');
          return;
        }
        if (!await _confirm(
          'Demote Admin?',
          'Remove admin access from ${user.email}? They will become a regular member.',
        )) return;
        await user.ref!.update({'role': 'user'});
        _snack('User demoted to member');
        break;

      // ── Ban a regular user ─────────────────────────────────────────────────
      // FIX: Only available for regular users — admins must be demoted first
      case _UserAction.banUser:
        final reason =
            await _askText('Ban Reason', 'Why are you banning this user?');
        if (reason == null || reason.trim().isEmpty) return;
        if (!await _confirm(
          'Ban User?',
          '${user.email} will be blocked from accessing the app.',
        )) return;
        await user.ref!.update({
          'status': 'banned',
          'banReason': reason.trim(),
          'bannedAt': Timestamp.now(),
          'bannedBy': _myEmail,
        });
        await _queueEmail(
          user.email,
          'Your SafeSpot account has been suspended',
          'Your account was suspended.\nReason: ${reason.trim()}\n\nIf you believe this is a mistake, please contact support.',
        );
        _snack('User banned and notification queued');
        break;

      // ── Unban ──────────────────────────────────────────────────────────────
      case _UserAction.unbanUser:
        if (!await _confirm(
          'Unban User?',
          '${user.email} will regain access to the app.',
        )) return;
        await user.ref!.update({
          'status': 'active',
          'banReason': FieldValue.delete(),
          'bannedAt': FieldValue.delete(),
          'bannedBy': FieldValue.delete(),
        });
        await _queueEmail(
          user.email,
          'Your SafeSpot account has been reactivated',
          'Your account suspension has been lifted. Welcome back!',
        );
        _snack('User unbanned and notification queued');
        break;

      // ── Request username change ────────────────────────────────────────────
      // FIX: Available for regular users only
      case _UserAction.changeUsername:
        final reason = await _askText(
          'Request Username Change',
          'Why should this user change their username?',
        );
        if (reason == null || reason.trim().isEmpty) return;
        if (!await _confirm(
          'Send Username Change Request?',
          'An email notification will be sent to ${user.email}.',
        )) return;
        await user.ref!.update({
          'usernameChangeRequested': true,
          'usernameChangeReason': reason.trim(),
          'usernameChangeRequestedAt': Timestamp.now(),
          'usernameChangeRequestedBy': _myEmail,
        });
        await _queueEmail(
          user.email,
          'Action required: Update your SafeSpot username',
          'An admin has requested you change your username.\nReason: ${reason.trim()}\n\nPlease update your username in the app settings.',
        );
        _snack('Username change request sent');
        break;

      // ── Remove all user data ───────────────────────────────────────────────
      // FIX: Available for regular users only — admins must be demoted first
      case _UserAction.removeUserData:
        if (!await _confirm(
          'Remove User Data?',
          'This permanently deletes all posts, comments, and the profile for ${user.email}. This cannot be undone.',
        )) return;
        final batch = FirebaseFirestore.instance.batch();
        await _collectForDeletion(batch, 'User Posts', user.email);
        await _collectForDeletion(
            batch, 'Moderated Posts', user.email);
        await _collectForDeletion(
            batch, 'Moderated Comments', user.email);
        await batch.commit();
        await _deleteCollectionGroup('Comments', user.email);
        await _deleteCollectionGroup('Replies', user.email);
        if (user.ref != null) await user.ref!.delete();
        await _queueEmail(
          user.email,
          'Your SafeSpot account has been removed',
          'Your account and all associated data have been permanently removed by a SafeSpot admin.',
        );
        _snack('User data removed');
        break;
    }
  }

  Future<void> _showDetailsSheet(_AdminUser user) async {
    // Load post count for this user
    int postCount = 0;
    int flagCount = 0;
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('User Posts')
            .where('UserEmail', isEqualTo: user.email)
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('Moderated Posts')
            .where('UserEmail', isEqualTo: user.email)
            .count()
            .get(),
      ]);
      postCount = results[0].count ?? 0;
      flagCount = results[1].count ?? 0;
    } catch (_) {}

    if (!mounted) return;
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
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: user.role == 'admin'
                      ? const Color(0xFF6C63FF)
                      : const Color(0xFF00B4D8),
                  child: Text(
                    user.email.isNotEmpty
                        ? user.email[0].toUpperCase()
                        : '?',
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
                      Text(user.email,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                      if (user.username.isNotEmpty)
                        Text('@${user.username}',
                            style: const TextStyle(
                                color: Color(0xFF677489),
                                fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.badge_rounded, 'Role',
                user.role == 'admin' ? 'Admin' : 'Member'),
            _detailRow(Icons.circle_rounded,
                'Status',
                user.status == 'banned' ? '🚫 Banned' : '✅ Active'),
            if (user.status == 'banned' && user.banReason.isNotEmpty)
              _detailRow(Icons.info_outline_rounded, 'Ban Reason',
                  user.banReason),
            if (user.bannedAt != null)
              _detailRow(Icons.calendar_today_rounded, 'Banned At',
                  _formatDate(user.bannedAt!)),
            _detailRow(Icons.article_rounded, 'Posts Published',
                '$postCount'),
            _detailRow(Icons.flag_rounded, 'Posts Flagged', '$flagCount'),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9CACCF)),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(
                  color: Color(0xFF677489), fontSize: 13)),
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

  Future<void> _collectForDeletion(
      WriteBatch batch, String collection, String email) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where('UserEmail', isEqualTo: email)
        .get();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
  }

  Future<void> _deleteCollectionGroup(
      String collection, String email) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collectionGroup(collection)
          .where('UserEmail', isEqualTo: email)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  Future<void> _queueEmail(
      String to, String subject, String text) async {
    await FirebaseFirestore.instance.collection('mail').add({
      'to': [to],
      'message': {'subject': subject, 'text': text},
      'createdBy': _myEmail,
      'createdAt': Timestamp.now(),
    });
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(message,
            style: const TextStyle(color: Color(0xFF677489))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Confirm',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _askText(String title, String hint) async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
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
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Submit',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    c.dispose();
    return result;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _AdminUser {
  const _AdminUser({
    required this.email,
    required this.username,
    required this.role,
    required this.status,
    required this.ref,
    required this.banReason,
    required this.bannedAt,
    required this.postCount,
  });
  final String email;
  final String username;
  final String role; // 'admin' | 'user'
  final String status; // 'active' | 'banned'
  final DocumentReference<Map<String, dynamic>>? ref;
  final String banReason;
  final Timestamp? bannedAt;
  final int? postCount;
}

// ── User tile ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.myEmail,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.borderColor,
    required this.onAction,
  });

  final _AdminUser user;
  final String myEmail;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;
  final void Function(_UserAction) onAction;

  bool get _isMe => user.email == myEmail;
  bool get _isAdmin => user.role == 'admin';
  bool get _isBanned => user.status == 'banned';
  bool get _hasProfile => user.ref != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _isBanned
                ? const Color(0xFFFF6B6B)
                : _isAdmin
                    ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                    : borderColor),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _isAdmin
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF00B4D8),
                child: Text(
                  user.email.isNotEmpty
                      ? user.email[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              if (_isAdmin)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                        color: Color(0xFF6C63FF), shape: BoxShape.circle),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.white, size: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(user.email,
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (_isMe)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                if (user.username.isNotEmpty)
                  Text('@${user.username}',
                      style: TextStyle(color: mutedColor, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _RoleBadge(role: _isAdmin ? 'Admin' : 'Member',
                        isAdmin: _isAdmin),
                    if (_isBanned) const _StatusBadge('Banned'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action menu
          _buildActionMenu(context),
        ],
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    // Discovered users have no Firestore profile — show "not registered" badge
    if (!_hasProfile) {
      return Tooltip(
        message:
            'User found in posts but has no profile document in Users collection',
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB84D).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFFFFB84D).withValues(alpha: 0.4)),
          ),
          child: const Text('Not registered',
              style: TextStyle(
                  color: Color(0xFFB07A00),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
      );
    }

    // Build menu items based on role:
    // - Regular users: view, promote to admin, ban/unban, change username, remove
    // - Admins: view, demote (no ban/remove while still admin)
    // - Self: view only (can't modify own account)
    final items = <PopupMenuItem<_UserAction>>[];

    // Everyone can be viewed
    items.add(const PopupMenuItem(
      value: _UserAction.viewDetails,
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF677489)),
        SizedBox(width: 8),
        Text('View full details'),
      ]),
    ));

    if (!_isMe) {
      if (_isAdmin) {
        // FIX: For admins — only show demote option
        items.add(const PopupMenuItem(
          value: _UserAction.demoteFromAdmin,
          child: Row(children: [
            Icon(Icons.arrow_downward_rounded,
                size: 16, color: Color(0xFFFF9F43)),
            SizedBox(width: 8),
            Text('Demote to member'),
          ]),
        ));
      } else {
        // FIX: For regular users — show all management actions
        items.add(const PopupMenuItem(
          value: _UserAction.promoteToAdmin,
          child: Row(children: [
            Icon(Icons.arrow_upward_rounded,
                size: 16, color: Color(0xFF6C63FF)),
            SizedBox(width: 8),
            Text('Promote to admin'),
          ]),
        ));

        if (_isBanned) {
          items.add(const PopupMenuItem(
            value: _UserAction.unbanUser,
            child: Row(children: [
              Icon(Icons.lock_open_rounded,
                  size: 16, color: Color(0xFF00C49A)),
              SizedBox(width: 8),
              Text('Unban user'),
            ]),
          ));
        } else {
          items.add(const PopupMenuItem(
            value: _UserAction.banUser,
            child: Row(children: [
              Icon(Icons.block_rounded,
                  size: 16, color: Color(0xFFFF6B6B)),
              SizedBox(width: 8),
              Text('Ban user', style: TextStyle(color: Color(0xFFFF6B6B))),
            ]),
          ));
        }

        items.add(const PopupMenuItem(
          value: _UserAction.changeUsername,
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 16, color: Color(0xFF677489)),
            SizedBox(width: 8),
            Text('Request username change'),
          ]),
        ));

        items.add(const PopupMenuItem(
          value: _UserAction.removeUserData,
          child: Row(children: [
            Icon(Icons.delete_forever_rounded,
                size: 16, color: Color(0xFFFF6B6B)),
            SizedBox(width: 8),
            Text('Remove all user data',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ]),
        ));
      }
    }

    return PopupMenuButton<_UserAction>(
      onSelected: onAction,
      itemBuilder: (_) => items,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      icon: const Icon(Icons.more_vert_rounded, size: 20),
    );
  }
}

// ── Small badge widgets ───────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.isAdmin});
  final String role;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final color =
        isAdmin ? const Color(0xFF6C63FF) : const Color(0xFF00B4D8);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFFFF6B6B),
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }
}

// class _DiscoveredBadge extends StatelessWidget {
//   const _DiscoveredBadge();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//       decoration: BoxDecoration(
//         color: const Color(0xFFFFB84D).withValues(alpha: 0.12),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: const Text('Discovered',
//           style: TextStyle(
//               color: Color(0xFFB07A00),
//               fontSize: 10,
//               fontWeight: FontWeight.w700)),
//     );
//   }
// }
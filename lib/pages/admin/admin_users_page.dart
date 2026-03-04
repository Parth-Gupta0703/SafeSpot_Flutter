import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

enum _UserAction { promoteOrDemote, banOrUnban, requestUsernameChange, removeUser }

class _AdminUsersPageState extends State<AdminUsersPage>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _filterRole = 'all';
  bool _includeDiscovered = true;
  Future<Set<String>>? _activityEmailsFuture;
  late TabController _tabController;

  String get _adminEmail =>
      FirebaseAuth.instance.currentUser?.email ?? 'admin@safespot.local';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
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
      final snapshots = await Future.wait([
        FirebaseFirestore.instance.collection('User Posts').get(),
        FirebaseFirestore.instance.collection('Moderated Posts').get(),
        FirebaseFirestore.instance.collection('Moderated Comments').get(),
        FirebaseFirestore.instance.collectionGroup('Comments').get(),
        FirebaseFirestore.instance.collectionGroup('Replies').get(),
      ]);
      final emails = <String>{};
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          final raw = (doc.data()['UserEmail'] ?? doc.data()['email'] ?? '').toString();
          final email = raw.trim().toLowerCase();
          if (email.contains('@')) emails.add(email);
        }
      }
      return emails;
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _refreshDiscovered() async {
    setState(() => _activityEmailsFuture = _fetchActivityEmails());
    await _activityEmailsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1220) : const Color(0xFFF3F6FF);
    final card = isDark ? const Color(0xFF1A1F34) : Colors.white;
    final text = isDark ? const Color(0xFFE7EDFF) : const Color(0xFF2D3142);
    final muted = isDark ? const Color(0xFF9CACCF) : const Color(0xFF667086);
    final border = isDark ? const Color(0xFF2B3656) : const Color(0xFFD6DCEE);

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF151C31) : const Color(0xFFE7EDFF),
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(18, 56, 18, 14),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFFF8FAB)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.people_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('Users').snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? const [];
                      final admins = docs.where((d) => (d.data()['role'] ?? '').toString().toLowerCase() == 'admin').length;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User Management', style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 20)),
                          Text('${docs.length} total, $admins admins', style: TextStyle(color: muted, fontSize: 12)),
                        ],
                      );
                    },
                  ),
                ]),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF6C63FF),
              labelColor: const Color(0xFF6C63FF),
              unselectedLabelColor: muted,
              tabs: const [Tab(text: 'All Users'), Tab(text: 'Admins'), Tab(text: 'Members')],
            ),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(children: [
                TextField(
                  style: TextStyle(color: text),
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by email or username...',
                    hintStyle: TextStyle(color: muted),
                    prefixIcon: Icon(Icons.search_rounded, color: muted),
                    filled: true,
                    fillColor: card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6C63FF))),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  FilterChip(
                    selected: _includeDiscovered,
                    label: const Text('Include discovered'),
                    onSelected: (v) => setState(() => _includeDiscovered = v),
                  ),
                  const Spacer(),
                  IconButton(onPressed: _refreshDiscovered, icon: const Icon(Icons.refresh_rounded)),
                ]),
              ]),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('Users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final byEmail = <String, _AdminUser>{};
                  for (final doc in (snapshot.data?.docs ?? const [])) {
                    final data = doc.data();
                    final email = ((data['email'] ?? '').toString()).trim().toLowerCase();
                    if (!email.contains('@')) continue;
                    byEmail[email] = _AdminUser(
                      email: email,
                      username: (data['username'] ?? '').toString(),
                      role: (data['role'] ?? 'user').toString().toLowerCase() == 'admin' ? 'admin' : 'user',
                      status: (data['status'] ?? 'active').toString().toLowerCase() == 'banned' ? 'banned' : 'active',
                      ref: doc.reference,
                      discoveredOnly: false,
                    );
                  }

                  Widget buildList(List<_AdminUser> users) {
                    if (users.isEmpty) return Center(child: Text('No users found', style: TextStyle(color: muted)));
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _UserTile(
                        user: users[i],
                        cardColor: card,
                        textColor: text,
                        mutedColor: muted,
                        borderColor: border,
                        onAction: (action) => _onAction(users[i], action),
                      ),
                    );
                  }

                  List<_AdminUser> filterAndSort(Iterable<_AdminUser> input) {
                    final filtered = input.where((u) {
                      if (_filterRole != 'all' && u.role != _filterRole) return false;
                      if (_searchQuery.isEmpty) return true;
                      return u.email.contains(_searchQuery) || u.username.toLowerCase().contains(_searchQuery);
                    }).toList();
                    filtered.sort((a, b) => a.email.compareTo(b.email));
                    return filtered;
                  }

                  if (!_includeDiscovered) return buildList(filterAndSort(byEmail.values));

                  return FutureBuilder<Set<String>>(
                    future: _activityEmailsFuture,
                    builder: (_, activity) {
                      for (final email in (activity.data ?? const <String>{})) {
                        byEmail.putIfAbsent(
                          email,
                          () => _AdminUser(
                            email: email,
                            username: '',
                            role: 'user',
                            status: 'active',
                            ref: null,
                            discoveredOnly: true,
                          ),
                        );
                      }
                      return buildList(filterAndSort(byEmail.values));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(_AdminUser user, _UserAction action) async {
    if (user.ref == null) {
      _snack('Discovered user only. No profile doc to modify.');
      return;
    }
    switch (action) {
      case _UserAction.promoteOrDemote:
        final promote = user.role != 'admin';
        if (!await _confirm(promote ? 'Promote user?' : 'Demote admin?', promote ? 'This will grant admin access to ${user.email}.' : 'This will revoke admin access from ${user.email}.')) return;
        await user.ref!.update({'role': promote ? 'admin' : 'user'});
        _snack(promote ? 'User promoted' : 'User demoted');
        break;
      case _UserAction.banOrUnban:
        final ban = user.status != 'banned';
        var reason = '';
        if (ban) {
          final asked = await _askText('Ban reason', 'Why are you banning this user?');
          if (asked == null || asked.trim().isEmpty) return;
          reason = asked.trim();
        }
        if (!await _confirm(ban ? 'Ban user?' : 'Unban user?', ban ? '${user.email} will be blocked from app access.' : '${user.email} will regain app access.')) return;
        await user.ref!.update(ban
            ? {'status': 'banned', 'role': 'user', 'banReason': reason, 'bannedAt': Timestamp.now(), 'bannedBy': _adminEmail}
            : {'status': 'active', 'banReason': FieldValue.delete(), 'bannedAt': FieldValue.delete(), 'bannedBy': FieldValue.delete()});
        await _queueEmail(user.email, ban ? 'SafeSpot account suspended' : 'SafeSpot account reactivated', ban ? 'Your account was suspended.\nReason: $reason' : 'Your account is active again.');
        _snack(ban ? 'User banned and email queued' : 'User unbanned and email queued');
        break;
      case _UserAction.requestUsernameChange:
        final reason = await _askText('Request username change', 'Reason to ask username change');
        if (reason == null || reason.trim().isEmpty) return;
        if (!await _confirm('Send username change request?', 'An email will be queued for ${user.email}.')) return;
        await user.ref!.update({
          'usernameChangeRequested': true,
          'usernameChangeReason': reason.trim(),
          'usernameChangeRequestedAt': Timestamp.now(),
          'usernameChangeRequestedBy': _adminEmail,
        });
        await _queueEmail(user.email, 'SafeSpot username update requested', 'Please change your username.\nReason: ${reason.trim()}');
        _snack('Username change request saved and email queued');
        break;
      case _UserAction.removeUser:
        if (!await _confirm('Remove user data?', 'This deletes user profile and related content for ${user.email}.')) return;
        await _deleteByEmail('User Posts', user.email);
        await _deleteByEmail('Moderated Posts', user.email);
        await _deleteByEmail('Moderated Comments', user.email);
        await _deleteByEmailGroup('Comments', user.email);
        await _deleteByEmailGroup('Replies', user.email);
        await user.ref!.delete();
        await _queueEmail(user.email, 'SafeSpot account removed', 'Your account data has been removed by an admin.');
        _snack('User removed and email queued');
        break;
    }
  }

  Future<void> _deleteByEmail(String collection, String email) async {
    final snap = await FirebaseFirestore.instance.collection(collection).where('UserEmail', isEqualTo: email).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _deleteByEmailGroup(String collection, String email) async {
    try {
      final snap = await FirebaseFirestore.instance.collectionGroup(collection).where('UserEmail', isEqualTo: email).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  Future<void> _queueEmail(String to, String subject, String text) async {
    await FirebaseFirestore.instance.collection('mail').add({
      'to': [to],
      'message': {'subject': subject, 'text': text},
      'createdBy': _adminEmail,
      'createdAt': Timestamp.now(),
    });
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
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
        title: Text(title),
        content: TextField(controller: c, maxLines: 3, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Submit')),
        ],
      ),
    );
    c.dispose();
    return result;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class _AdminUser {
  const _AdminUser({
    required this.email,
    required this.username,
    required this.role,
    required this.status,
    required this.ref,
    required this.discoveredOnly,
  });

  final String email;
  final String username;
  final String role;
  final String status;
  final DocumentReference<Map<String, dynamic>>? ref;
  final bool discoveredOnly;
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.borderColor,
    required this.onAction,
  });

  final _AdminUser user;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;
  final Future<void> Function(_UserAction) onAction;

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == 'admin';
    final isBanned = user.status == 'banned';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isBanned ? const Color(0xFFFF6B6B) : borderColor),
      ),
      child: Row(children: [
        CircleAvatar(backgroundColor: const Color(0xFF6C63FF), child: Text(user.email.isNotEmpty ? user.email[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.email, style: TextStyle(color: textColor, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          if (user.username.isNotEmpty) Text('@${user.username}', style: TextStyle(color: mutedColor, fontSize: 12)),
          const SizedBox(height: 4),
          Text('${isAdmin ? 'Admin' : 'Member'}${isBanned ? ' • Banned' : ''}${user.discoveredOnly ? ' • Discovered' : ''}', style: TextStyle(color: mutedColor, fontSize: 12)),
        ])),
        if (user.ref == null)
          Text('Read only', style: TextStyle(color: mutedColor, fontSize: 12))
        else
          PopupMenuButton<_UserAction>(
            onSelected: onAction,
            itemBuilder: (_) => [
              PopupMenuItem(value: _UserAction.promoteOrDemote, child: Text(isAdmin ? 'Demote' : 'Promote')),
              PopupMenuItem(value: _UserAction.banOrUnban, child: Text(isBanned ? 'Unban user' : 'Ban user')),
              const PopupMenuItem(value: _UserAction.requestUsernameChange, child: Text('Request username change')),
              const PopupMenuItem(value: _UserAction.removeUser, child: Text('Remove user data')),
            ],
          ),
      ]),
    );
  }
}

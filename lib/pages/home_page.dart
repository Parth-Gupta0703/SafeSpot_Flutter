import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_media/components/user_post.dart';
import 'package:social_media/services/moderation_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser!;
  final textController = TextEditingController();
  final ModerationService _moderationService = ModerationService();
  late AnimationController _fabController;
  bool _isSubmittingPost = false;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    unawaited(_moderationService.startWarmUpSequence()); // Moderation service warms up --> Reduce first request delay
  }

  @override
  void dispose() {
    _moderationService.dispose();
    _fabController.dispose();
    textController.dispose();
    super.dispose();
  }

  Future<void> postMessage(BuildContext sheetContext) async {
    final postText = textController.text.trim();
    if (postText.isEmpty || _isSubmittingPost) return;

    setState(() => _isSubmittingPost = true);

    try {
      final moderationResult = await _moderationService.moderatePost(postText);

      if (!mounted) return;

      if (moderationResult.action == 'allow') {
        await FirebaseFirestore.instance.collection('User Posts').add({
          'UserEmail': user.email,
          'UserId': user.uid,
          'Message': postText,
          'TimeStamp': Timestamp.now(),
          'Likes': [],
        });

        textController.clear();
        if (!mounted) return;

        if (sheetContext.mounted) {
          Navigator.of(sheetContext).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('Moderated Posts').add({
        'UserEmail': user.email,
        'UserId': user.uid,
        'Message': postText,
        'Reason': moderationResult.reason,
        'MatchedCount': moderationResult.matchedCount,
        'TimeStamp': Timestamp.now(),
      });

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Post removed'),
          content: Text(
            moderationResult.reason.isNotEmpty
                ? moderationResult.reason
                : 'This post violated moderation rules.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit post right now'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingPost = false);
      }
    }
  }

  void _showCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCreatePostSheet(),
    );
  }

  Widget _buildCreatePostSheet() {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 300),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB4A7D6), Color(0xFFD8B4E2)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Create Post',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextField(
                controller: textController,
                maxLines: 5,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmittingPost
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.grey[700],
                        elevation: 0,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmittingPost
                          ? null
                          : () {
                              postMessage(context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB4A7D6),
                      ),
                      child: _isSubmittingPost
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Post'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 300),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFB6C1),
                    Color(0xFFFFDAB9),
                  ], // Pink to Peach
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('SafeSpot'),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Color(0xFFB4A7D6)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfilePage(user: user)),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.logout, color: Color(0xFFFF6B6B)),
            ),
            onPressed: () {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: const [
                      Icon(Icons.logout, color: Color(0xFFFF6B6B)),
                      SizedBox(width: 12),
                      Text('Logout?'),
                    ],
                  ),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        _moderationService.cancelWarmUpSequence();
                        Navigator.pop(context);
                        await FirebaseAuth.instance.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 151, 210, 230), // Light blue
                Color(0xFFFFF0F5), // Very light pink
                Color(0xFFFFEFD5), // Peachy pink
              ],
            ),  
          ),

          child: SafeArea(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('User Posts')
                  .orderBy('TimeStamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFB4A7D6)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0x1AB4A7D6), // 0.1 opacity
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: Color(0xFFB4A7D6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No posts yet!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to share something',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 16, bottom: 120),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    return TweenAnimationBuilder(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: UserPost(post: doc),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 1500),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, double value, child) {
          // Bounce effect
          final bounce = (value < 0.5 ? value * 2 : (1 - value) * 2);
          return Transform.translate(
            offset: Offset(0, -10 * bounce),
            child: child,
          );
        },
        onEnd: () {
          // Restart animation
          if (mounted) setState(() {});
        },
        child: FloatingActionButton.extended(
          onPressed: _showCreatePostSheet,
          backgroundColor: const Color(0xFFB4A7D6),
          elevation: 4,
          icon: const Icon(Icons.add),
          label: const Text('Post'),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final User user;
  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _userPostsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _moderatedPostsStream;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedModeratedDocs = [];
  bool _hasModeratedSnapshot = false;

  @override
  void initState() {
    super.initState();
    _userPostsStream = FirebaseFirestore.instance
        .collection('User Posts')
        .where('UserId', isEqualTo: widget.user.uid)
        .snapshots();
    _moderatedPostsStream = FirebaseFirestore.instance
        .collection('Moderated Posts')
        .where('UserId', isEqualTo: widget.user.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE5EC), // Light pink
              Color(0xFFFFF0F5), // Very light pink
              Color(0xFFFFEFD5), // Peachy pink
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Profile Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB4A7D6), Color(0xFFD8B4E2)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0x1AB4A7D6), // 0.1 opacity
                    child: Text(
                      widget.user.email![0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB4A7D6),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                widget.user.email!.split('@')[0],
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.user.email!,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),

              const SizedBox(height: 32),

              // Stats Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _userPostsStream,
                  builder: (context, snapshot) {
                    int postCount = snapshot.hasData
                        ? snapshot.data!.docs.length
                        : 0;

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Posts',
                            postCount.toString(),
                            Icons.article_outlined,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Member',
                            'Since ${DateTime.now().year}',
                            Icons.calendar_today,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Moderated posts section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Moderated Posts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _moderatedPostsStream,
                          builder: (context, snapshot) {
                            final freshDocs = snapshot.data?.docs.toList();
                            if (freshDocs != null) {
                              freshDocs.sort((a, b) {
                                final aTimestamp = a.data()['TimeStamp'];
                                final bTimestamp = b.data()['TimeStamp'];
                                final aMillis = aTimestamp is Timestamp
                                    ? aTimestamp.millisecondsSinceEpoch
                                    : 0;
                                final bMillis = bTimestamp is Timestamp
                                    ? bTimestamp.millisecondsSinceEpoch
                                    : 0;
                                return bMillis.compareTo(aMillis);
                              });
                              _cachedModeratedDocs = freshDocs;
                              _hasModeratedSnapshot = true;
                            }

                            final docs = _cachedModeratedDocs;

                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !_hasModeratedSnapshot &&
                                docs.isEmpty) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFB4A7D6),
                                ),
                              );
                            }

                            if (snapshot.hasError && docs.isEmpty) {
                              return Center(
                                child: Text(
                                  'Unable to load moderated posts right now',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }

                            if (docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check_circle,
                                        size: 64,
                                        color: Colors.green[300],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No moderated posts!',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'All your posts are clean and safe',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              key: const PageStorageKey<String>(
                                'profile_moderated_posts',
                              ),
                              padding: const EdgeInsets.only(bottom: 12),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data();
                                final timestamp = data['TimeStamp'];
                                final reason = data['Reason']?.toString();
                                final message =
                                    data['Message']?.toString() ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red[200]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.block,
                                            color: Colors.red[400],
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Blocked by AI Moderator',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF2D3142),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Reason: ${reason?.isNotEmpty == true ? reason : 'Inappropriate content'}',
                                          style: TextStyle(
                                            color: Colors.red[900],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        timestamp is Timestamp
                                            ? timeago.format(timestamp.toDate())
                                            : 'Recently',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFB4A7D6), size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3142),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

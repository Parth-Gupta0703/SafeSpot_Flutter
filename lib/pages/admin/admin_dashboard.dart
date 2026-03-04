import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_overview_page.dart';
import 'admin_users_page.dart';
import 'admin_posts_page.dart';
import 'admin_moderation_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<Widget> _pages = const [
    AdminOverviewPage(),
    AdminUsersPage(),
    AdminPostsPage(),
    AdminModerationPage(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.dashboard_rounded, Icons.dashboard_outlined, "Overview"),
    _NavItem(Icons.people_rounded, Icons.people_outline_rounded, "Users"),
    _NavItem(Icons.article_rounded, Icons.article_outlined, "Posts"),
    _NavItem(Icons.shield_rounded, Icons.shield_outlined, "Moderation"),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _index) return;
    _fadeController.reverse().then((_) {
      setState(() => _index = index);
      _fadeController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: [
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
      backgroundColor: isDark
          ? const Color(0xFF0F1220)
          : const Color(0xFFF4F8FF),
      body: FadeTransition(opacity: _fadeAnimation, child: _pages[_index]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171D31) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2A3454) : const Color(0xFFD7DCE5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final isSelected = i == _index;
              final item = _navItems[i];
              return GestureDetector(
                onTap: () => _onTabTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 20 : 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFFFF8FAB)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFF9BA8CC)
                                  : const Color(0xFF677489)),
                        size: 22,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const _NavItem(this.activeIcon, this.icon, this.label);
}

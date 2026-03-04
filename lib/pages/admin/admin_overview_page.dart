import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F1220) : const Color(0xFFF4F8FF);

    return Scaffold(
      backgroundColor: pageBg,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context),
          SliverPadding(
            padding: const EdgeInsets.all(14),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildKpiGrid(context),
                const SizedBox(height: 16),
                _buildTrendChart(context),
                const SizedBox(height: 16),
                _buildRoleAndRiskRow(context),
                const SizedBox(height: 16),
                _buildTopContributors(context),
                const SizedBox(height: 16),
                _buildRecentEvents(context),
                const SizedBox(height: 10),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF171D31) : const Color(0xFFE8EEFF),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF171D31), Color(0xFF1E2950)]
                  : const [Color(0xFFE8EEFF), Color(0xFFF4EAFE)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 54, 18, 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF8FAB)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dashboard_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                'Admin Dashboard',
                style: TextStyle(
                  color: isDark ? const Color(0xFFE7EDFF) : const Color(0xFF2D3142),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _streamCountCard(context, 'Users', Icons.people_rounded, const Color(0xFF6C63FF),
            FirebaseFirestore.instance.collection('Users').snapshots(),
            countFromUsers: (docs) => docs.length),
        _streamCountCard(context, 'Admins', Icons.admin_panel_settings_rounded, const Color(0xFF00B4D8),
            FirebaseFirestore.instance.collection('Users').snapshots(),
            countFromUsers: (docs) => docs.where((d) => (d.data()['role'] ?? '').toString().toLowerCase() == 'admin').length),
        _streamCountCard(context, 'Banned', Icons.gpp_bad_rounded, const Color(0xFFFF6B6B),
            FirebaseFirestore.instance.collection('Users').snapshots(),
            countFromUsers: (docs) => docs.where((d) => (d.data()['status'] ?? '').toString().toLowerCase() == 'banned').length),
        _streamCountCard(context, 'Posts', Icons.article_rounded, const Color(0xFF9B59B6),
            FirebaseFirestore.instance.collection('User Posts').snapshots()),
        _streamCountCard(context, 'Flag Posts', Icons.flag_rounded, const Color(0xFFEE5A24),
            FirebaseFirestore.instance.collection('Moderated Posts').snapshots()),
        _streamCountCard(context, 'Flag Com.', Icons.comment_rounded, const Color(0xFFFFB84D),
            FirebaseFirestore.instance.collection('Moderated Comments').snapshots()),
      ],
    );
  }

  Widget _streamCountCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    Stream<QuerySnapshot<Map<String, dynamic>>> stream, {
    int Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)? countFromUsers,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final count = countFromUsers != null ? countFromUsers(docs) : docs.length;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F34) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const Spacer(),
              Text('$count',
                  style: TextStyle(
                      color: isDark ? const Color(0xFFE7EDFF) : const Color(0xFF2D3142),
                      fontWeight: FontWeight.w800,
                      fontSize: 20)),
              Text(label, style: TextStyle(color: isDark ? const Color(0xFF9CACCF) : const Color(0xFF6B7280), fontSize: 11)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendChart(BuildContext context) {
    return _card(
      context,
      title: '7-Day Content & Moderation Trend',
      child: SizedBox(
        height: 220,
        child: FutureBuilder<_TrendData>(
          future: _loadTrendData(),
          builder: (_, snapshot) {
            final data = snapshot.data ?? _TrendData.empty();
            return LineChart(
              LineChartData(
                minY: 0,
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][v.toInt() % 7], style: const TextStyle(fontSize: 10)))),
                ),
                lineBarsData: [
                  _line(data.posts, const Color(0xFF6C63FF)),
                  _line(data.flaggedPosts, const Color(0xFFFF6B6B)),
                  _line(data.flaggedComments, const Color(0xFFFFB84D)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleAndRiskRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _card(
            context,
            title: 'Role Distribution',
            child: SizedBox(
              height: 200,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('Users').snapshots(),
                builder: (_, snapshot) {
                  final docs = snapshot.data?.docs ?? const [];
                  final admins = docs.where((d) => (d.data()['role'] ?? '').toString().toLowerCase() == 'admin').length.toDouble();
                  final banned = docs.where((d) => (d.data()['status'] ?? '').toString().toLowerCase() == 'banned').length.toDouble();
                  final users = (docs.length - admins.toInt()).toDouble();
                  return PieChart(PieChartData(sections: [
                    PieChartSectionData(value: admins == 0 ? 1 : admins, color: const Color(0xFF6C63FF), title: 'Admin'),
                    PieChartSectionData(value: users == 0 ? 1 : users, color: const Color(0xFF00B4D8), title: 'Users'),
                    PieChartSectionData(value: banned == 0 ? 1 : banned, color: const Color(0xFFFF6B6B), title: 'Banned'),
                  ], centerSpaceRadius: 24));
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _card(
            context,
            title: 'Moderation Risk',
            child: SizedBox(
              height: 200,
              child: FutureBuilder<_RiskData>(
                future: _loadRiskData(),
                builder: (_, snapshot) {
                  final r = snapshot.data ?? const _RiskData(0, 0);
                  final ratio = r.totalPosts == 0 ? 0.0 : (r.flagged / r.totalPosts).clamp(0, 1).toDouble();
                  final percent = (ratio * 100).toStringAsFixed(1);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(value: ratio, strokeWidth: 10, color: const Color(0xFFFF6B6B), backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.18)),
                            Center(child: Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('${r.flagged} flagged out of ${r.totalPosts} posts', textAlign: TextAlign.center),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopContributors(BuildContext context) {
    return _card(
      context,
      title: 'Top Contributors (Posts)',
      child: SizedBox(
        height: 220,
        child: FutureBuilder<List<MapEntry<String, int>>>(
          future: _loadTopContributors(),
          builder: (_, snapshot) {
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) return const Center(child: Text('No data'));
            return BarChart(
              BarChartData(
                barGroups: List.generate(entries.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: entries[i].value.toDouble(), color: const Color(0xFF6C63FF), width: 18)])),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                    final email = entries[i].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(email.split('@').first, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                    );
                  })),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecentEvents(BuildContext context) {
    return _card(
      context,
      title: 'Recent Events',
      child: FutureBuilder<List<_RecentEvent>>(
        future: _loadRecentEvents(),
        builder: (_, snapshot) {
          final events = snapshot.data ?? const [];
          if (events.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('No events'));
          return Column(
            children: events.take(8).map((e) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(e.icon, size: 18, color: e.color),
              title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(e.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            )).toList(),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, {required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F34) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2A3554) : const Color(0xFFD8DEEE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFE7EDFF) : const Color(0xFF2D3142))),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  LineChartBarData _line(List<int> values, Color color) {
    return LineChartBarData(
      spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i].toDouble())),
      color: color,
      isCurved: true,
      barWidth: 3,
      dotData: const FlDotData(show: false),
    );
  }

  Future<_TrendData> _loadTrendData() async {
    final start = DateTime.now().subtract(const Duration(days: 6));
    final snaps = await Future.wait([
      FirebaseFirestore.instance.collection('User Posts').where('TimeStamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).get(),
      FirebaseFirestore.instance.collection('Moderated Posts').where('TimeStamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).get(),
      FirebaseFirestore.instance.collection('Moderated Comments').where('TimeStamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).get(),
    ]);
    List<int> c(QuerySnapshot<Map<String, dynamic>> s) {
      final out = List<int>.filled(7, 0);
      for (final d in s.docs) {
        final ts = d.data()['TimeStamp'];
        if (ts is! Timestamp) continue;
        final idx = ts.toDate().weekday - 1;
        if (idx >= 0 && idx < 7) out[idx] += 1;
      }
      return out;
    }
    return _TrendData(c(snaps[0]), c(snaps[1]), c(snaps[2]));
  }

  Future<_RiskData> _loadRiskData() async {
    final snaps = await Future.wait([
      FirebaseFirestore.instance.collection('User Posts').get(),
      FirebaseFirestore.instance.collection('Moderated Posts').get(),
      FirebaseFirestore.instance.collection('Moderated Comments').get(),
    ]);
    final posts = snaps[0].docs.length;
    final flagged = snaps[1].docs.length + snaps[2].docs.length;
    return _RiskData(posts, flagged);
  }

  Future<List<MapEntry<String, int>>> _loadTopContributors() async {
    final snap = await FirebaseFirestore.instance.collection('User Posts').limit(300).get();
    final map = <String, int>{};
    for (final doc in snap.docs) {
      final email = (doc.data()['UserEmail'] ?? '').toString().toLowerCase();
      if (!email.contains('@')) continue;
      map[email] = (map[email] ?? 0) + 1;
    }
    final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(6).toList();
  }

  Future<List<_RecentEvent>> _loadRecentEvents() async {
    final snaps = await Future.wait([
      FirebaseFirestore.instance.collection('User Posts').orderBy('TimeStamp', descending: true).limit(6).get(),
      FirebaseFirestore.instance.collection('Moderated Posts').orderBy('TimeStamp', descending: true).limit(6).get(),
      FirebaseFirestore.instance.collection('Moderated Comments').orderBy('TimeStamp', descending: true).limit(6).get(),
    ]);
    final events = <_RecentEvent>[];
    for (final doc in snaps[0].docs) {
      events.add(_RecentEvent(
        icon: Icons.article_rounded,
        color: const Color(0xFF6C63FF),
        title: 'New post by ${(doc.data()['UserEmail'] ?? 'unknown').toString()}',
        subtitle: (doc.data()['Message'] ?? 'Post content').toString(),
        ts: doc.data()['TimeStamp'] as Timestamp?,
      ));
    }
    for (final doc in snaps[1].docs) {
      events.add(_RecentEvent(
        icon: Icons.flag_rounded,
        color: const Color(0xFFFF6B6B),
        title: 'Flagged post',
        subtitle: (doc.data()['Reason'] ?? 'Moderation trigger').toString(),
        ts: doc.data()['TimeStamp'] as Timestamp?,
      ));
    }
    for (final doc in snaps[2].docs) {
      events.add(_RecentEvent(
        icon: Icons.comment_rounded,
        color: const Color(0xFFFFB84D),
        title: 'Flagged comment/reply',
        subtitle: (doc.data()['Reason'] ?? 'Moderation trigger').toString(),
        ts: doc.data()['TimeStamp'] as Timestamp?,
      ));
    }
    events.sort((a, b) => (b.ts?.millisecondsSinceEpoch ?? 0).compareTo(a.ts?.millisecondsSinceEpoch ?? 0));
    return events;
  }
}

class _TrendData {
  const _TrendData(this.posts, this.flaggedPosts, this.flaggedComments);
  final List<int> posts;
  final List<int> flaggedPosts;
  final List<int> flaggedComments;

  factory _TrendData.empty() => _TrendData(
        List<int>.filled(7, 0),
        List<int>.filled(7, 0),
        List<int>.filled(7, 0),
      );
}

class _RiskData {
  const _RiskData(this.totalPosts, this.flagged);
  final int totalPosts;
  final int flagged;
}

class _RecentEvent {
  const _RecentEvent({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.ts,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Timestamp? ts;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'admin_dashboard.dart'; // AdminPageHeader

class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1220) : const Color(0xFFF4F8FF),
      body: CustomScrollView(
        slivers: [
          // FIX: Header now contains title + admin email + logout button
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor:
                isDark ? const Color(0xFF171D31) : const Color(0xFFE8EEFF),
            flexibleSpace: FlexibleSpaceBar(
              background: AdminPageHeader(
                title: 'Admin Dashboard',
                subtitle:
                    'SafeSpot Control Panel',
                iconData: Icons.dashboard_rounded,
                fromColor: const Color(0xFF6C63FF),
                toColor: const Color(0xFFFF8FAB),
              ),
            ),
          ),
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
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI cards ──────────────────────────────────────────────────────────────

  Widget _buildKpiGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _kpiCard(context, 'Users', Icons.people_rounded, const Color(0xFF6C63FF),
            FirebaseFirestore.instance.collection('Users').snapshots(),
            tooltip: 'Total registered accounts'),
        _kpiCard(context, 'Admins', Icons.admin_panel_settings_rounded,
            const Color(0xFF00B4D8),
            FirebaseFirestore.instance.collection('Users').snapshots(),
            countFn: (docs) => docs
                .where((d) =>
                    (d.data()['role'] ?? '').toString().toLowerCase() == 'admin')
                .length,
            tooltip: 'Users with admin role'),
        _kpiCard(context, 'Banned', Icons.gpp_bad_rounded, const Color(0xFFFF6B6B),
            FirebaseFirestore.instance.collection('Users').snapshots(),
            countFn: (docs) => docs
                .where((d) =>
                    (d.data()['status'] ?? '').toString().toLowerCase() ==
                    'banned')
                .length,
            tooltip: 'Currently banned accounts'),
        _kpiCard(context, 'Posts', Icons.article_rounded, const Color(0xFF9B59B6),
            FirebaseFirestore.instance.collection('User Posts').snapshots(),
            tooltip: 'Total published posts'),
        _kpiCard(context, 'Flagged', Icons.flag_rounded, const Color(0xFFEE5A24),
            FirebaseFirestore.instance
                .collection('Moderated Posts')
                .snapshots(),
            tooltip: 'Posts pending review'),
        _kpiCard(context, 'Flag Cmt', Icons.comment_rounded,
            const Color(0xFFFFB84D),
            FirebaseFirestore.instance
                .collection('Moderated Comments')
                .snapshots(),
            tooltip: 'Comments pending review'),
      ],
    );
  }

  Widget _kpiCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    Stream<QuerySnapshot<Map<String, dynamic>>> stream, {
    int Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)? countFn,
    String tooltip = '',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (_, snap) {
          final docs = snap.data?.docs ?? const [];
          final count = countFn != null ? countFn(docs) : docs.length;
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1F34) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: color),
                const Spacer(),
                Text('$count',
                    style: TextStyle(
                        color: isDark
                            ? const Color(0xFFE7EDFF)
                            : const Color(0xFF2D3142),
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
                Text(label,
                    style: TextStyle(
                        color: isDark
                            ? const Color(0xFF9CACCF)
                            : const Color(0xFF6B7280),
                        fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 7-day trend chart ──────────────────────────────────────────────────────

  Widget _buildTrendChart(BuildContext context) {
    return _card(
      context,
      title: '7-Day Activity Trend',
      // FIX: Added description explaining what each line means
      description:
          'Daily count of new posts created vs content flagged for moderation.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIX: Chart legend so each line is explained
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: const [
              _LegendDot(color: Color(0xFF6C63FF), label: 'New Posts'),
              _LegendDot(
                  color: Color(0xFFFF6B6B), label: 'Flagged Posts'),
              _LegendDot(
                  color: Color(0xFFFFB84D), label: 'Flagged Comments'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: FutureBuilder<_TrendData>(
              future: _loadTrendData(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF)));
                }
                final d = snap.data!;
                final allVals = [...d.posts, ...d.flaggedPosts, ...d.flaggedComments];
                final maxY = (allVals.isEmpty
                        ? 5
                        : allVals.reduce((a, b) => a > b ? a : b) + 2)
                    .toDouble();
                return LineChart(LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0xFFE6EAF2), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 28)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          const days = [
                            'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                          ];
                          final i = v.toInt();
                          if (i < 0 || i >= days.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(days[i],
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF9CACCF))),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    _line(d.posts, const Color(0xFF6C63FF)),
                    _line(d.flaggedPosts, const Color(0xFFFF6B6B)),
                    _line(d.flaggedComments, const Color(0xFFFFB84D)),
                  ],
                ));
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Role pie + Risk gauge ──────────────────────────────────────────────────

  Widget _buildRoleAndRiskRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _card(
            context,
            title: 'User Roles',
            // FIX: description explains what the pie shows
            description: 'Breakdown of all accounts by their current role.',
            child: Column(
              children: [
                SizedBox(
                  height: 160,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('Users')
                        .snapshots(),
                    builder: (_, snap) {
                      final docs = snap.data?.docs ?? const [];
                      final adminN = docs
                          .where((d) =>
                              (d.data()['role'] ?? '')
                                  .toString()
                                  .toLowerCase() ==
                              'admin')
                          .length
                          .toDouble();
                      final bannedN = docs
                          .where((d) =>
                              (d.data()['status'] ?? '')
                                  .toString()
                                  .toLowerCase() ==
                              'banned')
                          .length
                          .toDouble();
                      final userN =
                          (docs.length - adminN.toInt()).toDouble();
                      return PieChart(PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 26,
                        sections: [
                          _pie(adminN, const Color(0xFF6C63FF), 'Admin'),
                          _pie(userN, const Color(0xFF00B4D8), 'Users'),
                          _pie(bannedN, const Color(0xFFFF6B6B), 'Banned'),
                        ],
                      ));
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: const [
                    _LegendDot(color: Color(0xFF6C63FF), label: 'Admins'),
                    _LegendDot(color: Color(0xFF00B4D8), label: 'Members'),
                    _LegendDot(color: Color(0xFFFF6B6B), label: 'Banned'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _card(
            context,
            title: 'Moderation Risk',
            // FIX: description explains what the gauge shows
            description: '% of all posts currently flagged for review.',
            child: FutureBuilder<_RiskData>(
              future: _loadRiskData(),
              builder: (_, snap) {
                final r = snap.data ?? const _RiskData(0, 0);
                final ratio = r.totalPosts == 0
                    ? 0.0
                    : (r.flagged / r.totalPosts).clamp(0.0, 1.0);
                final percent = (ratio * 100).toStringAsFixed(1);
                final Color gaugeColor;
                final String riskLabel;
                if (ratio < 0.05) {
                  gaugeColor = const Color(0xFF00C49A);
                  riskLabel = 'Low Risk';
                } else if (ratio < 0.15) {
                  gaugeColor = const Color(0xFFFFB84D);
                  riskLabel = 'Moderate';
                } else {
                  gaugeColor = const Color(0xFFFF6B6B);
                  riskLabel = 'High Risk';
                }
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: ratio,
                            strokeWidth: 12,
                            color: gaugeColor,
                            backgroundColor:
                                gaugeColor.withValues(alpha: 0.15),
                          ),
                          Center(
                            child: Text('$percent%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: gaugeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(riskLabel,
                          style: TextStyle(
                              color: gaugeColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                    const SizedBox(height: 6),
                    Text('${r.flagged} flagged / ${r.totalPosts} posts',
                        style: const TextStyle(
                            color: Color(0xFF9CACCF), fontSize: 11),
                        textAlign: TextAlign.center),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Top contributors bar chart ─────────────────────────────────────────────

  Widget _buildTopContributors(BuildContext context) {
    return _card(
      context,
      title: 'Top Contributors',
      // FIX: description explains what the bars represent
      description:
          'Users with the most published posts. Tap a bar for the full username.',
      child: FutureBuilder<List<MapEntry<String, int>>>(
        future: _loadTopContributors(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const SizedBox(
                height: 180,
                child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF))));
          }
          final entries = snap.data!;
          if (entries.isEmpty) {
            return const SizedBox(
                height: 80,
                child: Center(child: Text('No post data yet')));
          }
          final maxY = (entries
                      .map((e) => e.value)
                      .fold(0, (a, b) => a > b ? a : b) +
                  2)
              .toDouble();
          return SizedBox(
            // FIX: extra height for rotated bottom labels
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    // FIX: tooltip shows full email + post count on tap
                    getTooltipItem: (group, _, rod, __) {
                      final i = group.x;
                      if (i < 0 || i >= entries.length) return null;
                      return BarTooltipItem(
                        '${entries[i].key}\n${rod.toY.toInt()} posts',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFFE6EAF2), strokeWidth: 1),
                ),
                barGroups: List.generate(
                  entries.length,
                  (i) => BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: entries[i].value.toDouble(),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xFF6C63FF), Color(0xFFFF8FAB)],
                      ),
                      width: 22,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6)),
                    ),
                  ]),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true, reservedSize: 28, interval: 1),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      // FIX: reservedSize increased + labels rotated to prevent overlap
                      reservedSize: 56,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= entries.length) {
                          return const SizedBox.shrink();
                        }
                        final raw = entries[i].key.split('@').first;
                        final label =
                            raw.length > 9 ? '${raw.substring(0, 9)}…' : raw;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: RotatedBox(
                            quarterTurns: 1,
                            child: Text(label,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF677489))),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Recent events ──────────────────────────────────────────────────────────

  Widget _buildRecentEvents(BuildContext context) {
    return _card(
      context,
      title: 'Recent Activity',
      description:
          'Latest posts and flagged content across the platform, newest first.',
      child: FutureBuilder<List<_RecentEvent>>(
        future: _loadRecentEvents(),
        builder: (_, snap) {
          final events = snap.data ?? const [];
          if (events.isEmpty) {
            return const Padding(
                padding: EdgeInsets.all(16), child: Text('No events yet'));
          }
          return Column(
            children: events.take(10).map((e) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: e.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(e.icon, size: 16, color: e.color),
                ),
                title: Text(e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(e.subtitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
                trailing: e.ts != null
                    ? Text(_timeAgo(e.ts!),
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF9CACCF)))
                    : null,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card(
    BuildContext context, {
    required String title,
    required Widget child,
    String description = '',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F34) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                isDark ? const Color(0xFF2A3554) : const Color(0xFFD8DEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isDark
                      ? const Color(0xFFE7EDFF)
                      : const Color(0xFF2D3142))),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(description,
                style: const TextStyle(
                    color: Color(0xFF9CACCF), fontSize: 11)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  PieChartSectionData _pie(double value, Color color, String title) {
    return PieChartSectionData(
      value: value == 0 ? 0.01 : value,
      color: color,
      title: value == 0 ? '' : value.toInt().toString(),
      titleStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      radius: 54,
    );
  }

  LineChartBarData _line(List<int> values, Color color) {
    return LineChartBarData(
      spots: List.generate(
          values.length, (i) => FlSpot(i.toDouble(), values[i].toDouble())),
      color: color,
      isCurved: true,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 3,
            color: color,
            strokeWidth: 1.5,
            strokeColor: Colors.white),
      ),
    );
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  // ── Data loaders ──────────────────────────────────────────────────────────

  Future<_TrendData> _loadTrendData() async {
    final start = DateTime.now().subtract(const Duration(days: 6));
    final snaps = await Future.wait([
      FirebaseFirestore.instance
          .collection('User Posts')
          .where('TimeStamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .get(),
      FirebaseFirestore.instance
          .collection('Moderated Posts')
          .where('TimeStamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .get(),
      FirebaseFirestore.instance
          .collection('Moderated Comments')
          .where('TimeStamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .get(),
    ]);
    List<int> count(QuerySnapshot<Map<String, dynamic>> s) {
      final out = List<int>.filled(7, 0);
      for (final d in s.docs) {
        final ts = d.data()['TimeStamp'];
        if (ts is! Timestamp) continue;
        final idx = ts.toDate().weekday - 1;
        if (idx >= 0 && idx < 7) out[idx]++;
      }
      return out;
    }
    return _TrendData(count(snaps[0]), count(snaps[1]), count(snaps[2]));
  }

  Future<_RiskData> _loadRiskData() async {
    final snaps = await Future.wait([
      FirebaseFirestore.instance.collection('User Posts').get(),
      FirebaseFirestore.instance.collection('Moderated Posts').get(),
      FirebaseFirestore.instance.collection('Moderated Comments').get(),
    ]);
    return _RiskData(
      snaps[0].docs.length,
      snaps[1].docs.length + snaps[2].docs.length,
    );
  }

  Future<List<MapEntry<String, int>>> _loadTopContributors() async {
    final snap = await FirebaseFirestore.instance
        .collection('User Posts')
        .limit(300)
        .get();
    final map = <String, int>{};
    for (final doc in snap.docs) {
      final email =
          (doc.data()['UserEmail'] ?? '').toString().trim().toLowerCase();
      if (!email.contains('@')) continue;
      map[email] = (map[email] ?? 0) + 1;
    }
    final list = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(6).toList();
  }

  Future<List<_RecentEvent>> _loadRecentEvents() async {
    final snaps = await Future.wait([
      FirebaseFirestore.instance
          .collection('User Posts')
          .orderBy('TimeStamp', descending: true)
          .limit(5)
          .get(),
      FirebaseFirestore.instance
          .collection('Moderated Posts')
          .orderBy('TimeStamp', descending: true)
          .limit(5)
          .get(),
      FirebaseFirestore.instance
          .collection('Moderated Comments')
          .orderBy('TimeStamp', descending: true)
          .limit(5)
          .get(),
    ]);
    final events = <_RecentEvent>[];
    for (final doc in snaps[0].docs) {
      events.add(_RecentEvent(
          icon: Icons.article_rounded,
          color: const Color(0xFF6C63FF),
          title: 'New post by ${doc.data()['UserEmail'] ?? 'unknown'}',
          subtitle: (doc.data()['Message'] ?? '').toString(),
          ts: doc.data()['TimeStamp'] as Timestamp?));
    }
    for (final doc in snaps[1].docs) {
      events.add(_RecentEvent(
          icon: Icons.flag_rounded,
          color: const Color(0xFFFF6B6B),
          title: 'Post flagged — ${doc.data()['Reason'] ?? 'unknown reason'}',
          subtitle:
              (doc.data()['Message'] ?? doc.data()['Text'] ?? '').toString(),
          ts: doc.data()['TimeStamp'] as Timestamp?));
    }
    for (final doc in snaps[2].docs) {
      events.add(_RecentEvent(
          icon: Icons.comment_rounded,
          color: const Color(0xFFFFB84D),
          title:
              'Comment flagged — ${doc.data()['Reason'] ?? 'unknown reason'}',
          subtitle:
              (doc.data()['Comment'] ?? doc.data()['Text'] ?? '').toString(),
          ts: doc.data()['TimeStamp'] as Timestamp?));
    }
    events.sort((a, b) => (b.ts?.millisecondsSinceEpoch ?? 0)
        .compareTo(a.ts?.millisecondsSinceEpoch ?? 0));
    return events;
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _TrendData {
  const _TrendData(this.posts, this.flaggedPosts, this.flaggedComments);
  final List<int> posts;
  final List<int> flaggedPosts;
  final List<int> flaggedComments;
}

class _RiskData {
  const _RiskData(this.totalPosts, this.flagged);
  final int totalPosts;
  final int flagged;
}

class _RecentEvent {
  const _RecentEvent(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.ts});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Timestamp? ts;
}

// ── Shared legend dot (exported for use in other pages too) ──────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF677489))),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../core/widgets.dart';

const _blue = Color(0xFF7DB2FF);
const _blueLight = Color(0xFFE7F0FF);
const _ink = Color(0xFF0E3E3E);
const _green = Color(0xFF4CAF50);
const _orange = Color(0xFFFF9800);

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _weekly = {};
  Map<String, dynamic> _achievements = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        StatsService.getSummary(),
        StatsService.getWeeklyStats(),
        StatsService.getAchievements(),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0];
          _weekly = results[1];
          _achievements = results[2];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FD);

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: const CommonBottomNav(currentItem: NavItem.home),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: CustomScrollView(
            slivers: [
              // 헤더
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // 탭바
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: _blue,
                    unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey,
                    indicatorColor: _blue,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: '요약'),
                      Tab(text: '주간'),
                      Tab(text: '업적'),
                    ],
                  ),
                  isDark: isDark,
                ),
              ),

              // 탭 콘텐츠
              SliverFillRemaining(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSummaryTab(),
                          _buildWeeklyTab(),
                          _buildAchievementsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final overallRate = _summary['overallRate'] ?? 0;
    final streakDays = _summary['streakDays'] ?? 0;
    final completedTasks = _summary['completedTasks'] ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7DB2FF), Color(0xFF5A9BF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              ),
              const Text(
                '학습 통계',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 주요 통계
          Row(
            children: [
              _buildStatBox(
                icon: Icons.local_fire_department,
                value: '$streakDays',
                label: '연속 학습일',
                iconColor: _orange,
              ),
              const SizedBox(width: 12),
              _buildStatBox(
                icon: Icons.check_circle,
                value: '$completedTasks',
                label: '완료한 학습',
                iconColor: _green,
              ),
              const SizedBox(width: 12),
              _buildStatBox(
                icon: Icons.percent,
                value: '$overallRate%',
                label: '전체 달성률',
                iconColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(40),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    final dailyProgress = (_summary['dailyProgress'] as List?) ?? [];
    final topicStats = (_summary['topicStats'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 최근 7일 진행률
        _buildSectionCard(
          title: '최근 7일 학습 현황',
          icon: Icons.calendar_today,
          child: Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: dailyProgress.map<Widget>((day) {
                    final rate = (day['rate'] ?? 0) / 100.0;
                    final dayName = day['dayName'] ?? '';
                    final isToday = dailyProgress.indexOf(day) == dailyProgress.length - 1;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${day['rate']}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday ? _blue : Colors.grey,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 32,
                          height: 100.0 * (rate.clamp(0.05, 1.0) as double),
                          decoration: BoxDecoration(
                            color: isToday ? _blue : _blueLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isToday ? _blue : Colors.grey[600],
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 주제별 학습 현황
        _buildSectionCard(
          title: '주제별 진행률',
          icon: Icons.pie_chart,
          child: topicStats.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('학습 계획이 없습니다.', style: TextStyle(color: Colors.grey)),
                )
              : Column(
                  children: topicStats.map<Widget>((topic) {
                    final rate = (topic['rate'] ?? 0) / 100.0;
                    final completed = topic['completed'] ?? 0;
                    final total = topic['total'] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  topic['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$completed / $total',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: rate,
                              minHeight: 10,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                rate >= 1.0 ? _green : _blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildWeeklyTab() {
    final weeklyRate = _weekly['weeklyRate'] ?? 0;
    final days = (_weekly['days'] as List?) ?? [];
    final totalCompleted = _weekly['totalCompleted'] ?? 0;
    final totalTasks = _weekly['totalTasks'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 주간 요약
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7DB2FF), Color(0xFF5A9BF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text(
                '이번 주 달성률',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$weeklyRate%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$totalCompleted / $totalTasks 완료',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 요일별 상세
        _buildSectionCard(
          title: '요일별 학습',
          icon: Icons.view_week,
          child: Column(
            children: days.map<Widget>((day) {
              final rate = (day['rate'] ?? 0);
              final completed = day['completed'] ?? 0;
              final total = day['tasks'] ?? 0;
              final dayName = day['dayName'] ?? '';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: rate > 0 ? _blueLight : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: rate >= 100
                            ? _green
                            : rate > 0
                                ? _blue
                                : Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        dayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            total > 0 ? '$completed / $total 완료' : '학습 없음',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: total > 0 ? _ink : Colors.grey,
                            ),
                          ),
                          if (total > 0) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: rate / 100.0,
                                minHeight: 6,
                                backgroundColor: Colors.white,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  rate >= 100 ? _green : _blue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$rate%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: rate >= 100 ? _green : _ink,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsTab() {
    final achievements = (_achievements['achievements'] as List?) ?? [];
    final unlockedCount = _achievements['unlockedCount'] ?? 0;
    final totalCount = _achievements['totalCount'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 업적 요약
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _blueLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '획득한 업적',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$unlockedCount / $totalCount',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 업적 목록
        ...achievements.map<Widget>((achievement) {
          final unlocked = achievement['unlocked'] ?? false;
          final progress = achievement['progress'] ?? 0;
          final target = achievement['target'] ?? 1;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: unlocked ? const Color(0xFFE8F5E9) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: unlocked
                  ? Border.all(color: _green.withAlpha(100), width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: unlocked ? _green : Colors.grey[300],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    achievement['icon'] ?? '🏆',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement['title'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: unlocked ? _ink : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement['description'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (!unlocked) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress / target,
                            minHeight: 6,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(_blue),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$progress / $target',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (unlocked)
                  const Icon(Icons.check_circle, color: _green, size: 28),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// Sticky TabBar Delegate
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;

  const _StickyTabBarDelegate(this.tabBar, {this.isDark = false});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FD),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => oldDelegate.isDark != isDark;
}

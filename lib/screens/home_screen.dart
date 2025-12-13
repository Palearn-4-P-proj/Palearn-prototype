import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/api_service.dart';
import '../core/widgets.dart';

// 색상 상수 (테마에서 직접 참조)
const Color _ink = Color(0xFF0E3E3E);
const Color _inkSub = Color(0xFF2A3A3A);
const Color _blue = Color(0xFF7DB2FF);
const Color _blueLight = Color(0xFFE7F0FF);
const Color _surface = Color(0xFFF7F8FD);
const Color _green = Color(0xFF4CAF50);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String displayName = 'User';
  double todayProgress = 0.0;

  // 오늘의 할 일 (상세 정보 포함)
  List<Map<String, dynamic>> todayTasks = [];

  // 내 학습 계획 리스트
  List<Map<String, dynamic>> myPlans = [];

  // 날짜별 태스크 개수 (캘린더 표시용)
  Map<String, int> _taskCountByDate = {};

  // 주간 학습 통계 (최근 7일)
  List<double> weeklyProgress = [0, 0, 0, 0, 0, 0, 0];

  DateTime _focusedMonth = DateTime.now();

  bool loadingHeader = true;
  bool loadingTasks = true;
  bool loadingPlans = true;

  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 처음 로드가 아닌 경우 (다른 화면에서 돌아왔을 때) 데이터 새로고침
    if (!_isFirstLoad) {
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        _loadAll();
      }
    }
    _isFirstLoad = false;
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadHeader(),
      _loadTodayTasks(),
      _loadMyPlans(),
    ]);
  }

  Future<void> _loadHeader() async {
    try {
      // 먼저 로컬에 저장된 이름 가져오기 (백업용)
      final savedName = await SecureTokenStorage.getUserName();

      final data = await HomeService.getHeader();
      if (mounted) {
        // API 응답의 이름이 비어있으면 로컬 저장된 이름 사용
        final apiName = data['name']?.toString() ?? '';
        setState(() {
          displayName = apiName.isNotEmpty ? apiName : (savedName ?? 'User');
          todayProgress = (data['todayProgress'] ?? 0) / 100.0;
          loadingHeader = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading header: $e');
      // 에러 시에도 로컬 저장된 이름 시도
      final savedName = await SecureTokenStorage.getUserName();
      if (mounted) {
        setState(() {
          displayName = savedName ?? 'User';
          todayProgress = 0.0;
          loadingHeader = false;
        });
      }
    }
  }

  Future<void> _loadTodayTasks() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // 모든 계획에서 오늘 날짜의 태스크를 찾아서 합침
      final allPlans = await PlanService.getMyPlans();
      final List<Map<String, dynamic>> allTodayTasks = [];

      for (final plan in allPlans) {
        final schedule = plan['daily_schedule'] as List? ?? [];
        for (final day in schedule) {
          if (day['date'] == today) {
            final tasks = day['tasks'] as List? ?? [];
            for (final task in tasks) {
              allTodayTasks.add(Map<String, dynamic>.from(task as Map));
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          todayTasks = allTodayTasks;
          // 진행률 계산
          if (todayTasks.isNotEmpty) {
            final completedCount = todayTasks.where((t) => t['completed'] == true).length;
            todayProgress = completedCount / todayTasks.length;
          } else {
            todayProgress = 0.0;
          }
          loadingTasks = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading today tasks: $e');
      if (mounted) {
        setState(() {
          todayTasks = [];
          loadingTasks = false;
        });
      }
    }
  }

  Future<void> _loadMyPlans() async {
    try {
      final data = await PlanService.getMyPlans();
      if (mounted) {
        // 날짜별 태스크 개수 및 완료율 계산
        final Map<String, int> taskCounts = {};
        final Map<String, int> taskTotals = {};
        final Map<String, int> taskCompleted = {};

        for (final plan in data) {
          final schedule = plan['daily_schedule'] as List? ?? [];
          for (final day in schedule) {
            final date = day['date']?.toString() ?? '';
            final tasks = day['tasks'] as List? ?? [];
            if (date.isNotEmpty) {
              taskCounts[date] = (taskCounts[date] ?? 0) + tasks.length;
              taskTotals[date] = (taskTotals[date] ?? 0) + tasks.length;
              final completed = tasks.where((t) => t['completed'] == true).length;
              taskCompleted[date] = (taskCompleted[date] ?? 0) + completed;
            }
          }
        }

        // 최근 7일 진행률 계산
        final today = DateTime.now();
        final List<double> weekly = [];
        for (int i = 6; i >= 0; i--) {
          final date = today.subtract(Duration(days: i));
          final dateStr = date.toIso8601String().split('T')[0];
          final total = taskTotals[dateStr] ?? 0;
          final completed = taskCompleted[dateStr] ?? 0;
          weekly.add(total > 0 ? completed / total : 0.0);
        }

        setState(() {
          myPlans = data;
          _taskCountByDate = taskCounts;
          weeklyProgress = weekly;
          loadingPlans = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading plans: $e');
      if (mounted) {
        setState(() {
          myPlans = [];
          _taskCountByDate = {};
          weeklyProgress = [0, 0, 0, 0, 0, 0, 0];
          loadingPlans = false;
        });
      }
    }
  }

  void _goNotifications() => Navigator.pushNamed(context, '/notifications');

  // 계획 상세 페이지로 이동
  void _openPlanDetail(Map<String, dynamic> plan) {
    Navigator.pushNamed(context, '/plan_detail', arguments: plan);
  }

  // 태스크 완료 토글
  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final taskId = task['id'] ?? '';
    final newCompleted = !(task['completed'] ?? false);

    try {
      await PlanService.updateTask(
        date: today,
        taskId: taskId,
        completed: newCompleted,
      );

      setState(() {
        // 1. todayTasks 업데이트
        task['completed'] = newCompleted;

        // 2. myPlans 내부의 해당 태스크도 업데이트 (주간 통계 반영용)
        for (final plan in myPlans) {
          final schedule = plan['daily_schedule'] as List? ?? [];
          for (final day in schedule) {
            if (day['date'] == today) {
              final tasks = day['tasks'] as List? ?? [];
              for (final t in tasks) {
                if (t['id'] == taskId) {
                  t['completed'] = newCompleted;
                }
              }
            }
          }
        }

        // 3. 오늘 진행률 재계산
        final completedCount =
            todayTasks.where((t) => t['completed'] == true).length;
        todayProgress =
            todayTasks.isEmpty ? 0 : completedCount / todayTasks.length;

        // 4. 주간 진행률 재계산
        _recalculateWeeklyProgress();
      });
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  // 주간 진행률 재계산
  void _recalculateWeeklyProgress() {
    final todayDate = DateTime.now();
    final Map<String, int> taskTotals = {};
    final Map<String, int> taskCompleted = {};

    for (final plan in myPlans) {
      final schedule = plan['daily_schedule'] as List? ?? [];
      for (final day in schedule) {
        final date = day['date']?.toString() ?? '';
        final tasks = day['tasks'] as List? ?? [];
        if (date.isNotEmpty) {
          taskTotals[date] = (taskTotals[date] ?? 0) + tasks.length;
          final completed = tasks.where((t) => t['completed'] == true).length;
          taskCompleted[date] = (taskCompleted[date] ?? 0) + completed;
        }
      }
    }

    final List<double> weekly = [];
    for (int i = 6; i >= 0; i--) {
      final date = todayDate.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final total = taskTotals[dateStr] ?? 0;
      final completed = taskCompleted[dateStr] ?? 0;
      weekly.add(total > 0 ? completed / total : 0.0);
    }

    weeklyProgress = weekly;
  }

  // 태스크 상세 다이얼로그
  void _showTaskDetail(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskDetailSheet(
        task: task,
        onToggleComplete: () {
          Navigator.pop(ctx);
          _toggleTask(task);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percentLabel = '${(todayProgress * 100).round()}%';
    final completedCount =
        todayTasks.where((t) => t['completed'] == true).length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : _surface;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? const Color(0xFFE5E5E5) : _ink;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : _inkSub;
    final blueLightColor = isDark ? const Color(0xFF1E3A5F) : _blueLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: CustomScrollView(
            slivers: [
              // 헤더 - 원형 진행률 차트 + 주간 그래프
              SliverToBoxAdapter(
                child: _buildHeader(percentLabel, completedCount),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 주간 학습 통계 바 그래프
              SliverToBoxAdapter(
                child: _buildWeeklyStatsBar(isDark, cardColor, textColor),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // 오늘의 할 일 섹션
              SliverToBoxAdapter(
                child: _buildTodayTasksSection(isDark, cardColor, textColor, subTextColor, blueLightColor),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 내 학습 계획 리스트
              SliverToBoxAdapter(
                child: _buildMyPlansSection(isDark, cardColor, textColor, subTextColor, blueLightColor),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 캘린더 미니뷰
              SliverToBoxAdapter(
                child: _buildCalendarSection(isDark, cardColor, textColor),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _buildHeader(String percentLabel, int completedCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          // 앱 바
          Row(
            children: [
              const Text('Palearn',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/search'),
                icon: const Icon(Icons.search_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/stats'),
                icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: _goNotifications,
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Colors.white),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            '안녕하세요, $displayName 님!',
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 20),

          // 원형 진행률 + 텍스트
          Row(
            children: [
              // 원형 진행률 차트
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: todayProgress,
                        strokeWidth: 10,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          percentLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          '완료',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // 오늘의 학습 요약
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오늘의 학습',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$completedCount / ${todayTasks.length} 완료',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (todayTasks.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          todayProgress >= 1.0 ? '🎉 오늘 학습 완료!' : '💪 화이팅!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyStatsBar(bool isDark, Color cardColor, Color textColor) {
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final today = DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
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
              Icon(Icons.insights, color: _blue, size: 20),
              const SizedBox(width: 8),
              Text(
                '주간 학습 현황',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final date = today.subtract(Duration(days: 6 - i));
                final dayName = dayNames[date.weekday - 1];
                final progress = weeklyProgress[i];
                final isToday = i == 6;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 바 그래프
                    Container(
                      width: 28,
                      height: 40 * (progress > 0 ? progress : 0.05),
                      decoration: BoxDecoration(
                        color: isToday
                            ? _blue
                            : (progress > 0
                                ? _blue.withAlpha(isDark ? 150 : 100)
                                : (isDark ? Colors.grey[700] : Colors.grey[200])),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 요일
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? _blue : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTasksSection(bool isDark, Color cardColor, Color textColor, Color subTextColor, Color blueLightColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.today, color: _blue, size: 22),
              const SizedBox(width: 8),
              Text(
                '오늘 해야 할 것',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (todayTasks.isNotEmpty)
                Text(
                  '${todayTasks.length}개',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 가로 스크롤 태스크 리스트
        SizedBox(
          height: 140,
          child: loadingTasks
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 3,
                  itemBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: TaskCardSkeleton(),
                  ),
                )
              : todayTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 40, color: subTextColor),
                          const SizedBox(height: 8),
                          Text(
                            '오늘 할 일이 없습니다',
                            style: TextStyle(color: subTextColor),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/create_plan'),
                            child: const Text('새 계획 만들기'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: todayTasks.length,
                      itemBuilder: (_, i) =>
                          _buildTaskCard(todayTasks[i], i + 1, isDark, cardColor, textColor, blueLightColor),
                    ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, int index, bool isDark, Color cardColor, Color textColor, Color blueLightColor) {
    final title = task['title'] ?? '학습';
    final duration = task['duration'] ?? '';
    final completed = task['completed'] ?? false;

    return GestureDetector(
      onTap: () => _showTaskDetail(task),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: completed ? const Color(0xFFE8F5E9) : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: completed
              ? Border.all(color: _green.withAlpha(100), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 13),
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
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: completed ? _green : _blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: completed
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text(
                          '$index',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleTask(task),
                  child: Icon(
                    completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: completed ? _green : Colors.grey,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (duration.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: blueLightColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  duration,
                  style: const TextStyle(fontSize: 11, color: _blue),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyPlansSection(bool isDark, Color cardColor, Color textColor, Color subTextColor, Color blueLightColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.library_books, color: _blue, size: 22),
              const SizedBox(width: 8),
              Text(
                '내 학습 계획',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/create_plan'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('새 계획', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (loadingPlans)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(
                2,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: CardSkeleton(),
                ),
              ),
            ),
          )
        else if (myPlans.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: blueLightColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.school_outlined, size: 48, color: _blue),
                  const SizedBox(height: 12),
                  Text(
                    '아직 학습 계획이 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI가 맞춤 학습 계획을 만들어드립니다',
                    style: TextStyle(color: subTextColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/create_plan'),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text(
                      '첫 계획 만들기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      elevation: 4,
                      shadowColor: _blue.withAlpha(100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: myPlans.length,
            itemBuilder: (_, i) => _buildPlanCard(myPlans[i], isDark, cardColor, textColor, blueLightColor),
          ),
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, bool isDark, Color cardColor, Color textColor, Color blueLightColor) {
    final name = plan['plan_name'] ?? '학습 계획';
    final duration = plan['total_duration'] ?? '';
    final schedule = plan['daily_schedule'] as List? ?? [];
    final totalTasks =
        schedule.fold<int>(0, (sum, day) => sum + (day['tasks'] as List).length);
    final completedTasks = schedule.fold<int>(0, (sum, day) {
      final tasks = day['tasks'] as List;
      return sum + tasks.where((t) => t['completed'] == true).length;
    });
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return GestureDetector(
      onTap: () => _openPlanDetail(plan),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 10),
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: blueLightColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book, color: _blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$duration · ${schedule.length}일 일정',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: isDark ? Colors.grey[400] : Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            // 진행률 바
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? _green : _blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection(bool isDark, Color cardColor, Color textColor) {
    final subTextColor = isDark ? Colors.grey[400]! : _inkSub;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: _blue, size: 22),
              const SizedBox(width: 8),
              Text(
                '월간 캘린더',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/review'),
                child: const Text('어제 복습하기 →'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 30 : 10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _focusedMonth = DateTime(
                        _focusedMonth.year, _focusedMonth.month - 1, 1)),
                    icon: Icon(Icons.chevron_left, color: textColor),
                  ),
                  Text(
                    '${_focusedMonth.year}년 ${_focusedMonth.month}월',
                    style: TextStyle(
                        color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _focusedMonth = DateTime(
                        _focusedMonth.year, _focusedMonth.month + 1, 1)),
                    icon: Icon(Icons.chevron_right, color: textColor),
                  ),
                ],
              ),
              TableCalendar(
                focusedDay: _focusedMonth,
                firstDay: DateTime(_focusedMonth.year - 1, 1, 1),
                lastDay: DateTime(_focusedMonth.year + 1, 12, 31),
                headerVisible: false,
                rowHeight: 52,
                daysOfWeekHeight: 28,
                availableGestures: AvailableGestures.horizontalSwipe,
                // 스와이프로 월 변경 시 제목 동기화
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedMonth = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  todayDecoration:
                      const BoxDecoration(color: _blue, shape: BoxShape.circle),
                  todayTextStyle: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  defaultTextStyle: TextStyle(fontSize: 14, color: textColor),
                  weekendTextStyle:
                      const TextStyle(fontSize: 14, color: Colors.redAccent),
                  cellMargin: const EdgeInsets.all(2),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontSize: 13, color: subTextColor),
                  weekendStyle:
                      const TextStyle(fontSize: 13, color: Colors.redAccent),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildCalendarDay(day, isToday: false, isWeekend: day.weekday >= 6, textColor: textColor);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return _buildCalendarDay(day, isToday: true, isWeekend: false, textColor: textColor);
                  },
                  outsideBuilder: (context, day, focusedDay) {
                    return _buildCalendarDay(day, isToday: false, isWeekend: false, isOutside: true, textColor: textColor);
                  },
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _focusedMonth = focusedDay;
                  });
                  _showDayPlanDialog(selectedDay);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showDayPlanDialog(DateTime selectedDay) async {
    final dateStr = selectedDay.toIso8601String().split('T')[0];
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final dayName = dayNames[selectedDay.weekday - 1];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.calendar_today, color: _blue),
            const SizedBox(width: 10),
            Text(
              '${selectedDay.month}월 ${selectedDay.day}일 ($dayName)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: FutureBuilder<Map<String, dynamic>>(
          future: PlanService.getPlansByDate(date: dateStr),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 100,
                child: Center(
                  child: Text('계획을 불러올 수 없습니다.\n${snapshot.error}'),
                ),
              );
            }

            final data = snapshot.data!;
            final tasks = data['tasks'] as List<dynamic>? ?? [];
            final message = data['message'] as String?;

            if (tasks.isEmpty) {
              return SizedBox(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_busy, size: 40, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        message ?? '이 날의 계획이 없습니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.separated(
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final task = tasks[i] as Map<String, dynamic>;
                  final title = task['title'] ?? '제목 없음';
                  final description = task['description'] ?? '';
                  final duration = task['duration'] ?? '';
                  final completed = task['completed'] ?? false;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: completed ? const Color(0xFFE8F5E9) : _blueLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              completed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: completed ? _green : _blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (duration.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  duration,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                              ),
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDay(DateTime day, {
    required bool isToday,
    required bool isWeekend,
    bool isOutside = false,
    Color? textColor,
  }) {
    final dateStr = day.toIso8601String().split('T')[0];
    final taskCount = _taskCountByDate[dateStr] ?? 0;
    final defaultTextColor = textColor ?? _ink;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isToday ? _blue : null,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 날짜 숫자
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              color: isOutside
                  ? Colors.grey[400]
                  : isToday
                      ? Colors.white
                      : isWeekend
                          ? Colors.redAccent
                          : defaultTextColor,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          // 태스크 개수 표시 (오른쪽 아래)
          if (taskCount > 0 && !isOutside)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isToday ? Colors.white : _blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  taskCount > 9 ? '9+' : '$taskCount',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isToday ? _blue : Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return const CommonBottomNav(currentItem: NavItem.home);
  }
}

// 태스크 상세 시트
class _TaskDetailSheet extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onToggleComplete;

  const _TaskDetailSheet({
    required this.task,
    required this.onToggleComplete,
  });

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  // URL 열기
  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // 검색 링크 생성 (LLM 호출 없이 바로 링크)
  List<Map<String, dynamic>> get searchLinks {
    final title = widget.task['title'] ?? '';
    final cleanTitle = title.replaceAll(RegExp(r'[📹💻📝🎬📖🎯]\s*'), ''); // 이모지 제거
    final encodedTitle = Uri.encodeComponent(cleanTitle);

    return [
      {
        'title': 'YouTube에서 검색',
        'type': '유튜브',
        'url': 'https://www.youtube.com/results?search_query=$encodedTitle',
      },
      {
        'title': 'Google에서 검색',
        'type': '구글',
        'url': 'https://www.google.com/search?q=$encodedTitle',
      },
      {
        'title': '네이버에서 검색',
        'type': '네이버',
        'url': 'https://search.naver.com/search.naver?query=$encodedTitle',
      },
      {
        'title': 'Velog 검색',
        'type': '블로그',
        'url': 'https://velog.io/search?q=$encodedTitle',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.task['title'] ?? '학습';
    final description = widget.task['description'] ?? '';
    final duration = widget.task['duration'] ?? '';
    final completed = widget.task['completed'] ?? false;
    final courseLink = widget.task['course_link'] ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // 드래그 핸들
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // 상단 상태 표시
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: completed
                              ? const Color(0xFFE8F5E9)
                              : _blueLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              completed
                                  ? Icons.check_circle
                                  : Icons.pending_outlined,
                              size: 16,
                              color: completed ? _green : _blue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              completed ? '완료됨' : '진행 중',
                              style: TextStyle(
                                color: completed ? _green : _blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (duration.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                duration,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 제목
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],

                  // 강좌 링크
                  if (courseLink.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      '📚 강좌 링크',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _blueLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link, color: _blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              courseLink,
                              style: const TextStyle(
                                color: _blue,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 검색 링크 (로딩 없이 바로 표시)
                  const SizedBox(height: 24),
                  const Text(
                    '🔍 관련 자료 검색',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...searchLinks.map((link) => GestureDetector(
                        onTap: () => _openUrl(link['url']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getMaterialColor(link['type']),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getMaterialIcon(link['type']),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      link['title'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      link['type'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.open_in_new,
                                  color: _blue, size: 20),
                            ],
                          ),
                        ),
                      )),

                  const SizedBox(height: 24),

                  // 완료/미완료 버튼
                  ElevatedButton.icon(
                    onPressed: widget.onToggleComplete,
                    icon: Icon(
                      completed ? Icons.replay : Icons.check,
                      size: 20,
                    ),
                    label: Text(
                      completed ? '미완료로 변경' : '학습 완료',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: completed ? Colors.grey : _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMaterialColor(String? type) {
    switch (type?.toLowerCase()) {
      case '유튜브':
        return Colors.red;
      case '블로그':
        return Colors.orange;
      case '공식문서':
        return Colors.blue;
      case '구글':
        return Colors.blue;
      case '네이버':
        return const Color(0xFF03C75A);
      default:
        return _blue;
    }
  }

  IconData _getMaterialIcon(String? type) {
    switch (type?.toLowerCase()) {
      case '유튜브':
        return Icons.play_circle_fill;
      case '블로그':
        return Icons.article;
      case '공식문서':
        return Icons.description;
      case '구글':
        return Icons.search;
      case '네이버':
        return Icons.search;
      default:
        return Icons.link;
    }
  }
}

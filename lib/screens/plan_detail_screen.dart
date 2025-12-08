import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/api_service.dart';

const Color _ink = Color(0xFF0E3E3E);
const Color _blue = Color(0xFF7DB2FF);
const Color _blueLight = Color(0xFFE7F0FF);
const Color _surface = Color(0xFFF7F8FD);
const Color _green = Color(0xFF4CAF50);

class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({super.key});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> plan = {};
  List<Map<String, dynamic>> dailySchedule = [];
  bool _reviewPopupShown = false;

  // 현재 보여줄 날짜 범위
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      plan = args;
      dailySchedule = (plan['daily_schedule'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      // 어제 복습 팝업 표시 (한 번만)
      if (!_reviewPopupShown) {
        _reviewPopupShown = true;
        _checkYesterdayReview();
      }
    }
  }

  Future<void> _checkYesterdayReview() async {
    try {
      final reviewData = await PlanService.getYesterdayReview();
      if (reviewData['has_review'] == true && mounted) {
        final materials = (reviewData['materials'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final topic = reviewData['yesterday_topic'] ?? '';

        if (materials.isNotEmpty) {
          // 잠시 후 팝업 표시
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showYesterdayReviewPopup(topic, materials);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking yesterday review: $e');
    }
  }

  void _showYesterdayReviewPopup(String topic, List<Map<String, dynamic>> materials) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('💡', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '잠깐!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '어제 배운 "$topic"과 연관된 자료예요.',
              style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 4),
            const Text(
              '복습하고 오늘도 화이팅! 🔥',
              style: TextStyle(fontSize: 15, color: _ink, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ...materials.take(2).map((m) => _buildReviewMaterialItem(m)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('나중에 볼게요'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('확인했어요!'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewMaterialItem(Map<String, dynamic> material) {
    final title = material['title'] ?? '';
    final type = material['type'] ?? '';
    final url = material['url'] ?? '';

    return GestureDetector(
      onTap: () {
        if (url.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('링크가 복사되었습니다!')),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: type == '유튜브' ? Colors.red[50] : Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: type == '유튜브' ? Colors.red[200]! : Colors.orange[200]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              type == '유튜브' ? Icons.play_circle_fill : Icons.article,
              color: type == '유튜브' ? Colors.red : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 12,
                      color: type == '유튜브' ? Colors.red : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.copy, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Daily 태스크 가져오기 (선택된 날짜)
  List<Map<String, dynamic>> get dailyTasks {
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    for (var day in dailySchedule) {
      if (day['date'] == dateStr) {
        return (day['tasks'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
      }
    }
    return [];
  }

  // Weekly 태스크 가져오기
  List<Map<String, dynamic>> get weeklyTasks {
    final weekStart =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    List<Map<String, dynamic>> tasks = [];
    for (var day in dailySchedule) {
      final dayDate = DateTime.parse(day['date']);
      if (dayDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          dayDate.isBefore(weekEnd.add(const Duration(days: 1)))) {
        for (var task in (day['tasks'] as List? ?? [])) {
          tasks.add({
            ...task as Map<String, dynamic>,
            'date': day['date'],
          });
        }
      }
    }
    return tasks;
  }

  // Monthly 태스크 가져오기
  List<Map<String, dynamic>> get monthlyTasks {
    List<Map<String, dynamic>> tasks = [];
    for (var day in dailySchedule) {
      final dayDate = DateTime.parse(day['date']);
      if (dayDate.year == _selectedDate.year &&
          dayDate.month == _selectedDate.month) {
        for (var task in (day['tasks'] as List? ?? [])) {
          tasks.add({
            ...task as Map<String, dynamic>,
            'date': day['date'],
          });
        }
      }
    }
    return tasks;
  }

  // 진행률 계산
  double get progress {
    int total = 0;
    int completed = 0;
    for (var day in dailySchedule) {
      for (var task in (day['tasks'] as List? ?? [])) {
        total++;
        if (task['completed'] == true) completed++;
      }
    }
    return total > 0 ? completed / total : 0;
  }

  // 태스크 완료 토글
  Future<void> _toggleTask(Map<String, dynamic> task, String date) async {
    final newCompleted = !(task['completed'] ?? false);
    final taskId = task['id'] ?? '';

    try {
      final success = await PlanService.updateTask(
        date: date,
        taskId: taskId,
        completed: newCompleted,
      );

      if (success) {
        setState(() {
          // dailySchedule 내부의 원본 태스크 찾아서 업데이트
          for (var day in dailySchedule) {
            if (day['date'] == date) {
              for (var t in (day['tasks'] as List? ?? [])) {
                if (t['id'] == taskId) {
                  t['completed'] = newCompleted;
                  break;
                }
              }
              break;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('업데이트 실패. 다시 시도해주세요.')),
        );
      }
    }
  }

  // 태스크 상세 보기
  void _showTaskDetail(Map<String, dynamic> task, String date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskDetailSheet(
        task: task,
        date: date,
        onToggleComplete: () {
          Navigator.pop(ctx);
          _toggleTask(task, date);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planName = plan['plan_name'] ?? '학습 계획';
    final duration = plan['total_duration'] ?? '';

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            _buildHeader(planName, duration),

            // 탭 바
            _buildTabBar(),

            // 날짜 선택기
            _buildDateSelector(),

            // 태스크 리스트
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(dailyTasks, true),
                  _buildTaskList(weeklyTasks, false),
                  _buildTaskList(monthlyTasks, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String planName, String duration) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7DB2FF), Color(0xFF5A9BF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).round()}% 완료',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      '$duration · ${dailySchedule.length}일 일정',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 진행률 바
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _blue,
          borderRadius: BorderRadius.circular(22),
        ),
        indicatorPadding:
            const EdgeInsets.symmetric(horizontal: -8, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(vertical: 10),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black54,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(text: 'Daily'),
          Tab(text: 'Weekly'),
          Tab(text: 'Monthly'),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                if (_tabController.index == 0) {
                  _selectedDate =
                      _selectedDate.subtract(const Duration(days: 1));
                } else if (_tabController.index == 1) {
                  _selectedDate =
                      _selectedDate.subtract(const Duration(days: 7));
                } else {
                  _selectedDate = DateTime(
                      _selectedDate.year, _selectedDate.month - 1, 1);
                }
              });
            },
            icon: const Icon(Icons.chevron_left, color: _ink),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _blueLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: _blue),
                  const SizedBox(width: 8),
                  Text(
                    _tabController.index == 0
                        ? '${_selectedDate.month}월 ${_selectedDate.day}일 (${dayNames[_selectedDate.weekday - 1]})'
                        : _tabController.index == 1
                            ? '${_selectedDate.month}월 ${_getWeekNumber(_selectedDate)}주차'
                            : '${_selectedDate.year}년 ${_selectedDate.month}월',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                if (_tabController.index == 0) {
                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                } else if (_tabController.index == 1) {
                  _selectedDate = _selectedDate.add(const Duration(days: 7));
                } else {
                  _selectedDate = DateTime(
                      _selectedDate.year, _selectedDate.month + 1, 1);
                }
              });
            },
            icon: const Icon(Icons.chevron_right, color: _ink),
          ),
        ],
      ),
    );
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final daysSinceFirstDay = date.difference(firstDayOfMonth).inDays;
    return (daysSinceFirstDay / 7).floor() + 1;
  }

  Widget _buildTaskList(List<Map<String, dynamic>> tasks, bool isDaily) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              '이 기간에 할 일이 없습니다',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final task = tasks[i];
        final date = isDaily
            ? _selectedDate.toIso8601String().split('T')[0]
            : task['date'] ?? '';

        return _TaskCard(
          task: task,
          date: date,
          showDate: !isDaily,
          onTap: () => _showTaskDetail(task, date),
          onToggle: () => _toggleTask(task, date),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final String date;
  final bool showDate;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _TaskCard({
    required this.task,
    required this.date,
    required this.showDate,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final title = task['title'] ?? '학습';
    final description = task['description'] ?? '';
    final duration = task['duration'] ?? '';
    final completed = task['completed'] ?? false;
    final courseLink = task['course_link'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: completed ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: completed
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: completed ? _green : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      completed ? Icons.check : Icons.radio_button_unchecked,
                      color: completed ? Colors.white : Colors.grey,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDate && date.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _formatDate(date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                          decoration:
                              completed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (duration.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _blueLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      duration,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (courseLink.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.link, size: 16, color: _blue),
                  const SizedBox(width: 6),
                  const Text(
                    '강좌 링크 있음',
                    style: TextStyle(
                      fontSize: 12,
                      color: _blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  '자세히 보기 →',
                  style: TextStyle(
                    fontSize: 12,
                    color: _blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
      return '${date.month}/${date.day} (${dayNames[date.weekday - 1]})';
    } catch (e) {
      return dateStr;
    }
  }
}

// 태스크 상세 시트
class _TaskDetailSheet extends StatefulWidget {
  final Map<String, dynamic> task;
  final String date;
  final VoidCallback onToggleComplete;

  const _TaskDetailSheet({
    required this.task,
    required this.date,
    required this.onToggleComplete,
  });

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  List<Map<String, dynamic>> relatedMaterials = [];
  bool loadingMaterials = false;

  @override
  void initState() {
    super.initState();
    _loadRelatedMaterials();
  }

  void _loadRelatedMaterials() {
    // 태스크에 미리 저장된 연관 자료 사용 (API 호출 없음)
    final materials = widget.task['related_materials'] as List?;
    if (materials != null && materials.isNotEmpty) {
      setState(() {
        relatedMaterials = materials.map((e) => e as Map<String, dynamic>).toList();
        loadingMaterials = false;
      });
    } else {
      // 미리 저장된 자료가 없으면 기본 검색 링크
      final title = widget.task['title'] ?? '';
      final searchQuery = title.replaceAll(' ', '+');
      setState(() {
        relatedMaterials = [
          {"title": "$title 강의 영상", "type": "유튜브", "url": "https://www.youtube.com/results?search_query=$searchQuery+강의", "description": "관련 유튜브 강의를 검색합니다."},
          {"title": "$title 블로그 글", "type": "블로그", "url": "https://www.google.com/search?q=$searchQuery+블로그", "description": "관련 블로그 글을 검색합니다."},
        ];
        loadingMaterials = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.task['title'] ?? '학습';
    final description = widget.task['description'] ?? '';
    final duration = widget.task['duration'] ?? '';
    final completed = widget.task['completed'] ?? false;
    final courseLink = widget.task['course_link'] ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
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
                  // 날짜 & 상태
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _blueLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: _blue),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(widget.date),
                              style: const TextStyle(
                                color: _blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: completed
                              ? const Color(0xFFE8F5E9)
                              : Colors.orange[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              completed
                                  ? Icons.check_circle
                                  : Icons.pending_outlined,
                              size: 14,
                              color: completed ? _green : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              completed ? '완료됨' : '진행 중',
                              style: TextStyle(
                                color: completed ? _green : Colors.orange,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
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
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                duration,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 제목
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),

                  // 설명
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      '📝 학습 내용',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                          height: 1.7,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],

                  // 강좌 링크
                  if (courseLink.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      '🔗 강좌 링크',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: courseLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('링크가 클립보드에 복사되었습니다!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _blueLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.play_circle_outline,
                                color: _blue, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '강좌 바로가기',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    courseLink,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _blue,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.copy, color: _blue, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // 연관 자료
                  const SizedBox(height: 24),
                  const Text(
                    '📚 함께 보면 좋은 자료',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (loadingMaterials)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (relatedMaterials.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.search, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            '연관 자료를 검색 중입니다...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    ...relatedMaterials.map((material) => _MaterialCard(
                          material: material,
                        )),

                  const SizedBox(height: 32),

                  // 완료/미완료 버튼
                  ElevatedButton.icon(
                    onPressed: widget.onToggleComplete,
                    icon: Icon(
                      completed ? Icons.replay : Icons.check,
                      size: 22,
                    ),
                    label: Text(
                      completed ? '미완료로 변경' : '학습 완료!',
                      style: const TextStyle(
                        fontSize: 17,
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

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
      return '${date.year}년 ${date.month}월 ${date.day}일 (${dayNames[date.weekday - 1]})';
    } catch (e) {
      return dateStr;
    }
  }
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;

  const _MaterialCard({required this.material});

  @override
  Widget build(BuildContext context) {
    final title = material['title'] ?? '';
    final type = material['type'] ?? '';
    final url = material['url'] ?? '';
    final description = material['description'] ?? '';

    return GestureDetector(
      onTap: () {
        if (url.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('링크가 클립보드에 복사되었습니다!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getMaterialColor(type),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getMaterialIcon(type),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _ink,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getMaterialColor(type),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Colors.grey, size: 20),
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
      default:
        return Icons.link;
    }
  }
}

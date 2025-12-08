import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'friends_screen.dart';
import '../data/api_service.dart';
import '../core/widgets.dart';

const _ink = Color(0xFF0E3E3E);
const _blue = Color(0xFF7DB2FF);
const _blueLight = Color(0xFFE7F0FF);
const _green = Color(0xFF4CAF50);

class FriendDetailScreen extends StatefulWidget {
  const FriendDetailScreen({super.key});

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  late FriendDetailArgs _args;

  bool _loading = true;
  bool _initialized = false;
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  List<CheckItem> _dayItems = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _args = ModalRoute.of(context)!.settings.arguments as FriendDetailArgs;
      _loadDay(_selected);
      _initialized = true;
    }
  }

  Future<void> _loadDay(DateTime day) async {
    setState(() => _loading = true);

    try {
      final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final data = await FriendsService.getFriendPlans(
        friendId: _args.friendId,
        date: dateStr,
      );

      if (mounted) {
        setState(() {
          _dayItems = data.map((item) => CheckItem(
            id: item['id']?.toString() ?? '',
            title: item['title']?.toString() ?? '',
            duration: item['duration']?.toString() ?? '',
            done: item['done'] == true,
          )).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading friend plans: $e');
      if (mounted) {
        setState(() {
          _dayItems = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendCheer() async {
    try {
      await FriendsService.checkFriendPlan(
        friendId: _args.friendId,
        planId: 'cheer',
        done: true,
      );
      if (mounted) {
        showSuccessToast(context, '${_args.name}님에게 응원을 보냈습니다! 💪');
      }
    } catch (e) {
      debugPrint('Error sending cheer: $e');
      if (mounted) {
        showErrorToast(context, '응원 전송에 실패했습니다');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ym = '${_focused.year}년 ${_focused.month}월';
    final completedCount = _dayItems.where((i) => i.done).length;
    final totalCount = _dayItems.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7DB2FF), Color(0xFF5A9BF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_args.name}의 학습',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      // 응원 버튼
                      ElevatedButton.icon(
                        onPressed: _sendCheer,
                        icon: const Icon(Icons.favorite, size: 18),
                        label: const Text('응원하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _blue,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 오늘 진행률 표시
                  if (!_loading && _dayItems.isNotEmpty && isSameDay(_selected, DateTime.now())) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '오늘의 학습 진행률',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(200),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
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
                        const SizedBox(width: 16),
                        Text(
                          '$completedCount / $totalCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 달력
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              child: TableCalendar(
                firstDay: DateTime(_focused.year - 1, 1, 1),
                lastDay: DateTime(_focused.year + 1, 12, 31),
                focusedDay: _focused,
                selectedDayPredicate: (d) => isSameDay(d, _selected),
                onDaySelected: (sel, foc) {
                  setState(() {
                    _selected = sel;
                    _focused = foc;
                  });
                  _loadDay(sel);
                },
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextFormatter: (_, __) => ym,
                  titleTextStyle: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(color: _blueLight, shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: _blue, fontWeight: FontWeight.bold),
                  selectedDecoration: BoxDecoration(color: _blue, shape: BoxShape.circle),
                  selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                rowHeight: 40,
                daysOfWeekHeight: 28,
              ),
            ),

            // 날짜 표시
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: _blue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${_selected.month}월 ${_selected.day}일 학습 계획',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_dayItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: progress >= 1.0 ? _green.withAlpha(30) : _blueLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        progress >= 1.0 ? '완료!' : '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: progress >= 1.0 ? _green : _blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 학습 계획 목록
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _dayItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                '해당 날짜의 계획이 없습니다',
                                style: TextStyle(color: Colors.grey[600], fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _dayItems.length,
                          itemBuilder: (_, i) => _buildTaskCard(_dayItems[i], i + 1),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(CheckItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.done ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: item.done ? Border.all(color: _green.withAlpha(100), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.done ? _green : _blue,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: item.done
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    decoration: item.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.duration.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.duration,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            item.done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: item.done ? _green : Colors.grey[400],
            size: 24,
          ),
        ],
      ),
    );
  }
}

class CheckItem {
  final String id;
  final String title;
  final String duration;
  bool done;

  CheckItem({
    required this.id,
    required this.title,
    this.duration = '',
    this.done = false,
  });
}

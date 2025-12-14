import 'dart:async';
import 'package:flutter/material.dart';

const _ink = Color(0xFF0E3E3E);
const _blue = Color(0xFF7DB2FF);

class LoadingPlanScreen extends StatefulWidget {
  const LoadingPlanScreen({
    super.key,
    required this.skill,
    required this.hour,
    required this.start,
    required this.restDays,
    required this.level,
  });

  final String skill;
  final String hour;
  final DateTime start;
  final List<String> restDays;
  final String level;

  @override
  State<LoadingPlanScreen> createState() => _LoadingPlanScreenState();
}

class _LoadingPlanScreenState extends State<LoadingPlanScreen>
    with TickerProviderStateMixin {
  double progress = 0.0;
  Timer? _timer;
  Timer? _tipTimer;
  Timer? _statusTimer;
  int _currentTipIndex = 0;
  int _currentStatusIndex = 0;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  // AI 모델 정보
  static const String _aiModel = 'GPT-4o';
  static const String _searchEngine = 'Web Search';

  // 로딩 상태 메시지 (단계별)
  final List<Map<String, String>> _statusMessages = [
    {'status': '학습 주제 분석 중...', 'model': _aiModel},
    {'status': '관련 강좌 검색 중...', 'model': '$_aiModel + $_searchEngine'},
    {'status': '커리큘럼 구성 중...', 'model': _aiModel},
    {'status': '학습 일정 최적화 중...', 'model': _aiModel},
    {'status': '퀴즈 준비 중...', 'model': _aiModel},
  ];

  // Palearn 사용 팁 (더 상세하게)
  final List<Map<String, dynamic>> _tips = [
    {
      'icon': Icons.lightbulb_outline,
      'title': 'AI 맞춤 학습',
      'desc': 'GPT-4o가 사용자의 수준과 목표에 맞는 커리큘럼을 자동 생성합니다'
    },
    {
      'icon': Icons.schedule,
      'title': '스마트 일정 관리',
      'desc': '하루 학습량은 설정한 시간에 맞춰 자동으로 조절됩니다'
    },
    {
      'icon': Icons.video_library,
      'title': '검증된 학습 자료',
      'desc': '인프런, 유튜브 등에서 실제 존재하는 강좌만 추천합니다'
    },
    {
      'icon': Icons.quiz,
      'title': '실력 확인 퀴즈',
      'desc': '학습 전 퀴즈로 현재 실력을 점검하고 맞춤 난이도를 설정합니다'
    },
    {
      'icon': Icons.trending_up,
      'title': '진도 추적',
      'desc': '매일 학습 완료 체크로 진행 상황을 한눈에 파악하세요'
    },
    {
      'icon': Icons.people_outline,
      'title': '친구와 함께',
      'desc': '친구 추가 후 서로의 학습 진도를 확인하며 동기부여를 얻으세요'
    },
    {
      'icon': Icons.replay,
      'title': '복습 기능',
      'desc': '어제 학습한 내용의 복습 자료를 매일 추천받을 수 있습니다'
    },
    {
      'icon': Icons.calendar_today,
      'title': '휴식일 설정',
      'desc': '쉬고 싶은 요일을 지정하면 해당 날짜는 학습 일정에서 제외됩니다'
    },
  ];

  @override
  void initState() {
    super.initState();

    // 펄스 애니메이션
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 회전 애니메이션
    _rotateController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(_rotateController);

    // 4초마다 팁 변경
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });

    // 1.5초마다 상태 메시지 변경
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _currentStatusIndex = (_currentStatusIndex + 1) % _statusMessages.length;
        });
      }
    });

    _goToQuiz();
  }

  Future<void> _goToQuiz() async {
    // 로딩 애니메이션 (퀴즈 준비 중 표시용)
    _timer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (mounted) {
        setState(() => progress = (progress + 0.015).clamp(0.0, 0.95));
      }
    });

    // 잠시 대기 후 퀴즈 화면으로 이동
    await Future.delayed(const Duration(milliseconds: 1500));

    _timer?.cancel();
    if (!mounted) return;
    setState(() => progress = 1.0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // 퀴즈 화면으로 이동 (설정 정보를 함께 전달)
    Navigator.pushReplacementNamed(
      context,
      '/quiz',
      arguments: {
        'skill': widget.skill,
        'level': widget.level,
        'hourPerDay': double.tryParse(widget.hour) ?? 1.0,
        'startDate': widget.start.toIso8601String(),
        'restDays': widget.restDays,
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tipTimer?.cancel();
    _statusTimer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    final currentStatus = _statusMessages[_currentStatusIndex];
    final currentTip = _tips[_currentTipIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFEFF4FF),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F0FF),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: _ink, size: 18),
                  SizedBox(width: 6),
                  Text(
                    '새로운 학습 계획 만들기',
                    style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // AI 모델 정보 배지
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Container(
                key: ValueKey<int>(_currentStatusIndex),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _blue.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotationTransition(
                      turns: _rotateAnimation,
                      child: const Icon(Icons.auto_awesome, color: _blue, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentStatus['model']!,
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // 애니메이션 아이콘
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _blue.withValues(alpha: 0.3),
                      _blue.withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.psychology,
                      size: 45,
                      color: _blue,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 상태 메시지
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                key: ValueKey<String>(currentStatus['status']!),
                currentStatus['status']!,
                style: const TextStyle(
                  fontSize: 15,
                  color: _ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 진행바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      minHeight: 20,
                      value: progress,
                      color: _blue,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 스킬 정보
            Text(
              '${widget.skill} 학습 준비 중',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            const Spacer(),

            // Palearn 팁 카드
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey<int>(_currentTipIndex),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        currentTip['icon'] as IconData,
                        color: _blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTip['title'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentTip['desc'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 하단 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_tips.length, (index) {
                return Container(
                  width: index == _currentTipIndex ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _currentTipIndex
                        ? _blue
                        : _blue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

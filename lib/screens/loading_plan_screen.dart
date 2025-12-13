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
    with SingleTickerProviderStateMixin {
  double progress = 0.0;
  Timer? _timer;
  Timer? _tipTimer;
  int _currentTipIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 로딩 중 표시할 팁 메시지
  final List<String> _tips = [
    '💡 Palearn은 AI가 맞춤형 학습 계획을 생성합니다',
    '📚 하루 학습량은 설정한 시간에 맞춰 자동 조절됩니다',
    '🎯 쉬는 요일에는 학습 일정이 배정되지 않아요',
    '📊 학습 통계로 진행 상황을 한눈에 확인하세요',
    '👥 친구와 함께 학습하면 동기부여가 됩니다',
    '🔔 알림으로 학습 일정을 놓치지 마세요',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3초마다 팁 변경
    _tipTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });

    _goToQuiz();
  }

  Future<void> _goToQuiz() async {
    // 로딩 애니메이션 (퀴즈 준비 중 표시용)
    _timer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (mounted) {
        setState(() => progress = (progress + 0.02).clamp(0.0, 0.95));
      }
    });

    // 잠시 대기 후 퀴즈 화면으로 이동
    // 계획 생성은 사용자가 강좌를 선택한 후에 수행됨
    await Future.delayed(const Duration(milliseconds: 800));

    _timer?.cancel();
    if (!mounted) return;
    setState(() => progress = 1.0);
    await Future.delayed(const Duration(milliseconds: 200));
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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
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
                    color: Colors.black.withOpacity(.03),
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

            const Spacer(),

            // 애니메이션 아이콘
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 50,
                  color: _blue,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 진행바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  minHeight: 22,
                  value: progress,
                  color: _blue,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('$percent%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
            const SizedBox(height: 18),
            Text(
              'AI가 ${widget.skill} 학습 계획을 준비하고 있습니다...',
              style: const TextStyle(fontSize: 16, color: _ink),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // 팁 메시지 (페이드 애니메이션)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Container(
                key: ValueKey<int>(_currentTipIndex),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _tips[_currentTipIndex],
                  style: const TextStyle(
                    fontSize: 14,
                    color: _ink,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

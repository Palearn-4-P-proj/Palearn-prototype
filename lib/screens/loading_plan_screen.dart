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

class _LoadingPlanScreenState extends State<LoadingPlanScreen> {
  double progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
              child: Row(
                children: const [
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
            Text('$percent%', style: const TextStyle(fontSize: 16, color: _ink)),
            const SizedBox(height: 18),
            const Text('AI가 열심히 작업 중입니다 …',
                style: TextStyle(fontSize: 16, color: _ink)),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

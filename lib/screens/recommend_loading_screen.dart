// lib/screens/recommend_loading_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api_service.dart';

const _ink = Color(0xFF0E3E3E);
const _blue = Color(0xFF7DB2FF);
const _blueLight = Color(0xFFE7F0FF);

class RecommendLoadingScreen extends StatefulWidget {
  const RecommendLoadingScreen({super.key});

  @override
  State<RecommendLoadingScreen> createState() => _RecommendLoadingScreenState();
}

class _RecommendLoadingScreenState extends State<RecommendLoadingScreen> {
  double progress = 0.0;
  Timer? _timer;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  String _statusMessage = 'AI가 학습 계획을 준비하고 있어요';

  // 선택한 강좌(있다면)
  Map<String, dynamic>? selectedCourse;
  String _skill = 'general';
  String _level = '초급';
  String _courseTitle = '';

  // 계획 설정 정보
  double _hourPerDay = 1.0;
  String _startDate = '';
  List<String> _restDays = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        selectedCourse = Map<String, dynamic>.from(args['selectedCourse'] ?? {});
        _skill = args['skill']?.toString() ?? 'general';
        _level = args['level']?.toString() ?? '초급';
        _hourPerDay = (args['hourPerDay'] as num?)?.toDouble() ?? 1.0;
        _startDate = args['startDate']?.toString() ?? DateTime.now().toIso8601String();
        _restDays = (args['restDays'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        _courseTitle = selectedCourse?['title']?.toString() ?? '선택한 강좌';
      }
      _startElapsedTimer();
      _applyRecommendation();
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
          _updateStatusMessage();
        });
      }
    });
  }

  void _updateStatusMessage() {
    if (_elapsedSeconds < 5) {
      _statusMessage = '선택한 강좌의 커리큘럼을 분석하고 있어요';
    } else if (_elapsedSeconds < 15) {
      _statusMessage = 'AI가 최적의 학습 일정을 계산하고 있어요';
    } else if (_elapsedSeconds < 30) {
      _statusMessage = '학습 자료를 검색하고 연결하고 있어요';
    } else if (_elapsedSeconds < 50) {
      _statusMessage = '거의 완료됐어요! 마무리 작업 중...';
    } else {
      _statusMessage = 'GPT가 신중하게 계획을 만들고 있어요';
    }
  }

  Future<void> _applyRecommendation() async {
    _timer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (mounted) {
        setState(() => progress = (progress + 0.003).clamp(0.0, 0.9));
      }
    });

    try {
      if (selectedCourse != null && selectedCourse!.isNotEmpty) {
        debugPrint('=== Calling applyRecommendation ===');
        debugPrint('Course: ${selectedCourse?['title']}');
        debugPrint('Skill: $_skill, Level: $_level');
        debugPrint('HourPerDay: $_hourPerDay');

        final result = await RecommendService.applyRecommendation(
          selectedCourse: selectedCourse!,
          quizLevel: _level,
          skill: _skill,
          hourPerDay: _hourPerDay,
          startDate: _startDate.isNotEmpty ? _startDate : DateTime.now().toIso8601String(),
          restDays: _restDays,
        );

        debugPrint('=== applyRecommendation Result ===');
        debugPrint('Success: ${result['success']}');
        debugPrint('Plan: ${result['plan']?['plan_name']}');

        // 캐시 무효화
        await CacheManager.clearCache('/plans/all');
        await CacheManager.clearCache('/home/header');
      } else {
        debugPrint('=== No course selected, skipping API call ===');
      }

      _timer?.cancel();
      _elapsedTimer?.cancel();
      if (!mounted) return;
      setState(() {
        progress = 1.0;
        _statusMessage = '학습 계획이 완성되었어요!';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e, stackTrace) {
      debugPrint('=== Error applying recommendation ===');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');

      _timer?.cancel();
      _elapsedTimer?.cancel();
      if (!mounted) return;
      setState(() {
        progress = 1.0;
        _statusMessage = '오류가 발생했지만 홈으로 이동합니다';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    return PopScope(
      // 로딩 중 뒤로가기 방지
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FD),
        body: SafeArea(
          child: Column(
            children: [
              // 상단 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  color: _blueLight,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        SizedBox(width: 8),
                        Text(
                          '📘 학습 계획 생성 중',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (_courseTitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          _courseTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black38,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // 로딩 컨테이너
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // 로딩 아이콘
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _blueLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(_blue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 로딩바
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 16,
                        backgroundColor: const Color(0xFFEAECEF),
                        valueColor: const AlwaysStoppedAnimation<Color>(_blue),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 퍼센트 + 경과 시간
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_elapsedSeconds}초',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 상태 메시지
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 16,
                        color: _ink,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // 안내 박스
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'GPT가 커리큘럼을 분석하여\n맞춤형 학습 계획을 만들고 있어요',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber[900],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

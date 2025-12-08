// lib/screens/quiz_result_screen.dart
import 'package:flutter/material.dart';
// 📌 FastAPI 연동 시 필요한 import
// import 'package:http/http.dart' as http;
// import 'dart:convert';

class QuizResultScreen extends StatelessWidget {
  final String level;      // '초급' | '중급' | '고급'
  final double rate;       // 0.0 ~ 1.0
  final List<bool> details;

  const QuizResultScreen({
    super.key,
    required this.level,
    required this.rate,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final _level = args?['level'] ?? level;
    final _rate = (args?['rate'] ?? rate) as double;
    final _details = (args?['details'] ?? details) as List<bool>;
    final _skill = args?['skill']?.toString() ?? 'general';
    final percent = (_rate * 100).round();

    // 계획 설정 정보
    final _hourPerDay = (args?['hourPerDay'] as num?)?.toDouble() ?? 1.0;
    final _startDate = args?['startDate']?.toString() ?? DateTime.now().toIso8601String();
    final _restDays = (args?['restDays'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      body: SafeArea(
        child: Column(
          children: [
            // ───────────── 헤더 + 뒤로가기 버튼 ─────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF7DB2FF),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // ← 뒤로가기
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),

                      const Spacer(),

                      const Text(
                        '📝 수준 진단 퀴즈',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),

                      const Spacer(),

                      // 오른쪽 더미 아이콘(가운데 정렬 유지)
                      Opacity(
                        opacity: 0,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Text('퀴즈 결과',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),

                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFD6E6FA),
                    child: Text(
                      _level,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ────────────────────────────────────────────────

            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 0),
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('상세 결과',
                            style: TextStyle(fontSize: 16, color: Colors.black54)),
                        const Spacer(),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _details.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (ctx, i) => Row(
                          children: [
                            Text('문제 ${i + 1}',
                                style: const TextStyle(color: Colors.black54)),
                            const Spacer(),
                            Text(
                              _details[i] ? '정답' : '오답',
                              style: TextStyle(
                                color: _details[i] ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _pillButton(
                          '다시 설정',
                          onTap: () {
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/quiz', (route) => route.isFirst);
                          },
                        ),
                        const SizedBox(width: 16),
                        _pillButton(
                          '강좌 추천 보기',
                          onTap: () async {
                            // =====================================================
                            // 🟦 서버로 추천 요청 보내기 — FastAPI POST 필요
                            //
                            // 엔드포인트 예:
                            // POST /recommend/courses
                            //
                            // 요청 Body 예:
                            // {
                            //   "level": _level,
                            //   "score": _rate,
                            //   "detail": _details
                            // }
                            //
                            // Flutter 예:
                            // final res = await http.post(
                            //   Uri.parse('$BASE/recommend/courses'),
                            //   headers: {"Content-Type": "application/json"},
                            //   body: json.encode({
                            //     "level": _level,
                            //     "score": _rate,
                            //     "detail": _details
                            //   }),
                            // );
                            // final courses = json.decode(res.body);
                            //
                            // Navigator.pushNamed(context, '/recommend_courses',
                            //    arguments: courses);
                            // =====================================================

                            Navigator.pushNamed(
                              context,
                              '/recommend_courses',
                              arguments: {
                                'skill': _skill,
                                'level': _level,
                                'hourPerDay': _hourPerDay,
                                'startDate': _startDate,
                                'restDays': _restDays,
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(String label, {required VoidCallback onTap}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

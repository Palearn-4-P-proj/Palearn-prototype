// lib/screens/quiz_screen.dart
import 'package:flutter/material.dart';

import '../data/quiz_repository.dart';
import '../data/api_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _repo = QuizService();

  List<QuizItem> _items = [];
  int _idx = 0;
  late List<String?> _answers;
  late List<bool?> _results; // 각 문제별 정답 여부
  bool _loading = true;

  String _skill = 'general';
  String _level = '초급';

  // 계획 설정 정보 (loading_plan_screen에서 전달받음)
  double _hourPerDay = 1.0;
  String _startDate = '';
  List<String> _restDays = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // arguments에서 skill, level, 계획 설정 정보 받기
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _skill = args['skill']?.toString() ?? 'general';
      _level = args['level']?.toString() ?? '초급';
      _hourPerDay = (args['hourPerDay'] as num?)?.toDouble() ?? 1.0;
      _startDate = args['startDate']?.toString() ?? DateTime.now().toIso8601String();
      _restDays = (args['restDays'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    }
    if (_items.isEmpty && _loading) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final list = await _repo.fetchQuizItems(
        skill: _skill,
        level: _level,
      );
      _items = list.take(10).toList();
      _answers = List<String?>.filled(_items.length, null);
      _results = List<bool?>.filled(_items.length, null);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error loading quiz: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('퀴즈 로딩 실패: $e')),
        );
      }
    }
  }

  void _setAnswer(String? v) {
    setState(() {
      _answers[_idx] = v;
    });
  }

  // 정답 확인 및 해설 표시
  void _checkAnswerAndShowExplanation() {
    final q = _items[_idx];
    final userAnswer = _answers[_idx];

    if (userAnswer == null || userAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('답을 선택해주세요!')),
      );
      return;
    }

    // 정답 확인
    final correctAnswer = q.answerKey ?? '';
    final isCorrect = userAnswer.trim().toUpperCase() == correctAnswer.trim().toUpperCase();
    _results[_idx] = isCorrect;

    // 해설 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              isCorrect ? '정답입니다!' : '오답입니다',
              style: TextStyle(
                color: isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('정답', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(
                      correctAnswer,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                const Text('해설', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    q.explanation!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ],
              if (!isCorrect) ...[
                const SizedBox(height: 12),
                Text(
                  '내 답: $userAnswer',
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // 다음 문제로 이동 또는 마지막이면 결과 화면으로
              if (_idx < _items.length - 1) {
                setState(() {
                  _idx++;
                });
              } else {
                _finish();
              }
            },
            child: Text(
              _idx < _items.length - 1 ? '다음 문제' : '결과 보기',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    try {
      final result = await _repo.grade(items: _items, userAnswers: _answers);
      if (!mounted) return;

      Navigator.pushNamed(context, '/quiz_result', arguments: {
        'level': result.level,
        'rate': result.rate,
        'details': result.detail,
        'skill': _skill,
        // 계획 설정 정보도 함께 전달
        'hourPerDay': _hourPerDay,
        'startDate': _startDate,
        'restDays': _restDays,
      });
    } catch (e) {
      debugPrint('Error grading quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('채점 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('퀴즈를 불러올 수 없습니다.')),
      );
    }

    final q = _items[_idx];
    final currentAnswer = _answers[_idx];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
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
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text(
                        '수준 진단 퀴즈',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Spacer(),
                      Opacity(
                        opacity: 0,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Text('${_idx + 1} / ${_items.length}',
                      style: const TextStyle(fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 16),

                  // 질문 박스
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6E6FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      q.question,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 문제 본문 - key를 사용하여 문제마다 새로운 위젯 생성
            Expanded(
              child: _buildQuestion(q, currentAnswer),
            ),

            // 하단 버튼 - 답 확인 후 다음으로
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _navButton('이전 질문', _idx > 0 ? () {
                    setState(() => _idx--);
                  } : null),
                  const SizedBox(width: 8),
                  _navButton(
                    '정답 확인',
                    _answers[_idx] != null ? _checkAnswerAndShowExplanation : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(QuizItem q, String? currentAnswer) {
    switch (q.type) {
      case 'OX':
        return _OXQuestion(
          key: ValueKey('ox_$_idx'),
          initialValue: currentAnswer,
          onAnswer: _setAnswer,
        );
      case 'MULTI':
        return _MultiQuestion(
          key: ValueKey('multi_$_idx'),
          options: q.options,
          initialValue: currentAnswer,
          onAnswer: _setAnswer,
        );
      case 'SHORT':
        return _ShortQuestion(
          key: ValueKey('short_$_idx'),
          initialValue: currentAnswer,
          onAnswer: _setAnswer,
        );
      default:
        return const Center(child: Text('유효하지 않은 질문 유형입니다.'));
    }
  }

  Widget _navButton(String label, VoidCallback? onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: onTap != null ? Colors.white : Colors.grey[300],
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

// OX 문제 위젯
class _OXQuestion extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onAnswer;

  const _OXQuestion({
    super.key,
    this.initialValue,
    required this.onAnswer,
  });

  @override
  State<_OXQuestion> createState() => _OXQuestionState();
}

class _OXQuestionState extends State<_OXQuestion> {
  String? selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _tile('O'),
            _tile('X'),
          ],
        ),
      ],
    );
  }

  Widget _tile(String label) {
    final active = selected == label;
    return GestureDetector(
      onTap: () {
        setState(() => selected = label);
        widget.onAnswer(label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7DB2FF) : const Color(0xFFD6E6FA),
          borderRadius: BorderRadius.circular(28),
          boxShadow: active
              ? [const BoxShadow(color: Color(0x4D2196F3), blurRadius: 12, offset: Offset(0, 4))]
              : null,
          border: Border.all(
            color: active ? const Color(0xFF1976D2) : Colors.transparent,
            width: 3,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : const Color(0xFF1976D2),
          ),
        ),
      ),
    );
  }
}

// 객관식 문제 위젯
class _MultiQuestion extends StatefulWidget {
  final List<String> options;
  final String? initialValue;
  final ValueChanged<String?> onAnswer;

  const _MultiQuestion({
    super.key,
    required this.options,
    this.initialValue,
    required this.onAnswer,
  });

  @override
  State<_MultiQuestion> createState() => _MultiQuestionState();
}

class _MultiQuestionState extends State<_MultiQuestion> {
  String? selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
      child: ListView.separated(
        itemCount: widget.options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final opt = widget.options[i];
          final isSel = selected == opt;
          return GestureDetector(
            onTap: () {
              setState(() => selected = opt);
              widget.onAnswer(opt);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFF7DB2FF) : const Color(0xFFD6E6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? const Color(0xFF1976D2) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  color: isSel ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 단답형 문제 위젯
class _ShortQuestion extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onAnswer;

  const _ShortQuestion({
    super.key,
    this.initialValue,
    required this.onAnswer,
  });

  @override
  State<_ShortQuestion> createState() => _ShortQuestionState();
}

class _ShortQuestionState extends State<_ShortQuestion> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        children: [
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: '답안을 입력하세요.',
              filled: true,
              fillColor: const Color(0xFFD6E6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onChanged: widget.onAnswer,
          ),
        ],
      ),
    );
  }
}

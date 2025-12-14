import 'package:flutter/material.dart';
import 'loading_plan_screen.dart';

const _ink = Color(0xFF0E3E3E);
const _blue = Color(0xFF7DB2FF);
const _blueLight = Color(0xFFE7F0FF);

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  // 1) 배우고 싶은 스킬
  final skills = const [
    '딥러닝', '머신러닝 기초', '머신러닝', '자바 스크립트', 'HTML 기초', '코딩테스트/알고리즘'
  ];
  String? selectedSkill;

  // 2) 하루 공부 시간 (30분 단위)
  final hours = const ['30분', '1시간', '1시간 30분', '2시간', '2시간 30분', '3시간', '3시간 30분', '4시간'];
  String? selectedHour;

  // 3) 시작 날짜
  DateTime? startDate;

  // 4) 쉬는 요일 (복수 선택)
  final weekDays = const ['월', '화', '수', '목', '금', '토', '일'];
  final Set<String> restDays = {};

  // 5) 현재 수준 (1~10 슬라이더)
  double _levelValue = 5.0;

  String get _levelText {
    if (_levelValue <= 3) return '초급';
    if (_levelValue <= 6) return '중급';
    return '고급';
  }

  String get _levelDescription {
    if (_levelValue <= 3) return '기초부터 차근차근 시작해요';
    if (_levelValue <= 6) return '기본 개념은 알고 있어요';
    return '실무 수준으로 심화 학습해요';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final last  = DateTime(now.year + 2);
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? first,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _blue,
              onPrimary: Colors.white,
              onSurface: _ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => startDate = picked);
  }

  String _getWeekdayName(int weekday) {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    return '${names[weekday - 1]}요일';
  }

  void _goNext() {
    if (selectedSkill == null ||
        selectedHour == null ||
        startDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('모든 항목을 입력해 주세요.')));
      return;
    }

    // 모든 요일을 쉬는 날로 선택한 경우 경고
    if (restDays.length == weekDays.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 요일을 쉬는 날로 지정할 수 없습니다.')),
      );
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LoadingPlanScreen(
        skill: selectedSkill!,
        hour: selectedHour!,
        start: startDate!,
        restDays: restDays.toList(),
        level: _levelText,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 뒤로가기 AppBar 추가 ————
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // ————————————————

      backgroundColor: const Color(0xFFF7F8FD),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: const BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('새로운 학습 계획 만들기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      )),
                ],
              ),
            ),

            // 폼
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _Labeled('배우고 싶은 스킬'),
                  _Rounded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('예: 파이썬, 머신러닝, 웹개발 등'),
                        value: selectedSkill,
                        items: [
                          for (final s in skills)
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (v) => setState(() => selectedSkill = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  _Labeled('하루 공부 시간'),
                  _Rounded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('하루 공부 시간을 선택하세요'),
                        value: selectedHour,
                        items: [
                          for (final h in hours)
                            DropdownMenuItem(value: h, child: Text(h)),
                        ],
                        onChanged: (v) => setState(() => selectedHour = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '💡 선택한 시간에 맞춰 하루 학습량이 자동 조절됩니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 18),

                  _Labeled('시작 날짜'),
                  _Rounded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        child: Row(
                          children: [
                            Text(
                              startDate == null
                                  ? '날짜를 선택하세요'
                                  : '${startDate!.year}년 ${startDate!.month}월 ${startDate!.day}일 (${_getWeekdayName(startDate!.weekday)})',
                            ),
                            const Spacer(),
                            const Icon(Icons.calendar_month_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  _Labeled('쉬는 요일 (복수 선택 가능)'),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      for (final d in weekDays)
                        FilterChip(
                          selected: restDays.contains(d),
                          label: Text('$d요일'),
                          onSelected: (sel) => setState(() {
                            sel ? restDays.add(d) : restDays.remove(d);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  _Labeled('현재 수준 (자가 진단)'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _blueLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _levelText,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_levelValue.round()}/10',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _levelDescription,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _blue,
                            inactiveTrackColor: Colors.grey[300],
                            thumbColor: _blue,
                            overlayColor: _blue.withValues(alpha: 0.2),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: _levelValue,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            onChanged: (value) => setState(() => _levelValue = value),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('초급', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            Text('중급', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            Text('고급', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 하단 버튼
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              color: const Color(0xFFF7F8FD),
              child: SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _goNext,
                  child: const Text('다음',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, size: 20, color: _ink),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Rounded extends StatelessWidget {
  const _Rounded({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _blueLight,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: child,
    );
  }
}

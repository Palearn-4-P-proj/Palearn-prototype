import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/api_service.dart';

const Color _ink = Color(0xFF0E3E3E);
const Color _blue = Color(0xFF7DB2FF);
const Color _blueLight = Color(0xFFE7F0FF);

// 숫자에 콤마 추가하는 헬퍼 함수
String _formatNumber(String numStr) {
  // 숫자만 추출
  final digits = numStr.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return numStr;

  final number = int.tryParse(digits);
  if (number == null) return numStr;

  // 콤마 추가
  final formatted = number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );

  // 원래 문자열에 단위가 있으면 붙여서 반환 (예: "명", "개" 등)
  final suffix = numStr.replaceAll(RegExp(r'[\d,\s]'), '');
  return suffix.isNotEmpty ? '$formatted$suffix' : formatted;
}

class RecommendCoursesScreen extends StatefulWidget {
  const RecommendCoursesScreen({super.key});

  @override
  State<RecommendCoursesScreen> createState() => _RecommendCoursesScreenState();
}

class _RecommendCoursesScreenState extends State<RecommendCoursesScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> courses = [];
  String _skill = 'general';
  String _level = '초급';
  bool _loading = true;
  bool _loadingStarted = false;  // 중복 로딩 방지
  String _searchModel = '';
  String _searchStatus = 'idle';
  int _elapsedSeconds = 0;  // 경과 시간 표시용
  Timer? _elapsedTimer;  // 경과 시간 타이머
  Timer? _tipTimer;  // 팁 전환 타이머
  int _currentTipIndex = 0;

  // 애니메이션 컨트롤러
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;

  // 계획 설정 정보 (quiz_result_screen에서 전달받음)
  double _hourPerDay = 1.0;
  String _startDate = '';
  List<String> _restDays = [];

  // Palearn 사용 팁 (로딩 중 표시)
  final List<Map<String, dynamic>> _tips = [
    {
      'icon': Icons.search,
      'title': 'AI 강좌 검색',
      'desc': 'GPT-5가 인프런, 유데미, 유튜브에서 실제 강좌를 검색합니다'
    },
    {
      'icon': Icons.verified,
      'title': '검증된 URL만 제공',
      'desc': '실제로 접근 가능한 강좌 링크만 추천해 드립니다'
    },
    {
      'icon': Icons.school,
      'title': '수준별 맞춤 추천',
      'desc': '퀴즈 결과를 바탕으로 적합한 난이도의 강좌를 찾습니다'
    },
    {
      'icon': Icons.menu_book,
      'title': '도서도 함께 추천',
      'desc': '온라인 강좌뿐만 아니라 관련 도서도 추천해 드립니다'
    },
    {
      'icon': Icons.play_circle_filled,
      'title': '무료 콘텐츠 포함',
      'desc': '유튜브, 부스트코스 등 무료 학습 자료도 함께 제공합니다'
    },
    {
      'icon': Icons.list_alt,
      'title': '상세 커리큘럼 확인',
      'desc': '각 강좌의 섹션별 강의 목록과 시간을 미리 확인하세요'
    },
    {
      'icon': Icons.schedule,
      'title': '학습 기간 안내',
      'desc': '각 강좌별 예상 학습 기간을 함께 알려드립니다'
    },
    {
      'icon': Icons.star,
      'title': '평점과 수강생 수',
      'desc': '다른 학습자들의 평가를 참고하여 선택하세요'
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

    // 4초마다 팁 변경
    _tipTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _loading) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadingStarted) {
      _loadingStarted = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _skill = args['skill']?.toString() ?? 'general';
        _level = args['level']?.toString() ?? '초급';
        _hourPerDay = (args['hourPerDay'] as num?)?.toDouble() ?? 1.0;
        _startDate = args['startDate']?.toString() ?? DateTime.now().toIso8601String();
        _restDays = (args['restDays'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      }
      _startElapsedTimer();
      _loadRecommendations();
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _tipTimer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  // 경과 시간 타이머 시작 (1초마다 업데이트)
  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _loading) {
        setState(() {
          _elapsedSeconds++;
        });
        // 검색 상태도 주기적으로 확인
        _fetchSearchStatus();
      } else {
        timer.cancel();
      }
    });
  }

  // 검색 상태 확인 (별도 메서드)
  Future<void> _fetchSearchStatus() async {
    try {
      final status = await RecommendService.getSearchStatus();
      if (mounted) {
        setState(() {
          _searchModel = status['model']?.toString() ?? '';
          _searchStatus = status['status']?.toString() ?? 'idle';
        });
      }
    } catch (e) {
      // 무시
    }
  }

  // 로딩 타이틀 (경과 시간에 따라 변경)
  String _getLoadingTitle() {
    final seconds = _elapsedSeconds;
    if (seconds < 10) {
      return 'AI가 강좌를 검색하고 있어요';
    } else if (seconds < 30) {
      return '최적의 강좌를 분석하고 있어요';
    } else if (seconds < 60) {
      return '거의 다 됐어요! 조금만 기다려주세요';
    } else {
      return '열심히 찾고 있어요...';
    }
  }

  // 로딩 메시지 (단계별 상세 설명)
  String _getLoadingMessage() {
    final seconds = _elapsedSeconds;
    if (_searchStatus == 'completed') {
      return '검색 완료! 결과를 정리하고 있습니다...';
    }
    if (seconds < 5) {
      return '$_skill $_level 수준에 맞는\n강좌를 찾기 시작했습니다';
    } else if (seconds < 15) {
      return '인프런, 유데미, 부스트코스 등\n다양한 플랫폼에서 검색 중...';
    } else if (seconds < 30) {
      return '발견한 강좌들의 커리큘럼과\n평점을 분석하고 있습니다';
    } else if (seconds < 50) {
      return '학습자 수준에 가장 적합한\n강좌를 선별하고 있습니다';
    } else {
      return 'GPT가 신중하게 추천을 준비 중입니다\n잠시만 더 기다려주세요!';
    }
  }

  // 로딩 UI 빌더
  Widget _buildLoadingUI() {
    final currentTip = _tips[_currentTipIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // AI 모델 배지
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Container(
              key: ValueKey<String>(_searchModel),
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
                    turns: _rotateController,
                    child: const Icon(Icons.auto_awesome, color: _blue, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _searchModel.isNotEmpty ? _searchModel : 'GPT-5 Search API',
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

          const SizedBox(height: 30),

          // 펄스 애니메이션 아이콘
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 100,
              height: 100,
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
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 38,
                    color: _blue,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 메인 메시지
          Text(
            _getLoadingTitle(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // 상세 메시지
          Text(
            _getLoadingMessage(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // 경과 시간 + 상태
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _blueLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _searchStatus == 'completed' ? Icons.check_circle : Icons.access_time,
                      size: 14,
                      color: _searchStatus == 'completed' ? Colors.green : _blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_elapsedSeconds}초 경과',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // 팁 카드
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      currentTip['icon'] as IconData,
                      color: _blue,
                      size: 26,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentTip['desc'] as String,
                          style: TextStyle(
                            fontSize: 13,
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

          // 팁 인디케이터
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

          const SizedBox(height: 24),

          // 검색 플랫폼 안내
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.amber[700]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '인프런, 유데미, 유튜브, 부스트코스 등에서\n$_skill 관련 최고의 강좌를 검색 중입니다',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _loadRecommendations() async {
    try {
      final data = await RecommendService.getCourses(
        skill: _skill,
        level: _level,
      );
      if (mounted) {
        setState(() {
          courses = data;
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('=== ERROR loading recommendations ===');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error Message: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('=====================================');
      if (mounted) {
        setState(() {
          courses = [];
          _loading = false;
        });
      }
    }
  }

  void _selectCourse(Map<String, dynamic> course) async {
    try {
      await RecommendService.selectCourse(
        userId: '',
        courseId: course['id']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('Error selecting course: $e');
    }

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/recommend_loading',
      arguments: {
        "selectedCourse": course,
        "skill": _skill,
        "level": _level,
        "hourPerDay": _hourPerDay,
        "startDate": _startDate,
        "restDays": _restDays,
      },
    );
  }

  // 상세 정보 다이얼로그 표시
  void _showCourseDetail(Map<String, dynamic> course) {
    final title = course['title'] ?? '제목 없음';
    final provider = course['provider'] ?? '알 수 없음';
    final instructor = course['instructor'] ?? '';
    final type = course['type'] ?? 'course';
    final weeks = course['weeks']?.toString() ?? '-';
    final free = (course['free'] ?? false) ? '무료' : '유료';
    final summary = course['summary'] ?? '';
    final price = course['price'] ?? '가격 정보 없음';
    final link = course['link'] ?? '';
    final rating = course['rating']?.toString() ?? '';
    final students = course['students']?.toString() ?? '';
    final duration = course['total_duration']?.toString() ?? course['duration']?.toString() ?? '';
    final levelDetail = course['level_detail']?.toString() ?? '';
    final reason = course['reason']?.toString() ?? '';
    final language = course['language']?.toString() ?? '';

    // total_lectures 처리 - 숫자만 추출
    String rawTotalLectures = course['total_lectures']?.toString() ?? '';
    // "54개" 같은 문자열에서 숫자만 추출
    final totalLecturesNum = RegExp(r'\d+').firstMatch(rawTotalLectures)?.group(0) ?? '';

    // 새로운 커리큘럼 형식 지원 (섹션별 강의 목록)
    final rawCurriculum = course['curriculum'] ?? course['syllabus'] ?? [];
    final bool isNewFormat = rawCurriculum is List && rawCurriculum.isNotEmpty && rawCurriculum.first is Map;

    // 총 강의 수 계산
    int lectureCount = 0;
    if (isNewFormat) {
      for (final section in rawCurriculum) {
        if (section is Map && section['lectures'] is List) {
          lectureCount += (section['lectures'] as List).length;
        }
      }
    } else if (rawCurriculum is List) {
      lectureCount = rawCurriculum.length;
    }

    // 표시할 강의 수 결정 (total_lectures 숫자 > 계산된 값 > 0)
    final displayLectureCount = totalLecturesNum.isNotEmpty
        ? int.tryParse(totalLecturesNum) ?? lectureCount
        : lectureCount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
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

              // 콘텐츠
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 타입 배지
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: type == 'book'
                                ? Colors.orange[100]
                                : _blueLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type == 'book' ? '📚 도서' : (type == 'youtube' ? '▶️ YouTube' : '🎓 강좌'),
                            style: TextStyle(
                              color:
                                  type == 'book' ? Colors.orange[800] : _blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: free == '무료'
                                ? Colors.green[100]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            free,
                            style: TextStyle(
                              color: free == '무료'
                                  ? Colors.green[800]
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (language.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: language == 'English'
                                  ? Colors.purple[100]
                                  : Colors.indigo[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              language == 'English' ? '🌐 English' : '🇰🇷 한국어',
                              style: TextStyle(
                                color: language == 'English'
                                    ? Colors.purple[800]
                                    : Colors.indigo[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 제목
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 제공자 & 강사
                    Row(
                      children: [
                        const Icon(Icons.business, size: 18, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          provider,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        if (instructor.isNotEmpty) ...[
                          const Text(' · ', style: TextStyle(color: Colors.grey)),
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            instructor,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // 평점 & 수강생
                    if (rating.isNotEmpty || students.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (rating.isNotEmpty) ...[
                            const Icon(Icons.star, size: 18, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              rating,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (students.isNotEmpty) ...[
                            const Icon(Icons.people, size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              _formatNumber(students),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          if (duration.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            const Icon(Icons.schedule, size: 18, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              duration,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],

                    // 레벨 태그
                    if (levelDetail.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up, size: 16, color: Colors.green[700]),
                            const SizedBox(width: 6),
                            Text(
                              levelDetail,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 추천 이유
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber[700]),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '추천 이유',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[800],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.amber[900],
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 정보 카드들
                    Row(
                      children: [
                        Expanded(
                          child: _infoCard('학습 기간', '${weeks}주'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _infoCard('강의 수', '${displayLectureCount}개'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _infoCard('가격', price),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 설명
                    const Text(
                      '소개',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        summary.isNotEmpty ? summary : '설명이 없습니다.',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 커리큘럼 (상세 강의 목록)
                    if (rawCurriculum is List && rawCurriculum.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.list_alt, color: _blue, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            '커리큘럼',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _blueLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '총 $displayLectureCount강',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 새로운 형식: 섹션별 강의 목록
                      if (isNewFormat) ...[
                        ...rawCurriculum.map((section) {
                          if (section is! Map) return const SizedBox.shrink();
                          final sectionName = section['section']?.toString() ?? '';
                          final lectures = section['lectures'] as List? ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 섹션 헤더
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5A9BF6),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  sectionName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              // 강의 목록
                              ...lectures.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final lecture = entry.value;
                                final lectureTitle = lecture is Map
                                    ? lecture['title']?.toString() ?? ''
                                    : lecture.toString();
                                final lectureDuration = lecture is Map
                                    ? lecture['duration']?.toString() ?? ''
                                    : '';
                                final lectureDesc = lecture is Map
                                    ? lecture['description']?.toString() ?? ''
                                    : '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(8),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF7DB2FF), Color(0xFF5A9BF6)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${idx + 1}',
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
                                                lectureTitle,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: _ink,
                                                ),
                                              ),
                                              if (lectureDesc.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  lectureDesc,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons.play_circle_outline, size: 14, color: Colors.grey[500]),
                                                  const SizedBox(width: 4),
                                                  Text('영상 강의', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                                  if (lectureDuration.isNotEmpty) ...[
                                                    const SizedBox(width: 12),
                                                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                                    const SizedBox(width: 4),
                                                    Text(lectureDuration, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }),
                      ] else ...[
                        // 기존 형식: 문자열 리스트
                        ...rawCurriculum.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value.toString();
                          final isSection = item.startsWith('섹션') ||
                              item.startsWith('Section') ||
                              item.startsWith('Part');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isSection ? const Color(0xFF5A9BF6) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: isSection ? null : Border.all(color: Colors.grey.shade200),
                              boxShadow: isSection ? null : [
                                BoxShadow(
                                  color: Colors.black.withAlpha(8),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(isSection ? 14 : 16),
                              child: Row(
                                children: [
                                  if (!isSection)
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF7DB2FF), Color(0xFF5A9BF6)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${idx + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  if (!isSection) const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: TextStyle(
                                        fontSize: isSection ? 15 : 14,
                                        fontWeight: isSection ? FontWeight.bold : FontWeight.w500,
                                        color: isSection ? Colors.white : _ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],

                    const SizedBox(height: 24),

                    // 버튼들
                    Row(
                      children: [
                        // 링크 복사 버튼
                        if (link.isNotEmpty)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: link));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('링크가 클립보드에 복사되었습니다!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('링크 복사'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        if (link.isNotEmpty) const SizedBox(width: 12),

                        // 선택 버튼
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _selectCourse(course);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '이 강좌로 학습하기',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // AI Summary 박스 빌더
  Widget _buildAiSummaryBox() {
    // 첫 번째 강좌에서 ai_summary 가져오기
    final aiSummary = courses.isNotEmpty
        ? (courses[0]['ai_summary']?.toString() ?? '')
        : '';

    // ai_summary가 없으면 기본 메시지 표시
    final displayText = aiSummary.isNotEmpty
        ? aiSummary
        : '$_level 수준의 $_skill 학습자를 위해 인프런, Udemy, YouTube 등에서 검색한 추천 강좌입니다.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7DB2FF).withAlpha(30),
            const Color(0xFF5A9BF6).withAlpha(20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _blue.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: _blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI 추천 요약',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayText.length > 200
                ? '${displayText.substring(0, 200)}...'
                : displayText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '총 ${courses.length}개의 강좌를 찾았습니다',
            style: TextStyle(
              fontSize: 12,
              color: _blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: _blueLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
              decoration: const BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
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
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '추천 강좌 & 도서',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_skill · $_level 수준에 맞는 콘텐츠',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 리스트
            Expanded(
              child: _loading
                  ? _buildLoadingUI()
                  : courses.isEmpty
                      ? const Center(
                          child: Text(
                            '추천할 강좌가 없습니다.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: courses.length + 1, // +1 for AI summary box
                          itemBuilder: (_, i) {
                            // 첫 번째 아이템: AI Summary 박스
                            if (i == 0) {
                              return _buildAiSummaryBox();
                            }
                            // 나머지: 강좌 목록 (index - 1)
                            return _CourseListItem(
                              data: courses[i - 1],
                              onTap: () => _showCourseDetail(courses[i - 1]),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseListItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _CourseListItem({required this.data, required this.onTap});

  int _countLectures(dynamic curriculum) {
    if (curriculum == null) return 0;
    if (curriculum is! List) return 0;
    if (curriculum.isEmpty) return 0;

    // 새로운 형식: 섹션별 강의 목록
    if (curriculum.first is Map && curriculum.first['lectures'] != null) {
      int count = 0;
      for (final section in curriculum) {
        if (section is Map && section['lectures'] is List) {
          count += (section['lectures'] as List).length;
        }
      }
      return count;
    }
    // 기존 형식: 문자열 리스트
    return curriculum.length;
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '제목 없음';
    final provider = data['provider'] ?? '';
    final type = data['type'] ?? 'course';
    final free = (data['free'] ?? false);
    final summary = data['summary'] ?? '';
    final language = data['language']?.toString() ?? '';

    // total_lectures에서 숫자만 추출 (54개 -> 54)
    final rawTotalLectures = data['total_lectures']?.toString() ?? '';
    final totalLecturesNum = RegExp(r'\d+').firstMatch(rawTotalLectures)?.group(0);
    final rawCurriculum = data['curriculum'] ?? data['syllabus'];
    final calculatedCount = _countLectures(rawCurriculum);
    final lectureCount = totalLecturesNum != null
        ? int.tryParse(totalLecturesNum) ?? calculatedCount
        : calculatedCount;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 배지
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: type == 'book' ? Colors.orange[50] : _blueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    type == 'book' ? '📚 도서' : (type == 'youtube' ? '▶️ YouTube' : '🎓 강좌'),
                    style: TextStyle(
                      fontSize: 12,
                      color: type == 'book' ? Colors.orange[700] : _blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (free)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '무료',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (language.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: language == 'English' ? Colors.purple[50] : Colors.indigo[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      language == 'English' ? '🌐 EN' : '🇰🇷 KR',
                      style: TextStyle(
                        fontSize: 12,
                        color: language == 'English' ? Colors.purple[700] : Colors.indigo[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text(
                  provider,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 제목
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                summary,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // 하단 정보
            Row(
              children: [
                const Icon(Icons.play_circle_outline, size: 16, color: _blue),
                const SizedBox(width: 4),
                Text(
                  '$lectureCount개 콘텐츠',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                const Text(
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
}

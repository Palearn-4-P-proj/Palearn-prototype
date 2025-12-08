// lib/data/quiz_repository.dart

/// ===== 모델 =====
class QuizItem {
  final int id;
  final String type; // 'OX' | 'MULTI' | 'SHORT'
  final String question;
  final List<String> options; // MULTI 전용
  final String? answerKey;    // 정답(있다면)
  final String? explanation;  // 해설 (왜 정답인지/오답인지)

  QuizItem({
    required this.id,
    required this.type,
    required this.question,
    this.options = const [],
    this.answerKey,
    this.explanation,
  });

  factory QuizItem.fromMap(Map<String, dynamic> m) => QuizItem(
    id: m['id'] as int,
    type: m['type'] as String,
    question: m['question'] as String,
    options:
    (m['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [],
    answerKey: m['answerKey']?.toString(),
    explanation: m['explanation']?.toString(),
  );
}

class QuizResult {
  final int total;
  final int correct;
  final List<bool> detail;

  QuizResult({required this.total, required this.correct, required this.detail});

  double get rate => total == 0 ? 0 : correct / total;

  String get level {
    if (rate >= 0.8) return '고급';
    if (rate >= 0.5) return '중급';
    return '초급';
  }
}

/// ===== DB 연동용 인터페이스 =====
///
/// ※ 여기가 Flutter <-> FastAPI 통신을 실제로 구현해야 하는 부분.
///   실제 구현체(예: APIQuizRepository)는 이 인터페이스를 구현함.
///
/// FastAPI 예시 API 구조:
///   GET  /quiz/items        → 문제 리스트 조회
///   POST /quiz/grade        → 채점 요청(문제 ID + userAnswers)
///
abstract class QuizRepository {

  /// ============================================
  /// TODO: GET /quiz/items
  /// - 백엔드에서 퀴즈 목록을 받아오는 통신 필요
  /// - 반환 값: List<QuizItem> (JSON 리스트)
  /// ============================================
  Future<List<QuizItem>> fetchQuizItems();

  /// ============================================
  /// TODO: POST /quiz/grade
  /// - 사용자의 답안을 FastAPI로 전송해 채점 요청
  /// - 전송 데이터 예시:
  ///     {
  ///       "answers": [
  ///         {"id": 1, "userAnswer": "O"},
  ///         {"id": 2, "userAnswer": "2"},
  ///         ...
  ///       ]
  ///     }
  /// - FastAPI가 채점 후 응답:
  ///     {
  ///       "total": 10,
  ///       "correct": 7,
  ///       "detail": [true, false, ...]
  ///     }
  /// ============================================
  Future<QuizResult> grade({
    required List<QuizItem> items,
    required List<String?> userAnswers,
  });
}

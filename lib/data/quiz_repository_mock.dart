// lib/data/quiz_repository_mock.dart

import 'quiz_repository.dart';

/// 로컬 테스트용 Mock Repository
/// 서버 연동 전 UI 테스트에 사용
class MockQuizRepository implements QuizRepository {
  @override
  Future<List<QuizItem>> fetchQuizItems() async {
    // 테스트용 더미 데이터
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      QuizItem(id: 1, type: 'OX', question: 'Python은 인터프리터 언어이다.', answerKey: 'O'),
      QuizItem(id: 2, type: 'OX', question: 'Java는 컴파일 언어이다.', answerKey: 'O'),
      QuizItem(id: 3, type: 'MULTI', question: '다음 중 프로그래밍 언어가 아닌 것은?',
               options: ['Python', 'Java', 'HTML', 'C++'], answerKey: 'HTML'),
      QuizItem(id: 4, type: 'MULTI', question: '리스트의 첫 번째 요소 인덱스는?',
               options: ['0', '1', '-1', 'None'], answerKey: '0'),
      QuizItem(id: 5, type: 'SHORT', question: 'print("Hello")의 출력 결과는?', answerKey: 'Hello'),
      QuizItem(id: 6, type: 'OX', question: 'Flutter는 Google이 만들었다.', answerKey: 'O'),
      QuizItem(id: 7, type: 'MULTI', question: 'Flutter에서 UI 구성 요소를 무엇이라 하는가?',
               options: ['Component', 'Widget', 'Element', 'View'], answerKey: 'Widget'),
      QuizItem(id: 8, type: 'OX', question: 'Dart는 정적 타입 언어이다.', answerKey: 'O'),
      QuizItem(id: 9, type: 'SHORT', question: '1 + 1 = ?', answerKey: '2'),
      QuizItem(id: 10, type: 'MULTI', question: '다음 중 Flutter의 상태관리 방법이 아닌 것은?',
               options: ['Provider', 'Redux', 'GetX', 'Django'], answerKey: 'Django'),
    ];
  }

  @override
  Future<QuizResult> grade({
    required List<QuizItem> items,
    required List<String?> userAnswers,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    int correct = 0;
    List<bool> detail = [];

    for (int i = 0; i < items.length; i++) {
      final isCorrect = userAnswers[i]?.toLowerCase() == items[i].answerKey?.toLowerCase();
      detail.add(isCorrect);
      if (isCorrect) correct++;
    }

    return QuizResult(
      total: items.length,
      correct: correct,
      detail: detail,
    );
  }
}

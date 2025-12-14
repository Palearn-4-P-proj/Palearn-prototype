# Backend/routers/quiz.py
"""퀴즈 관련 라우터"""

from fastapi import APIRouter, Depends
from typing import Dict

from models.schemas import QuizSubmitRequest
from services.store import store
from services.gpt_service import call_gpt, extract_json
from utils.logger import log_request, log_stage, log_success, log_navigation
from .auth import get_current_user

router = APIRouter(prefix="/quiz", tags=["Quiz"])


@router.get("/items")
async def get_quiz_items(
    skill: str = "general",
    level: str = "초급",
    limit: int = 10,
    current_user: Dict = Depends(get_current_user)
):
    log_request("GET /quiz/items", current_user['name'], f"skill={skill}, level={level}, limit={limit}")
    log_stage(4, "퀴즈 시작", current_user['name'])
    log_navigation(current_user['name'], "퀴즈 화면")

    # 강화된 프롬프트 - O/X 퀴즈 + explanation
    prompt = f"""[시스템 지시]
당신은 '{skill}' 분야의 개념 이해도를 점검하는 OX 퀴즈 출제기입니다.
오직 JSON만 출력하세요. (마크다운/코드블록/설명 금지)

🚨🚨🚨 **언어 규칙 - 매우 중요** 🚨🚨🚨
- question과 explanation은 반드시 **한국어**로만 작성하세요.
- 영어로 작성하면 안 됩니다. 무조건 한국어입니다.
- 기술 용어(예: Python, API, React 등)는 그대로 사용 가능하지만, 문장은 한국어로 작성하세요.

[목표]
- {level} 학습자용 '{skill}' OX 퀴즈 10개 생성

[핵심 규칙]
1) 모든 문항은 '{skill}'의 핵심 개념/용어/상황을 반드시 포함해야 합니다.
   - 각 question에 '{skill}' 관련 키워드(개념명/용어/기술/문제상황) 최소 1개 포함
2) 일반상식/컴퓨터기초/역사/시사/언어상식 같은 "도메인 외 상식 문제"는 절대 금지.
   - 금지 예: RAM/HTML/CPU/IP 같은 범용 IT 상식(단, '{skill}'에 직접적으로 필수인 경우만 허용)
3) OX로 명확히 판별 가능해야 하며, 애매한 표현("대부분", "가끔", "상황에 따라") 금지
4) explanation은 1~2문장으로 짧고 명확하게(속도 우선), 반드시 한국어로 작성

[난이도]
- {level} 수준에 맞춘 개념으로 구성
- 너무 사소한 암기형보다 "헷갈리기 쉬운 개념/오해 포인트" 위주

[반드시 따를 스키마]
{{"quizzes":[
  {{"id":1,"type":"OX","question":"한국어 질문...","options":[],"answerKey":"O","explanation":"한국어 설명..."}},
  ...
  {{"id":10,"type":"OX","question":"한국어 질문...","options":[],"answerKey":"X","explanation":"한국어 설명..."}}
]}}
- quizzes 길이 = 10, id=1..10, type="OX", options=[]
- answerKey는 "O" 또는 "X"만
- question과 explanation은 반드시 한국어

오직 JSON만 출력하세요. question과 explanation은 반드시 한국어로 작성하세요."""

    response = call_gpt(prompt, use_search=False)
    data = extract_json(response)

    if data and 'quizzes' in data:
        store.quiz_answers[current_user['user_id']] = data['quizzes']
        log_success(f"퀴즈 {len(data['quizzes'])}개 생성 완료")
        return data['quizzes']

    # 기본 퀴즈 (폴백) - explanation 추가
    default_quizzes = [
        {"id": 1, "type": "OX", "question": "컴퓨터는 0과 1로 모든 연산을 처리한다.", "options": [], "answerKey": "O", "explanation": "컴퓨터는 이진법(Binary)을 사용하여 0과 1만으로 모든 데이터를 표현하고 연산합니다. 이를 디지털 연산이라고 합니다."},
        {"id": 2, "type": "OX", "question": "인터넷과 월드와이드웹(WWW)은 같은 의미이다.", "options": [], "answerKey": "X", "explanation": "인터넷은 컴퓨터들을 연결하는 네트워크 인프라이고, WWW는 인터넷 위에서 동작하는 서비스 중 하나입니다. WWW는 인터넷의 일부일 뿐입니다."},
        {"id": 3, "type": "OX", "question": "프로그래밍 언어는 기계어만 존재한다.", "options": [], "answerKey": "X", "explanation": "프로그래밍 언어는 기계어 외에도 어셈블리어(저급 언어), Python/Java/C++ 같은 고급 언어 등 다양하게 존재합니다."},
        {"id": 4, "type": "OX", "question": "RAM은 전원이 꺼지면 데이터가 사라지는 휘발성 메모리이다.", "options": [], "answerKey": "O", "explanation": "RAM(Random Access Memory)은 휘발성 메모리로, 전원이 꺼지면 저장된 데이터가 모두 사라집니다. 반면 SSD나 HDD는 비휘발성입니다."},
        {"id": 5, "type": "OX", "question": "HTML은 프로그래밍 언어이다.", "options": [], "answerKey": "X", "explanation": "HTML은 HyperText Markup Language의 약자로, 웹 페이지의 구조를 정의하는 '마크업 언어'입니다. 프로그래밍 언어처럼 로직을 처리하지 않습니다."},
        {"id": 6, "type": "OX", "question": "1바이트(Byte)는 8비트(bit)이다.", "options": [], "answerKey": "O", "explanation": "1바이트는 8비트로 구성됩니다. 비트는 0 또는 1의 최소 정보 단위이고, 바이트는 컴퓨터에서 문자 하나를 표현하는 기본 단위입니다."},
        {"id": 7, "type": "OX", "question": "CPU는 컴퓨터의 장기 저장 장치이다.", "options": [], "answerKey": "X", "explanation": "CPU(Central Processing Unit)는 컴퓨터의 '두뇌'로, 연산과 제어를 담당합니다. 장기 저장은 HDD, SSD 같은 저장 장치가 담당합니다."},
        {"id": 8, "type": "OX", "question": "운영체제(OS)는 하드웨어와 소프트웨어 사이를 중재하는 시스템 소프트웨어이다.", "options": [], "answerKey": "O", "explanation": "운영체제는 컴퓨터 하드웨어를 관리하고, 응용 프로그램이 하드웨어를 사용할 수 있도록 인터페이스를 제공하는 시스템 소프트웨어입니다."},
        {"id": 9, "type": "OX", "question": "IP 주소는 인터넷에서 컴퓨터를 식별하는 고유한 주소이다.", "options": [], "answerKey": "O", "explanation": "IP(Internet Protocol) 주소는 네트워크상에서 각 장치를 식별하기 위한 고유한 숫자 주소입니다. IPv4는 32비트, IPv6는 128비트를 사용합니다."},
        {"id": 10, "type": "OX", "question": "클라우드 컴퓨팅은 반드시 인터넷 연결 없이도 사용할 수 있다.", "options": [], "answerKey": "X", "explanation": "클라우드 컴퓨팅은 인터넷을 통해 원격 서버의 리소스를 사용하는 기술이므로, 기본적으로 인터넷 연결이 필요합니다."},
    ]
    store.quiz_answers[current_user['user_id']] = default_quizzes
    return default_quizzes[:limit]


@router.post("/grade")
async def grade_quiz(request: QuizSubmitRequest, current_user: Dict = Depends(get_current_user)):
    log_request("POST /quiz/grade", current_user['name'], f"answers={len(request.answers)}개")
    log_stage(5, "퀴즈 채점", current_user['name'])

    saved_quizzes = store.quiz_answers.get(current_user['user_id'], [])
    answer_map = {q['id']: q['answerKey'] for q in saved_quizzes}

    total = len(request.answers)
    correct = 0
    detail = []

    for answer in request.answers:
        correct_answer = answer_map.get(answer.id, "")
        user_answer = answer.userAnswer.strip()
        expected = correct_answer.strip()

        # 비교 (대소문자 무시, 공백 정리)
        is_correct = user_answer.lower() == expected.lower()

        if is_correct:
            correct += 1
        detail.append(is_correct)

    rate = correct / total if total > 0 else 0

    if rate >= 0.8:
        level = "고급"
    elif rate >= 0.6:
        level = "중급"
    else:
        level = "초급"

    log_success(f"퀴즈 채점 완료: {correct}/{total} ({rate*100:.0f}%) → 레벨: {level}")
    log_navigation(current_user['name'], "퀴즈 결과 화면")

    return {
        "total": total,
        "correct": correct,
        "detail": detail,
        "rate": rate,
        "level": level
    }

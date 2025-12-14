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
    prompt = f"""[SYSTEM ROLE]
You are a quiz generator specialized in "{skill}". Generate O/X (True/False) quizzes for {level} learners.

[STRICT OUTPUT REQUIREMENTS]
- Output ONLY valid JSON. No markdown, no code blocks, no explanations before/after.
- All "question" and "explanation" fields MUST be written in Korean.
- Technical terms (Python, API, React, etc.) may remain in English, but sentences must be Korean.

[DOMAIN CONSTRAINT - CRITICAL]
Topic scope: "{skill}" ONLY

REQUIRED: Every question MUST contain at least ONE of the following:
- A core concept specific to "{skill}"
- A technical term unique to "{skill}"
- A common misconception within "{skill}"
- A practical scenario involving "{skill}"

PROHIBITED question topics (auto-reject):
- Generic computer science (RAM, CPU, IP, HTTP) unless directly essential to "{skill}"
- General programming basics not specific to "{skill}"
- History, current events, general knowledge
- Cross-domain comparisons that don't test "{skill}" knowledge

[QUESTION QUALITY CRITERIA]
1. DETERMINISTIC: Must have exactly one correct answer (O or X), no ambiguity
2. FORBIDDEN phrases: "대부분", "보통", "가끔", "상황에 따라", "일반적으로"
3. FOCUSED: Test understanding, not memorization of trivia
4. DIFFICULTY: Match {level} level
   - 초급: Basic concepts, definitions, simple true/false facts
   - 중급: Application of concepts, common pitfalls, edge cases
   - 고급: Advanced patterns, performance implications, architectural decisions

[ANSWER DISTRIBUTION]
- Include mix of O (True) and X (False) answers
- Aim for approximately 5 O and 5 X answers
- Do not cluster same answers consecutively

[OUTPUT SCHEMA - EXACT FORMAT]
{{"quizzes":[
  {{"id":1,"type":"OX","question":"한국어 질문문장","options":[],"answerKey":"O","explanation":"한국어 해설 1-2문장"}},
  {{"id":2,"type":"OX","question":"한국어 질문문장","options":[],"answerKey":"X","explanation":"한국어 해설 1-2문장"}},
  ...
  {{"id":10,"type":"OX","question":"한국어 질문문장","options":[],"answerKey":"O","explanation":"한국어 해설 1-2문장"}}
]}}

SCHEMA RULES:
- "quizzes" array length = exactly 10
- "id" = sequential integers 1 through 10
- "type" = always "OX"
- "options" = always empty array []
- "answerKey" = only "O" or "X"
- "question" = Korean sentence ending with proper punctuation
- "explanation" = Korean, 1-2 sentences, explains why answer is correct

Generate quiz now. Output JSON only."""

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

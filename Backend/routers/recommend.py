# Backend/routers/recommend.py
"""강좌 추천 관련 라우터"""

from fastapi import APIRouter, Depends
from typing import Dict
import uuid

from models.schemas import SelectCourseRequest, ApplyRecommendationRequest
from services.store import store
from services.gpt_service import call_gpt, extract_json, get_search_status
from utils.logger import log_request, log_stage, log_success, log_navigation, log_info
from .auth import get_current_user

router = APIRouter(prefix="/recommend", tags=["Recommend"])


@router.get("/search_status")
async def get_current_search_status():
    """현재 AI 검색 상태 반환 (프론트엔드 로딩 화면용)"""
    return get_search_status()


@router.get("/courses")
async def get_recommended_courses(
    skill: str = "programming",
    level: str = "초급",
    current_user: Dict = Depends(get_current_user)
):
    log_request("GET /recommend/courses", current_user['name'], f"skill={skill}, level={level}")
    log_stage(6, "강좌 추천", current_user['name'])
    log_navigation(current_user['name'], "강좌 추천 화면")

    # 강화된 프롬프트 - 실제 강좌/도서 링크 + 커리큘럼 일치 강제
    prompt = f"""[시스템 지시]
당신은 "{skill}" 분야 학습자를 위한 교육 추천 AI입니다.
오직 JSON만 출력하세요. 설명/사과/메타 발화 금지.

────────────────────────────────
[URL 안정성 최우선 규칙 – 매우 중요]

1. 실제 접근 가능함을 **강하게 확신할 수 있는 경우에만** 링크를 출력하세요.
   - 조금이라도 불확실하면 해당 항목은 출력하지 마세요.

2. 다음과 같은 URL 생성 행위는 절대 금지입니다:
   - URL slug를 임의로 번역/조합/추측하여 생성
   - 강좌 제목을 그대로 URL에 끼워 맞추는 방식
   - 기억 기반으로 "있을 것 같은" 링크 생성

3. 다음 유형의 페이지는 추천 금지:
   - 404 / 접근 권한 없음 / 로그인 요구 페이지
   - 프로모션·랜딩·오리지널·브랜드 페이지
   - 시리즈/묶음/카테고리 페이지
   - 수료 과정 소개 페이지 (강의 상세 아님)

4. 확실한 상세 페이지를 찾을 수 없는 경우:
   - 억지로 비슷한 강좌를 만들지 말고
   - 도서(book) 또는 유튜브 단일 강의로 대체하세요.

5. link_accessible 필드 규칙:
   - true로 표기한 링크는 "정상 강의 상세 페이지"라고 확신하는 경우만 허용
   - false일 가능성이 있는 링크는 절대 출력하지 마세요.

────────────────────────────────
[추천 구성 – 비용 접근성 유지]
- 전체 6개 중:
  - 무료 콘텐츠 ≥ 2
  - 도서(book) ≥ 2
  - 유료 강좌 ≤ 2

────────────────────────────────
[플랫폼 제한]
- 인프런, 유데미, 클래스101, 부스트코스, 코세라
- 교보문고, 예스24
- 유튜브 단일 강의 영상

검색/카테고리/블로그 URL 절대 금지

────────────────────────────────
[콘텐츠 작성 규칙]
- summary: 1~2문장
- curriculum: 실제 페이지 기반 항목 최소 3개
- 커리큘럼을 확인할 수 없는 경우 해당 항목 제외

────────────────────────────────
[JSON 형식]
{{
  "recommendations": [
    {{
      "id": "uuid",
      "title": "실제 제목",
      "provider": "플랫폼명",
      "instructor": "강사/저자",
      "type": "course 또는 book",
      "weeks": 4,
      "free": true 또는 false,
      "rating": 45,
      "students": "1234명",
      "summary": "소개 요약",
      "reason": "{level} 학습자에게 적합한 이유",
      "curriculum": ["목차1", "목차2", "목차3"],
      "link": "실제 상세페이지 URL",
      "price": "가격 또는 무료",
      "duration": "학습 시간",
      "level_detail": "{level} 수준"
    }}
  ]
}}

총 6개만 출력하세요."""

    response = call_gpt(prompt, use_search=True)
    data = extract_json(response)

    if data and 'error' not in data:
        # recommendations 또는 courses 키 모두 지원
        courses = data.get('recommendations', data.get('courses', []))
        # example.com 필터링
        valid_courses = [c for c in courses if 'example' not in c.get('link', '').lower()]
        if valid_courses:
            log_success(f"강좌 {len(valid_courses)}개 추천 완료")
            return valid_courses[:6]

    log_info("GPT 응답 실패 또는 API 키 없음, 기본 추천 반환")
    return [
        {
            "id": str(uuid.uuid4()),
            "title": f"{skill} 입문 강좌 - 처음부터 배우는 완벽 가이드",
            "provider": "인프런",
            "instructor": "전문 강사",
            "type": "course",
            "weeks": 4,
            "free": False,
            "rating": 4.7,
            "students": "2500명+",
            "total_lectures": 20,
            "total_duration": "총 8시간 30분",
            "summary": f"{skill}의 기초부터 실무 활용까지 배울 수 있는 종합 강좌입니다. 초보자도 쉽게 따라할 수 있도록 구성되어 있습니다.",
            "reason": f"{level} 학습자가 {skill}의 기초 개념을 체계적으로 익히기에 최적화된 입문 강좌입니다.",
            "curriculum": [
                {
                    "section": "섹션 1: 시작하기",
                    "lectures": [
                        {"title": f"1강: {skill} 소개 및 학습 로드맵", "duration": "15분", "description": "강좌 소개와 학습 방향 안내"},
                        {"title": "2강: 개발 환경 설정하기", "duration": "25분", "description": "필요한 도구 설치 및 설정"},
                        {"title": "3강: 첫 번째 코드 작성", "duration": "20분", "description": "Hello World 프로그램 만들기"}
                    ]
                },
                {
                    "section": "섹션 2: 핵심 개념",
                    "lectures": [
                        {"title": "4강: 기본 문법과 구조 이해", "duration": "35분", "description": "프로그래밍 기본 문법 학습"},
                        {"title": "5강: 변수와 데이터 타입", "duration": "40분", "description": "데이터를 저장하고 다루는 방법"},
                        {"title": "6강: 연산자와 표현식", "duration": "30분", "description": "다양한 연산 방법 익히기"},
                        {"title": "7강: 조건문 마스터", "duration": "45분", "description": "if-else로 프로그램 흐름 제어"},
                        {"title": "8강: 반복문 마스터", "duration": "45분", "description": "for, while 반복 구조 학습"}
                    ]
                },
                {
                    "section": "섹션 3: 함수와 모듈",
                    "lectures": [
                        {"title": "9강: 함수 기초", "duration": "35분", "description": "함수 정의와 호출 방법"},
                        {"title": "10강: 매개변수와 반환값", "duration": "30분", "description": "함수에 데이터 전달하기"},
                        {"title": "11강: 내장 함수 활용", "duration": "25분", "description": "자주 쓰이는 내장 함수들"},
                        {"title": "12강: 모듈과 패키지", "duration": "30분", "description": "코드 재사용하기"}
                    ]
                },
                {
                    "section": "섹션 4: 실전 프로젝트",
                    "lectures": [
                        {"title": "13강: 미니 프로젝트 1 - 계산기", "duration": "50분", "description": "사칙연산 계산기 만들기"},
                        {"title": "14강: 미니 프로젝트 2 - 할 일 목록", "duration": "60분", "description": "To-do 리스트 앱 만들기"},
                        {"title": "15강: 마무리 및 다음 단계", "duration": "15분", "description": "학습 정리와 심화 학습 안내"}
                    ]
                }
            ],
            "link": f"https://www.inflearn.com/courses?s={skill}",
            "price": "55000원",
            "level_detail": f"{level} 수준에 적합"
        },
        {
            "id": str(uuid.uuid4()),
            "title": f"{skill} 마스터 클래스 - 실무에서 바로 쓰는",
            "provider": "유데미",
            "instructor": "시니어 개발자",
            "type": "course",
            "weeks": 6,
            "free": False,
            "rating": 4.8,
            "students": "15000명+",
            "total_lectures": 25,
            "total_duration": "총 15시간",
            "summary": f"{skill} 분야의 전문 지식을 습득할 수 있는 심화 강좌입니다. 실제 프로젝트를 진행합니다.",
            "reason": f"실무 수준의 {skill} 역량을 키우고 싶은 학습자에게 프로젝트 중심의 심화 학습을 제공합니다.",
            "curriculum": [
                {
                    "section": "섹션 1: 기초 다지기",
                    "lectures": [
                        {"title": "1강: 핵심 개념 복습", "duration": "30분", "description": "기초 개념 빠른 복습"},
                        {"title": "2강: 고급 문법 배우기", "duration": "45분", "description": "심화 문법 학습"}
                    ]
                },
                {
                    "section": "섹션 2: 중급 과정",
                    "lectures": [
                        {"title": "3강: 디자인 패턴 이해", "duration": "50분", "description": "주요 디자인 패턴 학습"},
                        {"title": "4강: 테스트 주도 개발(TDD)", "duration": "55분", "description": "TDD 방법론 실습"},
                        {"title": "5강: 클린 코드 작성법", "duration": "40분", "description": "읽기 좋은 코드 작성하기"}
                    ]
                },
                {
                    "section": "섹션 3: 실전 프로젝트",
                    "lectures": [
                        {"title": "6강: 대규모 프로젝트 설계", "duration": "60분", "description": "프로젝트 아키텍처 설계"},
                        {"title": "7강: 성능 최적화 기법", "duration": "45분", "description": "성능 개선 방법론"},
                        {"title": "8강: 배포 및 유지보수", "duration": "50분", "description": "실제 서비스 배포하기"}
                    ]
                }
            ],
            "link": f"https://www.udemy.com/courses/search/?q={skill}",
            "price": "79000원",
            "level_detail": "중급~고급 수준에 적합"
        },
        {
            "id": str(uuid.uuid4()),
            "title": f"{skill} 무료 부트캠프",
            "provider": "부스트코스",
            "instructor": "네이버 부스트캠프",
            "type": "course",
            "weeks": 5,
            "free": True,
            "rating": 4.6,
            "students": "50000명+",
            "total_lectures": 18,
            "total_duration": "총 40시간",
            "summary": f"네이버에서 제공하는 무료 {skill} 교육 과정입니다. 체계적인 커리큘럼과 수료증을 제공합니다.",
            "reason": f"비용 부담 없이 {skill}을 배우고 싶은 학습자에게 체계적인 무료 교육을 제공합니다.",
            "curriculum": [
                {
                    "section": "Week 1: 기초 학습",
                    "lectures": [
                        {"title": "1강: 오리엔테이션", "duration": "30분", "description": "부트캠프 소개 및 학습 가이드"},
                        {"title": "2강: 기본 개념 이해", "duration": "60분", "description": "핵심 개념 학습"},
                        {"title": "3강: 실습 환경 구성", "duration": "45분", "description": "개발 환경 설정"}
                    ]
                },
                {
                    "section": "Week 2: 심화 학습",
                    "lectures": [
                        {"title": "4강: 핵심 기능 실습 1", "duration": "90분", "description": "주요 기능 직접 구현"},
                        {"title": "5강: 핵심 기능 실습 2", "duration": "90분", "description": "심화 기능 실습"},
                        {"title": "6강: 코드 리뷰 및 피드백", "duration": "60분", "description": "작성 코드 리뷰"}
                    ]
                },
                {
                    "section": "Week 3-4: 프로젝트",
                    "lectures": [
                        {"title": "7강: 팀 프로젝트 기획", "duration": "60분", "description": "프로젝트 주제 선정"},
                        {"title": "8강: 팀 프로젝트 개발", "duration": "180분", "description": "협업 프로젝트 진행"},
                        {"title": "9강: 발표 및 수료", "duration": "60분", "description": "결과물 발표 및 수료"}
                    ]
                }
            ],
            "link": f"https://www.boostcourse.org/search?keyword={skill}",
            "price": "무료",
            "level_detail": f"{level} 수준에 적합"
        }
    ]


@router.post("/select")
async def select_course(request: SelectCourseRequest, current_user: Dict = Depends(get_current_user)):
    log_request("POST /recommend/select", current_user['name'], f"course_id={request.course_id}")
    log_navigation(current_user['name'], "강좌 선택 → 로딩 화면")
    return {"success": True, "message": "강좌가 선택되었습니다."}

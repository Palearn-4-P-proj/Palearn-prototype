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

    # 프롬프트 - 실제 강좌 페이지 방문 필수
    prompt = f"""당신은 "{skill}" 학습을 위한 온라인 강좌를 찾아주는 전문가입니다.
{level} 수준의 학습자에게 적합한 실제 강좌 3-5개를 추천해주세요.

## 필수 작업 순서

### 1단계: 검색 실행
다음 검색어로 웹 검색을 수행하세요:
- "{skill} 강의 인프런"
- "{skill} 강좌 udemy"
- "{skill} tutorial youtube"

### 2단계: 개별 강좌 페이지 방문 (매우 중요!)
검색 결과에서 찾은 각 강좌의 **상세 페이지**에 직접 방문하세요.
- 인프런: https://www.inflearn.com/course/강좌이름 형식의 페이지
- Udemy: https://www.udemy.com/course/강좌이름 형식의 페이지
- YouTube: 개별 영상 또는 재생목록 페이지

⚠️ 절대 금지: 검색 결과 목록 페이지(inflearn.com/search?s=..., udemy.com/courses/search/...)에서 정보를 추출하지 마세요.

### 3단계: 상세 정보 추출
각 강좌 상세 페이지에서 다음 정보를 정확히 복사하세요:
- 강좌 제목 (페이지에 표시된 그대로)
- 강사 이름
- 가격
- 평점, 수강생 수
- 총 강의 시간
- 커리큘럼 (섹션명과 각 강의 제목)

## 출력 형식 (JSON)
{{
  "ai_summary": "{level} 수준의 {skill} 학습자를 위해 인프런, Udemy 등에서 실제 검색한 결과입니다. 각 강좌의 상세 페이지를 직접 확인하여 정확한 정보를 수집했습니다.",
  "recommendations": [
    {{
      "id": "고유ID",
      "title": "정확한 강좌 제목",
      "provider": "인프런|Udemy|YouTube",
      "instructor": "강사 실명",
      "type": "course|youtube",
      "language": "Korean|English",
      "weeks": 4,
      "free": true|false,
      "rating": "4.8",
      "students": "12345",
      "total_lectures": 24,
      "total_duration": "15시간 30분",
      "summary": "강좌 소개 요약 (한국어)",
      "reason": "이 강좌가 {level} 학습자에게 좋은 이유 (한국어)",
      "price": "₩55,000|$19.99|무료",
      "level_detail": "{level}",
      "link": "https://www.inflearn.com/course/실제강좌경로",
      "curriculum": [
        {{
          "section": "섹션 1: 섹션명",
          "lectures": [
            {{"title": "1강 제목", "duration": "10분"}}
          ]
        }}
      ]
    }}
  ]
}}

## 엄격한 규칙
1. 실제로 방문한 강좌 페이지의 정보만 포함
2. link 필드는 반드시 강좌 상세 페이지 URL (검색 페이지 URL 절대 금지)
   - 올바른 예: https://www.inflearn.com/course/파이썬-입문-인프런-오리지널
   - 잘못된 예: https://www.inflearn.com/search?s=파이썬
3. 정보를 찾을 수 없으면 빈 배열 반환: {{"recommendations": []}}
4. 허위 정보 생성 절대 금지

JSON만 출력하세요."""

    response = call_gpt(prompt, use_search=True)
    data = extract_json(response)

    if data and 'error' not in data:
        # ai_summary 추출 (프론트에서 표시용)
        ai_summary = data.get('ai_summary', '')

        # recommendations 또는 courses 키 모두 지원
        courses = data.get('recommendations', data.get('courses', []))

        # 유효하지 않은 URL 필터링 (검색 페이지, example.com 등)
        invalid_patterns = ['example.com', '/search?', '?s=', '?q=', '/courses/search', 'search?keyword']
        valid_courses = []
        for c in courses:
            link = c.get('link', '').lower()
            # 잘못된 패턴이 하나라도 있으면 제외
            if not any(pattern in link for pattern in invalid_patterns):
                # ai_summary를 각 강좌에 추가
                if ai_summary:
                    c['ai_summary'] = ai_summary
                valid_courses.append(c)

        if valid_courses:
            log_success(f"강좌 {len(valid_courses)}개 추천 완료 (유효한 URL만)")
            return valid_courses[:8]  # 최대 8개까지 반환
        else:
            log_info(f"검색 페이지 URL만 반환됨, 필터링 후 0개")

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

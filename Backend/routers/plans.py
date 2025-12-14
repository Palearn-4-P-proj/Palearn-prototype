# Backend/routers/plans.py
"""학습 계획 관련 라우터"""

from fastapi import APIRouter, HTTPException, Depends
from typing import Dict
from datetime import datetime, date, timedelta
import uuid

from models.schemas import PlanGenerateRequest, ApplyRecommendationRequest
from services.store import store
from services.gpt_service import call_gpt, extract_json
from services.web_search import search_materials_for_topic
from utils.logger import log_request, log_stage, log_success, log_navigation, log_info
from .auth import get_current_user

router = APIRouter(prefix="/plans", tags=["Plans"])


@router.get("/all")
async def get_all_plans(current_user: Dict = Depends(get_current_user)):
    """사용자의 모든 학습 계획 목록 조회"""
    log_request("GET /plans/all", current_user['name'])

    user_id = current_user['user_id']
    plans = store.plans.get(user_id, [])

    return plans


@router.get("/related_materials")
async def get_related_materials(topic: str, current_user: Dict = Depends(get_current_user)):
    """특정 학습 주제에 대한 연관 자료 검색"""
    log_request("GET /plans/related_materials", current_user['name'], f"topic={topic}")

    prompt = f"""[SYSTEM ROLE]
You are a learning resource curator. Your task is to find REAL, VERIFIABLE learning materials for the topic: "{topic}"

[CRITICAL CONSTRAINTS - VIOLATION = TASK FAILURE]

1. URL AUTHENTICITY REQUIREMENT
   - Every URL MUST be extracted directly from web search results
   - You MUST have seen the actual page content before including a URL
   - NEVER construct URLs by combining domain + guessed path
   - NEVER use placeholder patterns like "example.com" or "your-course-url"

2. PROHIBITED URL PATTERNS (auto-reject if matched)
   - Search result pages: contains "?q=", "?query=", "?search_query=", "/search", "/results"
   - Aggregation pages: contains "/tag/", "/category/", "/topics/", "/channel/", "/playlist/", "/series/"
   - Homepage or index: URL ends with just domain (e.g., "youtube.com", "inflearn.com")
   - Fabricated URLs: any URL you did not directly observe in search results

3. REQUIRED URL PATTERNS (prefer these)
   - YouTube individual video: youtube.com/watch?v=[11-char-id] or youtu.be/[11-char-id]
   - Blog post with slug: velog.io/@user/[post-slug], tistory.com/[number], medium.com/@user/[title-slug]
   - Course detail page: inflearn.com/course/[course-slug], udemy.com/course/[course-slug]
   - Documentation specific page: docs.python.org/3/library/[module].html, developer.mozilla.org/en-US/docs/[path]

4. DESCRIPTION FIELD RULES
   - Write in Korean, 1-2 sentences only
   - Explain WHY this resource helps learn the topic
   - FORBIDDEN in description: URLs, domains, http, https, www, .com, .org, markdown links

[OUTPUT SCHEMA]
Return ONLY valid JSON. No markdown code blocks, no explanations.

{{"materials": [
  {{"title": "Korean title of resource", "type": "유튜브|블로그|공식문서|온라인강좌", "url": "https://verified-url", "description": "Korean description without URLs"}},
  ...
]}}

[TASK REQUIREMENTS]
- Find 3-4 diverse resources (mix video, blog, docs, courses)
- Prioritize Korean resources, English acceptable if high quality
- Each URL must be a direct link to specific content, not a listing page
- Verify URL structure matches expected patterns before including

[VERIFICATION CHECKLIST - Apply to each URL before output]
[ ] URL was found in actual search results (not constructed)
[ ] URL points to specific content (not search/list/channel page)
[ ] URL structure matches known valid patterns
[ ] Title accurately reflects the linked content

Now search and return verified materials for: "{topic}"
"""

    response = call_gpt(prompt, use_search=True)
    data = extract_json(response)

    if data and 'materials' in data:
        valid_materials = [m for m in data['materials'] if 'example' not in m.get('url', '').lower()]
        if valid_materials:
            log_success(f"연관 자료 {len(valid_materials)}개 찾기 완료")
            return {"materials": valid_materials[:4]}

    # 기본 검색 링크
    search_query = topic.replace(' ', '+')
    log_info("GPT 응답 실패, 기본 검색 링크 반환")
    return {
        "materials": [
            {"title": f"{topic} - 유튜브 검색", "type": "유튜브", "url": f"https://www.youtube.com/results?search_query={search_query}", "description": "유튜브에서 관련 영상을 검색합니다."},
            {"title": f"{topic} - 구글 검색", "type": "기타", "url": f"https://www.google.com/search?q={search_query}+강의", "description": "구글에서 관련 강의를 검색합니다."},
        ]
    }


@router.get("")
async def get_plans(scope: str = "daily", current_user: Dict = Depends(get_current_user)):
    log_request("GET /plans", current_user['name'], f"scope={scope}")

    user_id = current_user['user_id']
    plans = store.plans.get(user_id, [])

    if not plans:
        return []

    current_plan = plans[-1]
    today = date.today()
    result = []

    if 'daily_schedule' in current_plan:
        for day in current_plan['daily_schedule']:
            day_date = datetime.strptime(day['date'], '%Y-%m-%d').date()

            if scope == "daily" and day_date == today:
                result.extend([task['title'] for task in day['tasks']])
            elif scope == "weekly":
                week_start = today - timedelta(days=today.weekday())
                week_end = week_start + timedelta(days=6)
                if week_start <= day_date <= week_end:
                    result.extend([task['title'] for task in day['tasks']])
            elif scope == "monthly":
                if day_date.year == today.year and day_date.month == today.month:
                    result.extend([task['title'] for task in day['tasks']])

    return result


@router.get("/review")
async def get_review_plans(current_user: Dict = Depends(get_current_user)):
    user_id = current_user['user_id']
    plans = store.plans.get(user_id, [])

    if not plans:
        return []

    current_plan = plans[-1]
    yesterday = (date.today() - timedelta(days=1)).isoformat()

    result = []
    if 'daily_schedule' in current_plan:
        for day in current_plan['daily_schedule']:
            if day['date'] == yesterday:
                for task in day['tasks']:
                    if task.get('completed', False):
                        result.append({"title": task['title'], "id": task.get('id', str(uuid.uuid4()))})

    return result


@router.get("/yesterday_review")
async def get_yesterday_review(current_user: Dict = Depends(get_current_user)):
    """어제 학습 내용 기반 복습 자료 반환 (유튜브 1개 + 블로그 1개)"""
    log_request("GET /plans/yesterday_review", current_user['name'])

    user_id = current_user['user_id']
    plans = store.plans.get(user_id, [])

    if not plans:
        return {"has_review": False, "materials": [], "yesterday_topic": ""}

    current_plan = plans[-1]
    yesterday = (date.today() - timedelta(days=1)).isoformat()

    # 어제 학습한 내용 찾기
    yesterday_topics = []
    if 'daily_schedule' in current_plan:
        for day in current_plan['daily_schedule']:
            if day['date'] == yesterday:
                for task in day['tasks']:
                    yesterday_topics.append(task.get('title', ''))

    if not yesterday_topics:
        return {"has_review": False, "materials": [], "yesterday_topic": ""}

    # 첫 번째 토픽으로 복습 자료 검색
    topic = yesterday_topics[0]

    # 태스크에 미리 저장된 복습 자료가 있는지 확인
    for day in current_plan.get('daily_schedule', []):
        if day['date'] == yesterday:
            for task in day['tasks']:
                if task.get('review_materials'):
                    return {
                        "has_review": True,
                        "materials": task['review_materials'][:2],  # 유튜브 1 + 블로그 1
                        "yesterday_topic": topic
                    }

    # 없으면 기본 검색 링크 반환
    search_query = topic.replace(' ', '+')
    return {
        "has_review": True,
        "materials": [
            {"title": f"{topic} 복습 영상", "type": "유튜브", "url": f"https://www.youtube.com/results?search_query={search_query}+강의"},
            {"title": f"{topic} 복습 글", "type": "블로그", "url": f"https://www.google.com/search?q={search_query}+블로그"}
        ],
        "yesterday_topic": topic
    }


def _get_materials_for_task(topic: str) -> dict:
    """태스크에 대한 학습 자료 검색 (웹 검색 API 사용)"""
    try:
        return search_materials_for_topic(topic)
    except Exception as e:
        log_info(f"웹 검색 실패, 기본 URL 사용: {e}")
        # 실패 시 기본 검색 URL
        from urllib.parse import quote_plus
        search_query = quote_plus(topic)
        default_materials = [
            {"title": f"{topic} 강의 영상", "type": "유튜브", "url": f"https://www.youtube.com/results?search_query={search_query}+강의", "description": "유튜브에서 검색"},
            {"title": f"{topic} 블로그 글", "type": "블로그", "url": f"https://www.google.com/search?q={search_query}+블로그", "description": "구글에서 검색"},
        ]
        return {
            "related_materials": default_materials,
            "review_materials": default_materials
        }


@router.post("/generate")
async def generate_plan(request: PlanGenerateRequest, current_user: Dict = Depends(get_current_user)):
    log_request("POST /plans/generate", current_user['name'], f"skill={request.skill}")
    log_stage(7, "계획 생성", current_user['name'])

    user_id = current_user['user_id']

    # 쉬는 요일 처리 - 프론트에서 '월', '화' 형식으로 오므로 그대로 사용
    rest_days_str = ', '.join(request.restDays) if request.restDays else '없음'
    rest_days_list = request.restDays if request.restDays else []

    prompt = f"""[SYSTEM ROLE]
You are a personalized learning planner. Generate a 4-week (28-day) study schedule.

[INPUT PARAMETERS]
- Skill: "{request.skill}"
- Daily study time: {request.hourPerDay} hours
- Start date: {request.startDate}
- Rest days: {rest_days_str}
- Learner level: {request.selfLevel}

[REST DAY EXCLUSION - CRITICAL]
Rest days to EXCLUDE: {rest_days_str}

Day mapping (Korean to weekday):
- 월 = Monday (weekday 0)
- 화 = Tuesday (weekday 1)
- 수 = Wednesday (weekday 2)
- 목 = Thursday (weekday 3)
- 금 = Friday (weekday 4)
- 토 = Saturday (weekday 5)
- 일 = Sunday (weekday 6)

RULE: If a date falls on any rest day listed above, that date MUST NOT appear in daily_schedule.
Example: If rest days = "월, 수, 금", only include dates that fall on 화, 목, 토, 일.

[TASK GENERATION RULES]

1. TASKS PER DAY: Exactly 2 tasks per day (no more, no less)

2. DURATION VALUES: Use only these exact strings
   - "30분" (30 minutes)
   - "1시간" (1 hour)
   Combined duration should approximate {request.hourPerDay} hours per day.

3. TASK TITLE REQUIREMENTS
   - Must be specific to "{request.skill}"
   - Include concrete learning objectives (e.g., "Python 리스트 컴프리헨션 학습" not "파이썬 공부")
   - Progress logically through the curriculum
   - Written in Korean

4. TASK DESCRIPTION
   - Exactly 1 sentence in Korean
   - Describe the learning activity concisely
   - No creative expressions, metaphors, or emotional language

[CURRICULUM PROGRESSION]
Week 1 (Days 1-7): Foundation - Core concepts, basic terminology, fundamental principles
Week 2 (Days 8-14): Practice - Hands-on exercises, basic implementations, simple examples
Week 3 (Days 15-21): Application - Advanced topics, real-world scenarios, problem-solving
Week 4 (Days 22-28): Consolidation - Review, mini-project, integration of learned concepts

Adjust depth based on learner level: {request.selfLevel}
- 초급: Focus more on basics, slower progression
- 중급: Balance theory and practice
- 고급: Emphasize advanced patterns and optimization

[DATE RULES]
- Start from: {request.startDate}
- Total span: 28 calendar days
- Dates in ascending order (YYYY-MM-DD format)
- No duplicate dates
- Skip all rest days

[OUTPUT SCHEMA - STRICT]
{{"plan_name": "Korean plan name including {request.skill}",
  "total_duration": "4주",
  "daily_schedule": [
    {{"date": "YYYY-MM-DD",
      "tasks": [
        {{"id": "unique-string-id", "title": "Korean task title", "description": "Korean 1-sentence description", "duration": "30분", "completed": false}},
        {{"id": "unique-string-id", "title": "Korean task title", "description": "Korean 1-sentence description", "duration": "1시간", "completed": false}}
      ]
    }},
    ...
  ]
}}

[VALIDATION CHECKLIST]
- [ ] All dates are within 28-day range from start
- [ ] No rest day dates included
- [ ] Exactly 2 tasks per day
- [ ] All task IDs are unique strings
- [ ] All durations are "30분" or "1시간"
- [ ] Dates are sorted ascending
- [ ] No duplicate dates

Output ONLY the JSON object. No markdown, no explanations."""

    response = call_gpt(prompt, use_search=False)
    data = extract_json(response)

    if data and 'daily_schedule' in data:
        # GPT 응답에서 쉬는 요일 필터링 (한번 더 확인)
        day_names = ['월', '화', '수', '목', '금', '토', '일']
        filtered_schedule = []
        for day in data['daily_schedule']:
            try:
                day_date = datetime.strptime(day['date'], '%Y-%m-%d').date()
                day_name = day_names[day_date.weekday()]
                if day_name not in rest_days_list:
                    filtered_schedule.append(day)
            except:
                filtered_schedule.append(day)  # 날짜 파싱 실패시 일단 포함
        data['daily_schedule'] = filtered_schedule
        log_info("학습 자료 검색 시작...")
        for day in data['daily_schedule']:
            for task in day['tasks']:
                if 'id' not in task:
                    task['id'] = str(uuid.uuid4())
                if 'completed' not in task:
                    task['completed'] = False
                # 각 태스크에 연관 자료 미리 추가 (웹 검색 API 사용)
                if 'related_materials' not in task or 'review_materials' not in task:
                    materials = _get_materials_for_task(task.get('title', request.skill))
                    task['related_materials'] = materials.get('related_materials', [])
                    task['review_materials'] = materials.get('review_materials', [])

        store.plans[user_id].append(data)
        log_success(f"학습 계획 생성 완료: {data.get('plan_name', 'Unknown')}")
        log_navigation(current_user['name'], "퀴즈 화면")
        return data

    # 기본 계획 생성
    start = datetime.strptime(request.startDate.split('T')[0], '%Y-%m-%d').date()
    schedule = []
    day_names = ['월', '화', '수', '목', '금', '토', '일']

    for i in range(28):
        current_date = start + timedelta(days=i)
        day_name = day_names[current_date.weekday()]

        if day_name in request.restDays:
            continue

        task_title = f"{request.skill} 학습 Day {len(schedule) + 1}"
        materials = _get_materials_for_task(task_title)
        schedule.append({
            "date": current_date.isoformat(),
            "tasks": [
                {
                    "id": str(uuid.uuid4()),
                    "title": task_title,
                    "description": f"{request.skill} 학습을 진행합니다.",
                    "duration": f"{request.hourPerDay}시간",
                    "completed": False,
                    "related_materials": materials.get('related_materials', []),
                    "review_materials": materials.get('review_materials', [])
                }
            ]
        })

    plan = {
        "plan_name": f"{request.skill} 학습 계획",
        "total_duration": "4주",
        "daily_schedule": schedule
    }

    store.plans[user_id].append(plan)
    log_success(f"기본 학습 계획 생성 완료")
    return plan


@router.get("/date/{target_date}")
async def get_plans_by_date(
    target_date: str,
    current_user: Dict = Depends(get_current_user)
):
    """특정 날짜의 상세 계획 조회"""
    log_request("GET /plans/date", current_user['name'], f"date={target_date}")

    user_id = current_user['user_id']
    plans = store.plans.get(user_id, [])

    if not plans:
        return {"date": target_date, "tasks": [], "message": "아직 학습 계획이 없습니다."}

    current_plan = plans[-1]

    for day in current_plan.get('daily_schedule', []):
        if day['date'] == target_date:
            return {
                "date": target_date,
                "tasks": day['tasks'],
                "plan_name": current_plan.get('plan_name', '학습 계획'),
                "message": None
            }

    return {"date": target_date, "tasks": [], "message": "해당 날짜에 계획이 없습니다."}


@router.post("/task/update")
async def update_task(
    date: str,
    task_id: str,
    completed: bool,
    current_user: Dict = Depends(get_current_user)
):
    user_id = current_user['user_id']

    # store의 update_task를 사용하여 DB에 영구 저장
    success = store.update_task(user_id, date, task_id, completed)

    if success:
        # 메모리 캐시도 무효화 (다음 조회 시 DB에서 다시 로드)
        if hasattr(store.plans, '_cache') and user_id in store.plans._cache:
            del store.plans._cache[user_id]

        log_success(f"태스크 업데이트: {task_id} → {'완료' if completed else '미완료'}")
        return {"success": True}

    raise HTTPException(status_code=404, detail="Task not found")

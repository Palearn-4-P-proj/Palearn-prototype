# Backend/routers/plan_apply.py
"""계획 적용 관련 라우터 - 강좌 커리큘럼 기반 학습 계획 생성"""

from fastapi import APIRouter, Depends
from typing import Dict, List
from datetime import datetime, timedelta
import uuid

from models.schemas import ApplyRecommendationRequest
from services.store import store
from services.gpt_service import call_gpt, extract_json
from services.web_search import search_materials_for_topic
from utils.logger import log_request, log_success, log_error, log_navigation, log_info
from .auth import get_current_user

router = APIRouter(prefix="/plan", tags=["Plan"])


def _get_materials_for_task(topic: str) -> dict:
    """태스크에 대한 학습 자료 검색"""
    try:
        return search_materials_for_topic(topic)
    except Exception as e:
        log_info(f"웹 검색 실패, 기본 URL 사용: {e}")
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


def _flatten_curriculum(curriculum) -> List[Dict]:
    """커리큘럼을 평탄화하여 모든 강의 목록 추출"""
    all_lessons = []

    if not curriculum:
        return all_lessons

    for item in curriculum:
        # 새로운 형식: {"section": "...", "lectures": [...]}
        if isinstance(item, dict) and 'section' in item and 'lectures' in item:
            section_name = item['section']
            for lecture in item['lectures']:
                if isinstance(lecture, dict):
                    all_lessons.append({
                        "section": section_name,
                        "title": lecture.get('title', ''),
                        "duration": lecture.get('duration', ''),
                        "description": lecture.get('description', '')
                    })
                else:
                    all_lessons.append({
                        "section": section_name,
                        "title": str(lecture),
                        "duration": "",
                        "description": ""
                    })
        # 기존 형식: 문자열 리스트
        elif isinstance(item, str):
            all_lessons.append({
                "section": "기본",
                "title": item,
                "duration": "",
                "description": ""
            })

    return all_lessons


def _create_plan_with_gpt(
    course: Dict,
    skill: str,
    hour_per_day: float,
    start_date: str,
    rest_days: List[str],
    level: str
) -> Dict:
    """GPT를 사용하여 커리큘럼 기반 학습 계획 생성"""

    course_title = course.get('title', '학습 강좌')
    curriculum = course.get('curriculum', course.get('syllabus', []))
    total_lectures = course.get('total_lectures', len(_flatten_curriculum(curriculum)))
    total_duration = course.get('total_duration', '')

    # 커리큘럼 정보를 문자열로 변환
    curriculum_str = ""
    for item in curriculum:
        if isinstance(item, dict) and 'section' in item:
            curriculum_str += f"\n[{item['section']}]\n"
            for lecture in item.get('lectures', []):
                if isinstance(lecture, dict):
                    curriculum_str += f"  - {lecture.get('title', '')} ({lecture.get('duration', '')}) : {lecture.get('description', '')}\n"
                else:
                    curriculum_str += f"  - {lecture}\n"
        else:
            curriculum_str += f"  - {item}\n"

    if not curriculum_str.strip():
        curriculum_str = f"{skill} 기초부터 심화까지"

    log_info(f"GPT로 학습 계획 생성 시작: {course_title}")

    prompt = f"""[시스템 지시] 학습 계획 생성 API입니다. 반드시 JSON만 출력하세요.

선택된 강좌 정보를 바탕으로 최적의 학습 계획을 만들어주세요.

📚 강좌 정보:
- 강좌명: {course_title}
- 총 강의 수: {total_lectures}개
- 총 학습 시간: {total_duration}
- 학습 분야: {skill}
- 학습자 수준: {level}

📋 커리큘럼:
{curriculum_str}

⏰ 학습 조건:
- 시작 날짜: {start_date.split('T')[0]}
- 하루 학습 시간: {hour_per_day}시간
- 쉬는 요일: {', '.join(rest_days) if rest_days else '없음'}

🎯 계획 생성 규칙 (매우 중요!):
1. 학습자 수준({level})에 맞게 난이도 조절
2. ⭐ 하루에 반드시 2~5개의 다양한 태스크를 포함할 것! (절대 1개만 넣지 말 것)
3. ⭐ 매일 다양한 유형의 학습 활동을 포함:
   - 📹 강의 시청: 메인 강의 내용
   - 💻 실습/코딩 연습: 배운 내용을 직접 실습 (코드 작성, 예제 풀이 등)
   - 📝 복습/정리: 이전 내용 복습, 노트 정리
   - 🎬 유튜브 추천: 해당 주제 관련 유튜브 영상 시청 (필요시)
   - 📖 추가 학습: 공식 문서, 블로그 글 읽기 (심화 학습)
   - 🎯 미니 프로젝트/퀴즈: 작은 과제나 퀴즈로 이해도 확인
4. 하루 {hour_per_day}시간에 맞게 시간 분배 (각 태스크에 적절한 시간 배분)
5. 관련 강의들은 같은 날에 연속 배치
6. 최대 4주(28일) 내에 완료되도록 설계
7. 쉬는 요일({', '.join(rest_days) if rest_days else '없음'})은 제외
8. task_type 필드로 태스크 유형 명시: "lecture", "practice", "review", "youtube", "reading", "quiz"

예시 하루 일정:
- 태스크1: 파이썬 기초 변수 강의 시청 (30분) - type: "lecture"
- 태스크2: 변수 선언 실습 코딩 (20분) - type: "practice"
- 태스크3: 유튜브 '파이썬 변수 쉽게 설명' 영상 (15분) - type: "youtube"
- 태스크4: 변수 관련 퀴즈 풀기 (10분) - type: "quiz"

반드시 아래 JSON 형식으로만 응답:
```json
{{
  "plan_name": "{course_title} 학습 계획",
  "total_duration": "N주",
  "daily_schedule": [
    {{
      "date": "YYYY-MM-DD",
      "tasks": [
        {{
          "id": "uuid형식",
          "title": "강의 제목 또는 학습 내용",
          "description": "해당 학습의 목표와 내용 설명",
          "duration": "예상 학습 시간 (예: 30분, 1시간)",
          "completed": false,
          "section": "섹션명",
          "task_type": "lecture/practice/review/youtube/reading/quiz 중 하나"
        }}
      ]
    }}
  ]
}}
```

⚠️ 중요: 반드시 하루에 2~5개의 태스크를 포함해야 합니다! 1개만 있으면 안 됩니다!

지금 바로 JSON을 출력하세요:"""

    response = call_gpt(prompt, use_search=False)
    data = extract_json(response)

    if data and 'daily_schedule' in data:
        log_success("GPT 학습 계획 생성 성공")
        # 각 태스크에 UUID와 학습 자료 추가
        for day in data['daily_schedule']:
            for task in day['tasks']:
                if 'id' not in task or not task['id'].startswith('uuid'):
                    task['id'] = str(uuid.uuid4())
                if 'completed' not in task:
                    task['completed'] = False
                # 학습 자료 검색
                search_topic = f"{skill} {task.get('title', '')}"
                materials = _get_materials_for_task(search_topic)
                task['related_materials'] = materials.get('related_materials', [])
                task['review_materials'] = materials.get('review_materials', [])

        # 강좌 정보 추가
        data['course_info'] = {
            "title": course_title,
            "provider": course.get('provider', ''),
            "link": course.get('link', ''),
            "total_lectures": total_lectures
        }
        return data

    log_info("GPT 응답 파싱 실패, 기본 계획 생성")
    return None


def _create_plan_from_curriculum(
    course: Dict,
    skill: str,
    hour_per_day: float,
    start_date: str,
    rest_days: List[str],
    level: str
) -> Dict:
    """커리큘럼을 기반으로 학습 계획 생성 (폴백용) - 하루 2~5개 태스크 포함"""

    course_title = course.get('title', '학습 강좌')
    curriculum = course.get('curriculum', course.get('syllabus', []))

    # 커리큘럼 평탄화
    all_lessons = _flatten_curriculum(curriculum)

    if not all_lessons:
        all_lessons = [
            {"section": "기초", "title": f"{skill} 기초 학습", "duration": "", "description": ""},
            {"section": "기초", "title": f"{skill} 기초 실습", "duration": "", "description": ""},
            {"section": "심화", "title": f"{skill} 심화 학습", "duration": "", "description": ""},
            {"section": "심화", "title": f"{skill} 심화 실습", "duration": "", "description": ""},
            {"section": "실습", "title": f"{skill} 프로젝트", "duration": "", "description": ""}
        ]

    # 날짜 계산
    try:
        start = datetime.strptime(start_date.split('T')[0], '%Y-%m-%d').date()
    except:
        start = datetime.now().date()

    day_names = ['월', '화', '수', '목', '금', '토', '일']
    schedule = []
    current_date = start
    lesson_index = 0

    # 하루에 배정할 메인 강의 수 (최소 1개)
    main_lessons_per_day = max(1, int(hour_per_day) // 2)

    # 최대 4주(28일) 동안 배정
    max_days = 28
    days_count = 0

    # 태스크 타입별 시간 분배 템플릿
    def _get_task_time(task_type: str, hour_per_day: float) -> str:
        if task_type == "lecture":
            return f"{int(hour_per_day * 60 * 0.35)}분"  # 35%
        elif task_type == "practice":
            return f"{int(hour_per_day * 60 * 0.25)}분"  # 25%
        elif task_type == "review":
            return f"{int(hour_per_day * 60 * 0.15)}분"  # 15%
        elif task_type == "youtube":
            return f"{int(hour_per_day * 60 * 0.15)}분"  # 15%
        elif task_type == "quiz":
            return f"{int(hour_per_day * 60 * 0.10)}분"  # 10%
        return "30분"

    while lesson_index < len(all_lessons) and days_count < max_days:
        day_name = day_names[current_date.weekday()]

        # 쉬는 날 건너뛰기
        if day_name in rest_days:
            current_date += timedelta(days=1)
            continue

        # 해당 날짜의 태스크 생성 (2~5개)
        day_tasks = []

        # 메인 강의 태스크 추가
        for _ in range(main_lessons_per_day):
            if lesson_index >= len(all_lessons):
                break

            lesson_data = all_lessons[lesson_index]
            lesson_title = lesson_data["title"]
            section_name = lesson_data["section"]
            description = lesson_data.get("description", "")

            # 학습 자료 검색
            search_topic = f"{skill} {lesson_title}"
            materials = _get_materials_for_task(search_topic)

            # 1. 메인 강의 태스크
            day_tasks.append({
                "id": str(uuid.uuid4()),
                "title": f"📹 {lesson_title}",
                "description": f"[{section_name}] {description}" if description else f"[{section_name}] {lesson_title} 강의 시청",
                "duration": _get_task_time("lecture", hour_per_day),
                "completed": False,
                "section": section_name,
                "task_type": "lecture",
                "related_materials": materials.get('related_materials', []),
                "review_materials": materials.get('review_materials', [])
            })

            # 2. 실습 태스크 추가
            day_tasks.append({
                "id": str(uuid.uuid4()),
                "title": f"💻 {lesson_title} 실습",
                "description": f"배운 내용을 직접 코드로 작성해보기",
                "duration": _get_task_time("practice", hour_per_day),
                "completed": False,
                "section": section_name,
                "task_type": "practice",
                "related_materials": [],
                "review_materials": []
            })

            lesson_index += 1

        # 3. 유튜브 추천 태스크 (격일로)
        if days_count % 2 == 0 and day_tasks:
            first_lesson = day_tasks[0]["title"].replace("📹 ", "")
            day_tasks.append({
                "id": str(uuid.uuid4()),
                "title": f"🎬 {skill} {first_lesson} 관련 유튜브 영상",
                "description": "관련 유튜브 영상을 찾아 추가 학습하기",
                "duration": _get_task_time("youtube", hour_per_day),
                "completed": False,
                "section": "추가학습",
                "task_type": "youtube",
                "related_materials": [],
                "review_materials": []
            })

        # 4. 복습 태스크 (3일마다)
        if days_count > 0 and days_count % 3 == 0:
            day_tasks.append({
                "id": str(uuid.uuid4()),
                "title": f"📝 이전 학습 내용 복습",
                "description": "지금까지 배운 내용을 정리하고 복습하기",
                "duration": _get_task_time("review", hour_per_day),
                "completed": False,
                "section": "복습",
                "task_type": "review",
                "related_materials": [],
                "review_materials": []
            })

        # 5. 퀴즈/미니 프로젝트 (4일마다)
        if days_count > 0 and days_count % 4 == 0:
            day_tasks.append({
                "id": str(uuid.uuid4()),
                "title": f"🎯 {skill} 미니 퀴즈",
                "description": "학습한 내용에 대한 이해도 확인 퀴즈",
                "duration": _get_task_time("quiz", hour_per_day),
                "completed": False,
                "section": "평가",
                "task_type": "quiz",
                "related_materials": [],
                "review_materials": []
            })

        if day_tasks:
            schedule.append({
                "date": current_date.isoformat(),
                "tasks": day_tasks
            })

        current_date += timedelta(days=1)
        days_count += 1

    # 계획 기간 계산
    if schedule:
        total_days = (datetime.fromisoformat(schedule[-1]["date"]) - datetime.fromisoformat(schedule[0]["date"])).days + 1
        weeks = (total_days + 6) // 7
        duration_str = f"{weeks}주"
    else:
        duration_str = "1주"

    return {
        "plan_name": f"{course_title} 학습 계획",
        "total_duration": duration_str,
        "course_info": {
            "title": course_title,
            "provider": course.get('provider', ''),
            "link": course.get('link', ''),
            "total_lessons": len(all_lessons)
        },
        "daily_schedule": schedule
    }


@router.post("/apply_recommendation")
async def apply_recommendation(request: ApplyRecommendationRequest, current_user: Dict = Depends(get_current_user)):
    """선택한 강좌의 커리큘럼을 기반으로 GPT가 학습 계획 생성"""
    log_request("POST /plan/apply_recommendation", current_user['name'])

    user_id = current_user['user_id']
    course = request.selected_course

    log_info(f"선택 강좌: {course.get('title', 'Unknown')}")
    curriculum = course.get('curriculum', course.get('syllabus', []))
    log_info(f"커리큘럼 항목 수: {len(curriculum)}")

    # 1차: GPT로 학습 계획 생성 (우선)
    log_info("GPT로 학습 계획 생성 시도...")
    plan = _create_plan_with_gpt(
        course=course,
        skill=request.skill,
        hour_per_day=request.hourPerDay,
        start_date=request.startDate,
        rest_days=request.restDays,
        level=request.quiz_level
    )

    if plan and plan.get('daily_schedule'):
        store.plans[user_id].append(plan)
        log_success(f"GPT 기반 계획 생성 완료: {plan.get('plan_name')}")
        log_info(f"총 {len(plan['daily_schedule'])}일, {sum(len(d['tasks']) for d in plan['daily_schedule'])}개 태스크")
        log_navigation(current_user['name'], "홈 화면")
        return {"success": True, "plan": plan}

    # 2차: 폴백 - 커리큘럼 기반 단순 배치
    log_info("GPT 계획 생성 실패, 커리큘럼 기반 단순 배치로 폴백")
    plan = _create_plan_from_curriculum(
        course=course,
        skill=request.skill,
        hour_per_day=request.hourPerDay,
        start_date=request.startDate,
        rest_days=request.restDays,
        level=request.quiz_level
    )

    if plan and plan.get('daily_schedule'):
        store.plans[user_id].append(plan)
        log_success(f"커리큘럼 기반 계획 생성 완료: {plan.get('plan_name')}")
        log_info(f"총 {len(plan['daily_schedule'])}일, {sum(len(d['tasks']) for d in plan['daily_schedule'])}개 태스크")
        log_navigation(current_user['name'], "홈 화면")
        return {"success": True, "plan": plan}

    # 3차: 최종 폴백 - GPT 프롬프트로 생성
    log_info("커리큘럼 없음, GPT 프롬프트로 계획 생성 시도")
    curriculum = course.get('curriculum', course.get('syllabus', []))

    prompt = f"""
선택된 강좌를 바탕으로 학습 계획을 만들어주세요.

조건:
- 강좌명: {course.get('title', 'Unknown')}
- 커리큘럼: {curriculum if curriculum else '정보 없음'}
- 스킬: {request.skill}
- 하루 공부 시간: {request.hourPerDay}시간
- 시작 날짜: {request.startDate}
- 쉬는 요일: {', '.join(request.restDays) if request.restDays else '없음'}
- 학습자 수준: {request.quiz_level}

⭐ 중요 규칙:
1. 하루에 반드시 2~5개의 다양한 태스크 포함! (1개만 넣지 말 것)
2. 다양한 학습 유형을 섞어서:
   - 강의 시청 (lecture)
   - 실습/코딩 연습 (practice)
   - 복습/정리 (review)
   - 유튜브 영상 시청 (youtube)
   - 추가 읽기 자료 (reading)
   - 퀴즈/미니 프로젝트 (quiz)
3. 하루 {request.hourPerDay}시간에 맞게 각 태스크 시간 분배

반드시 아래 JSON 형식으로만 응답해주세요:
```json
{{
  "plan_name": "계획 이름",
  "total_duration": "N주",
  "daily_schedule": [
    {{
      "date": "YYYY-MM-DD",
      "tasks": [
        {{
          "id": "uuid",
          "title": "학습 내용",
          "description": "설명",
          "duration": "시간",
          "completed": false,
          "task_type": "lecture/practice/review/youtube/reading/quiz"
        }}
      ]
    }}
  ]
}}
```
"""

    response = call_gpt(prompt, use_search=False)
    data = extract_json(response)

    if data and 'daily_schedule' in data:
        for day in data['daily_schedule']:
            for task in day['tasks']:
                if 'id' not in task:
                    task['id'] = str(uuid.uuid4())
                if 'completed' not in task:
                    task['completed'] = False
                # 학습 자료 추가
                materials = _get_materials_for_task(task.get('title', request.skill))
                task['related_materials'] = materials.get('related_materials', [])
                task['review_materials'] = materials.get('review_materials', [])

        store.plans[user_id].append(data)
        log_success("GPT 기반 계획 생성 완료")
        log_navigation(current_user['name'], "홈 화면")
        return {"success": True, "plan": data}

    log_error("계획 생성 실패")
    return {"success": False, "message": "계획 생성에 실패했습니다."}

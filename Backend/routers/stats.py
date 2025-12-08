# Backend/routers/stats.py
"""학습 통계 라우터"""

from fastapi import APIRouter, Depends
from typing import Dict
from datetime import datetime, timedelta

from services.store import store
from utils.logger import log_request, log_stage
from .auth import get_current_user

router = APIRouter(prefix="/stats", tags=["Statistics"])


@router.get("/summary")
async def get_stats_summary(current_user: Dict = Depends(get_current_user)):
    """학습 통계 요약 조회"""
    log_request("GET /stats/summary", current_user['name'])
    log_stage(9, "통계 조회", current_user['name'])

    user_id = current_user['user_id']
    plans = store.get_plans(user_id)

    # 통계 계산
    total_tasks = 0
    completed_tasks = 0
    total_study_days = 0
    streak_days = 0

    # 일별 완료율 (최근 7일)
    daily_progress = []
    today = datetime.now().date()

    # 주제별 학습 시간
    topics = {}

    for plan in plans:
        schedule = plan.get('daily_schedule', [])
        for day in schedule:
            day_date = day.get('date', '')
            tasks = day.get('tasks', [])

            # 전체 태스크 수
            total_tasks += len(tasks)
            day_completed = sum(1 for t in tasks if t.get('completed', False))
            completed_tasks += day_completed

            if tasks:
                total_study_days += 1

            # 주제별 학습 시간 집계
            plan_name = plan.get('plan_name', '기타')
            if plan_name not in topics:
                topics[plan_name] = {'total': 0, 'completed': 0}
            topics[plan_name]['total'] += len(tasks)
            topics[plan_name]['completed'] += day_completed

    # 최근 7일 일별 진행률
    for i in range(6, -1, -1):
        target_date = (today - timedelta(days=i)).isoformat()
        day_tasks = 0
        day_completed = 0

        for plan in plans:
            for day in plan.get('daily_schedule', []):
                if day.get('date') == target_date:
                    tasks = day.get('tasks', [])
                    day_tasks += len(tasks)
                    day_completed += sum(1 for t in tasks if t.get('completed', False))

        rate = int(day_completed / day_tasks * 100) if day_tasks > 0 else 0
        daily_progress.append({
            'date': target_date,
            'dayName': ['월', '화', '수', '목', '금', '토', '일'][(today - timedelta(days=i)).weekday()],
            'rate': rate,
            'completed': day_completed,
            'total': day_tasks
        })

    # 연속 학습일 계산
    for i in range(30):  # 최대 30일 체크
        target_date = (today - timedelta(days=i)).isoformat()
        day_has_completed = False

        for plan in plans:
            for day in plan.get('daily_schedule', []):
                if day.get('date') == target_date:
                    if any(t.get('completed', False) for t in day.get('tasks', [])):
                        day_has_completed = True
                        break
            if day_has_completed:
                break

        if day_has_completed:
            streak_days += 1
        else:
            break

    # 전체 완료율
    overall_rate = int(completed_tasks / total_tasks * 100) if total_tasks > 0 else 0

    # 주제별 통계
    topic_stats = []
    for name, data in topics.items():
        rate = int(data['completed'] / data['total'] * 100) if data['total'] > 0 else 0
        topic_stats.append({
            'name': name,
            'total': data['total'],
            'completed': data['completed'],
            'rate': rate
        })

    # 완료율 기준 정렬
    topic_stats.sort(key=lambda x: x['rate'], reverse=True)

    return {
        'totalTasks': total_tasks,
        'completedTasks': completed_tasks,
        'overallRate': overall_rate,
        'totalStudyDays': total_study_days,
        'streakDays': streak_days,
        'dailyProgress': daily_progress,
        'topicStats': topic_stats,
        'totalPlans': len(plans)
    }


@router.get("/weekly")
async def get_weekly_stats(current_user: Dict = Depends(get_current_user)):
    """주간 통계 조회"""
    log_request("GET /stats/weekly", current_user['name'])

    user_id = current_user['user_id']
    plans = store.get_plans(user_id)

    today = datetime.now().date()
    start_of_week = today - timedelta(days=today.weekday())

    weekly_data = []
    total_completed = 0
    total_tasks = 0

    for i in range(7):
        target_date = (start_of_week + timedelta(days=i)).isoformat()
        day_tasks = 0
        day_completed = 0

        for plan in plans:
            for day in plan.get('daily_schedule', []):
                if day.get('date') == target_date:
                    tasks = day.get('tasks', [])
                    day_tasks += len(tasks)
                    day_completed += sum(1 for t in tasks if t.get('completed', False))

        total_tasks += day_tasks
        total_completed += day_completed

        weekly_data.append({
            'date': target_date,
            'dayName': ['월', '화', '수', '목', '금', '토', '일'][i],
            'tasks': day_tasks,
            'completed': day_completed,
            'rate': int(day_completed / day_tasks * 100) if day_tasks > 0 else 0
        })

    return {
        'weekStart': start_of_week.isoformat(),
        'weekEnd': (start_of_week + timedelta(days=6)).isoformat(),
        'totalTasks': total_tasks,
        'totalCompleted': total_completed,
        'weeklyRate': int(total_completed / total_tasks * 100) if total_tasks > 0 else 0,
        'days': weekly_data
    }


@router.get("/achievements")
async def get_achievements(current_user: Dict = Depends(get_current_user)):
    """업적 조회"""
    log_request("GET /stats/achievements", current_user['name'])

    user_id = current_user['user_id']
    plans = store.get_plans(user_id)

    # 통계 계산
    total_tasks = 0
    completed_tasks = 0

    for plan in plans:
        for day in plan.get('daily_schedule', []):
            tasks = day.get('tasks', [])
            total_tasks += len(tasks)
            completed_tasks += sum(1 for t in tasks if t.get('completed', False))

    # 업적 목록
    achievements = [
        {
            'id': 'first_task',
            'title': '첫 발걸음',
            'description': '첫 번째 학습 완료',
            'icon': '🎯',
            'unlocked': completed_tasks >= 1,
            'progress': min(completed_tasks, 1),
            'target': 1
        },
        {
            'id': 'ten_tasks',
            'title': '열심히 학습 중',
            'description': '10개의 학습 완료',
            'icon': '📚',
            'unlocked': completed_tasks >= 10,
            'progress': min(completed_tasks, 10),
            'target': 10
        },
        {
            'id': 'fifty_tasks',
            'title': '학습 전문가',
            'description': '50개의 학습 완료',
            'icon': '🏆',
            'unlocked': completed_tasks >= 50,
            'progress': min(completed_tasks, 50),
            'target': 50
        },
        {
            'id': 'hundred_tasks',
            'title': '학습 마스터',
            'description': '100개의 학습 완료',
            'icon': '👑',
            'unlocked': completed_tasks >= 100,
            'progress': min(completed_tasks, 100),
            'target': 100
        },
        {
            'id': 'first_plan',
            'title': '계획의 시작',
            'description': '첫 번째 학습 계획 생성',
            'icon': '📝',
            'unlocked': len(plans) >= 1,
            'progress': min(len(plans), 1),
            'target': 1
        },
        {
            'id': 'three_plans',
            'title': '다양한 학습',
            'description': '3개의 학습 계획 생성',
            'icon': '📖',
            'unlocked': len(plans) >= 3,
            'progress': min(len(plans), 3),
            'target': 3
        },
    ]

    unlocked_count = sum(1 for a in achievements if a['unlocked'])

    return {
        'achievements': achievements,
        'unlockedCount': unlocked_count,
        'totalCount': len(achievements)
    }

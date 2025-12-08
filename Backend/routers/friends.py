# Backend/routers/friends.py
"""친구 관련 라우터"""

from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Optional
from datetime import date, datetime

from models.schemas import AddFriendRequest, CheckFriendPlanRequest
from services.store import store
from utils.logger import log_request, log_stage, log_success, log_error, log_navigation
from .auth import get_current_user

router = APIRouter(prefix="/friends", tags=["Friends"])


@router.get("")
async def get_friends(current_user: Dict = Depends(get_current_user)):
    log_request("GET /friends", current_user['name'])
    log_stage(8, "친구 목록", current_user['name'])
    log_navigation(current_user['name'], "친구 화면")

    user_id = current_user['user_id']

    # 실제 친구 목록 가져오기
    real_friends = store.get_friends(user_id)

    friends = []
    for friend in real_friends:
        today_rate = 0
        friend_plans = store.get_plans(friend['user_id'])
        if friend_plans:
            today_str = date.today().isoformat()
            for plan in friend_plans:
                for day in plan.get('daily_schedule', []):
                    if day['date'] == today_str:
                        total = len(day['tasks'])
                        completed = sum(1 for t in day['tasks'] if t.get('completed', False))
                        today_rate = int((completed / total * 100) if total > 0 else 0)
                        break

        friends.append({
            "id": friend['user_id'],
            "name": friend['name'],
            "avatarUrl": friend.get('photo_url'),
            "todayRate": today_rate
        })

    # 샘플 친구도 항상 포함
    sample_friends = store.get_sample_friends()
    friends.extend(sample_friends)

    return friends


@router.post("/add")
async def add_friend(request: AddFriendRequest, current_user: Dict = Depends(get_current_user)):
    log_request("POST /friends/add", current_user['name'], f"code={request.code}")

    user_id = current_user['user_id']
    friend_code = request.code.upper()

    # 친구 코드로 사용자 찾기
    friend = store.get_user_by_friend_code(friend_code)

    if not friend:
        log_error(f"친구 코드 없음: {friend_code}")
        raise HTTPException(status_code=404, detail="친구 코드를 찾을 수 없습니다.")

    friend_id = friend['user_id']

    if friend_id == user_id:
        raise HTTPException(status_code=400, detail="자기 자신은 친구로 추가할 수 없습니다.")

    # 이미 친구인지 확인
    existing_friends = store.get_friends(user_id)
    if any(f['user_id'] == friend_id for f in existing_friends):
        raise HTTPException(status_code=400, detail="이미 친구입니다.")

    # 친구 추가
    store.add_friend(user_id, friend_id)

    # 알림 추가
    store.add_notification(friend_id, f"{current_user['name']}님이 친구로 추가했습니다.")

    log_success(f"친구 추가 완료: {friend['name']}")

    return {
        "success": True,
        "friend": {
            "id": friend_id,
            "name": friend['name'],
            "avatarUrl": friend.get('photo_url'),
            "todayRate": 0
        }
    }


@router.get("/{friend_id}/plans")
async def get_friend_plans(
    friend_id: str,
    date: Optional[str] = None,
    current_user: Dict = Depends(get_current_user)
):
    """친구의 특정 날짜 학습 계획 조회"""
    log_request("GET /friends/{id}/plans", current_user['name'], f"friend_id={friend_id}, date={date}")

    # 샘플 친구는 항상 접근 가능
    if not friend_id.startswith('sample-friend-'):
        # 실제 친구인지 확인
        user_id = current_user['user_id']
        friends = store.get_friends(user_id)
        if not any(f['user_id'] == friend_id for f in friends):
            raise HTTPException(status_code=403, detail="친구가 아닙니다.")

    target_date = date or datetime.today().strftime('%Y-%m-%d')
    plans = store.get_friend_plans_by_date(friend_id, target_date)

    return plans


@router.post("/{friend_id}/plans/check")
async def check_friend_plan(
    friend_id: str,
    request: CheckFriendPlanRequest,
    current_user: Dict = Depends(get_current_user)
):
    """친구 응원하기"""
    friend = store.get_user_by_id(friend_id)
    if friend:
        store.add_notification(
            friend_id,
            f"{current_user['name']}님이 응원합니다! 💪"
        )
        log_success(f"{current_user['name']} → {friend['name']} 응원 전송")

    return {"success": True}

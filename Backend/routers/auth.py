# Backend/routers/auth.py
"""인증 관련 라우터 - 보안 강화 버전"""

from fastapi import APIRouter, HTTPException, Depends, Header, Request
from typing import Dict
import re

from slowapi import Limiter
from slowapi.util import get_remote_address

from models.schemas import SignupRequest, LoginRequest
from services.store import store
from utils.logger import log_request, log_stage, log_success, log_error, log_navigation

router = APIRouter(prefix="/auth", tags=["Auth"])
limiter = Limiter(key_func=get_remote_address)


# ==================== 입력 검증 함수 ====================

def validate_email(email: str) -> bool:
    """이메일 형식 검증"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))


def validate_password(password: str) -> tuple[bool, str]:
    """
    비밀번호 강도 검증
    - 최소 8자 이상
    - 대문자 1개 이상
    """
    if len(password) < 8:
        return False, "비밀번호는 최소 8자 이상이어야 합니다."
    if not re.search(r'[A-Z]', password):
        return False, "비밀번호에 대문자가 1개 이상 포함되어야 합니다."
    return True, ""


def sanitize_input(text: str) -> str:
    """입력값 정제 (XSS 방지)"""
    if not text:
        return text
    # HTML 태그 제거
    text = re.sub(r'<[^>]*>', '', text)
    # 특수 문자 이스케이프
    text = text.replace('&', '&amp;')
    text = text.replace('<', '&lt;')
    text = text.replace('>', '&gt;')
    text = text.replace('"', '&quot;')
    text = text.replace("'", '&#x27;')
    return text.strip()


# ==================== 인증 의존성 ====================

async def get_current_user(authorization: str = Header(None)) -> Dict:
    """현재 인증된 사용자 가져오기"""
    if not authorization:
        raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")

    token = authorization.replace("Bearer ", "") if authorization.startswith("Bearer ") else authorization
    user = store.get_user_by_token(token)

    if not user:
        raise HTTPException(status_code=401, detail="유효하지 않거나 만료된 토큰입니다.")

    return user


# ==================== API 엔드포인트 ====================

@router.post("/signup")
@limiter.limit("5/minute")  # 분당 5회 제한
async def signup(request: Request, data: SignupRequest):
    """회원가입 - 입력 검증 강화"""
    log_request("POST /auth/signup", data.name, f"email={data.email}")
    log_stage(1, "회원가입", data.name)

    # 이메일 형식 검증
    if not validate_email(data.email):
        log_error(f"회원가입 실패 - 이메일 형식 오류: {data.email}")
        raise HTTPException(status_code=400, detail="올바른 이메일 형식이 아닙니다.")

    # 비밀번호 강도 검증
    is_valid, error_msg = validate_password(data.password)
    if not is_valid:
        log_error(f"회원가입 실패 - 비밀번호 요구사항 미충족: {data.email}")
        raise HTTPException(status_code=400, detail=error_msg)

    # 입력값 정제
    sanitized_name = sanitize_input(data.name)
    sanitized_username = sanitize_input(data.username)

    if not sanitized_name or len(sanitized_name) < 2:
        raise HTTPException(status_code=400, detail="이름은 2자 이상이어야 합니다.")

    user = store.create_user(
        username=sanitized_username,
        email=data.email.lower().strip(),  # 이메일 정규화
        password=data.password,
        name=sanitized_name,
        birth=data.birth,
        photo_url=data.photo_url
    )

    if not user:
        log_error(f"회원가입 실패 - 이메일 중복: {data.email}")
        raise HTTPException(status_code=400, detail="이미 존재하는 이메일입니다.")

    log_success(f"회원가입 완료! user_id={user['user_id'][:8]}..., 친구코드={user['friend_code']}")

    return {
        "success": True,
        "userId": user['user_id'],
        "friendCode": user['friend_code'],
        "message": "회원가입이 완료되었습니다."
    }


@router.post("/login")
@limiter.limit("10/minute")  # 분당 10회 제한 (브루트포스 방지)
async def login(request: Request, data: LoginRequest):
    """로그인 - Rate Limiting 적용"""
    log_request("POST /auth/login", data.email)
    log_stage(2, "로그인", data.email)

    # 이메일 정규화
    email = data.email.lower().strip()

    result = store.login(email, data.password)

    if not result:
        log_error(f"로그인 실패: {email}")
        raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 올바르지 않습니다.")

    log_success(f"로그인 성공! name={result['name']}, token={result['token'][:20]}...")
    log_navigation(result['name'], "홈 화면")

    return {
        "success": True,
        "token": result['token'],
        "userId": result['user_id'],
        "displayName": result['name']
    }


@router.post("/logout")
async def logout(current_user: Dict = Depends(get_current_user), authorization: str = Header(None)):
    """로그아웃 - 토큰 블랙리스트"""
    log_request("POST /auth/logout", current_user['name'])
    log_navigation(current_user['name'], "로그아웃 → 로그인 화면")

    if authorization:
        token = authorization.replace("Bearer ", "") if authorization.startswith("Bearer ") else authorization
        store.logout(token)

    log_success(f"로그아웃 완료: {current_user['name']}")
    return {"success": True, "message": "로그아웃되었습니다."}


@router.get("/me")
async def get_me(current_user: Dict = Depends(get_current_user)):
    """현재 로그인한 사용자 정보"""
    return {
        "success": True,
        "user": {
            "userId": current_user['user_id'],
            "email": current_user['email'],
            "name": current_user['name'],
            "friendCode": current_user['friend_code'],
            "birth": current_user.get('birth'),
            "photoUrl": current_user.get('photo_url')
        }
    }


@router.post("/validate-password")
async def validate_password_endpoint(password: str):
    """비밀번호 강도 검증 (프론트엔드용)"""
    is_valid, error_msg = validate_password(password)

    # 강도 계산
    strength = 0
    if len(password) >= 8:
        strength += 20
    if len(password) >= 12:
        strength += 10
    if re.search(r'[A-Z]', password):
        strength += 20
    if re.search(r'[a-z]', password):
        strength += 20
    if re.search(r'[0-9]', password):
        strength += 15
    if re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        strength += 15

    return {
        "valid": is_valid,
        "message": error_msg if not is_valid else "강력한 비밀번호입니다.",
        "strength": min(strength, 100)
    }

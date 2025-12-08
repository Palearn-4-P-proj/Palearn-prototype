# Backend/main.py
"""Palearn API 메인 진입점 - 보안 강화 버전"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from datetime import datetime
import os

from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from utils.logger import Colors
from routers import auth, quiz, profile, home, plans, recommend, friends, notifications, review, plan_apply, stats

# Rate Limiter 설정
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="Palearn API",
    version="2.0.0",
    description="AI 기반 개인화 학습 플랫폼 API"
)

# Rate Limiter 등록
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS 설정 - 화이트리스트 방식 (Flutter 웹 포트 포함)
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:53832,http://localhost:53832").split(",")

# 개발 환경에서는 모든 origin 허용
if os.getenv("ENV", "development") == "development":
    ALLOWED_ORIGINS = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
    max_age=600,  # Preflight 캐시 10분
)


# 전역 에러 핸들러
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "detail": "서버 내부 오류가 발생했습니다.",
            "error_type": type(exc).__name__
        }
    )


# 라우터 등록
app.include_router(auth.router)
app.include_router(quiz.router)
app.include_router(profile.router)
app.include_router(home.router)
app.include_router(plans.router)
app.include_router(recommend.router)
app.include_router(friends.router)
app.include_router(notifications.router)
app.include_router(review.router)
app.include_router(plan_apply.router)
app.include_router(stats.router)


@app.get("/health")
async def health_check():
    """서버 상태 확인"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "2.0.0"
    }


@app.get("/")
async def root():
    """API 정보"""
    return {
        "message": "Palearn API Server",
        "version": "2.0.0",
        "docs": "/docs",
        "features": [
            "bcrypt 비밀번호 해싱",
            "JWT 토큰 인증",
            "SQLite 영속성 저장소",
            "Rate Limiting"
        ]
    }


@app.on_event("startup")
async def startup_event():
    print(f"""
{Colors.CYAN}{'='*70}

    ____        _
   |  _ \\ __ _| | ___  __ _ _ __ _ __
   | |_) / _` | |/ _ \\/ _` | '__| '_ \\
   |  __/ (_| | |  __/ (_| | |  | | | |
   |_|   \\__,_|_|\\___|\\__,_|_|  |_| |_|

   Backend Server v2.0.0 (Secure Edition)

{'='*70}{Colors.ENDC}

{Colors.GREEN}[SECURITY]{Colors.ENDC}
  - bcrypt 비밀번호 해싱
  - JWT 토큰 인증 (24시간 만료)
  - Rate Limiting 활성화
  - CORS 화이트리스트 적용

{Colors.GREEN}[DATABASE]{Colors.ENDC}
  - SQLite 영속성 저장소
  - 자동 테이블 생성

{Colors.GREEN}[SERVER READY]{Colors.ENDC} http://localhost:8000
{Colors.BLUE}[API DOCS]{Colors.ENDC}     http://localhost:8000/docs

{Colors.YELLOW}━━━ 모듈 구조 ━━━{Colors.ENDC}
  routers/
     auth.py        - 인증 (회원가입/로그인/로그아웃)
     quiz.py        - 퀴즈 (생성/채점)
     profile.py     - 프로필 (조회/수정)
     home.py        - 홈 (대시보드)
     plans.py       - 학습 계획 (CRUD)
     recommend.py   - AI 강좌 추천
     friends.py     - 친구 (추가/삭제/목록)
     notifications.py - 알림
     review.py      - 복습 자료

  services/
     store.py       - SQLite 데이터 저장소
     gpt_service.py - GPT 호출

{Colors.CYAN}대기 중... Flutter 앱에서 요청을 보내주세요!{Colors.ENDC}
""")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

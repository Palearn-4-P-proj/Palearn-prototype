FROM python:3.11-slim

WORKDIR /app

# 시스템 의존성 설치
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Python 의존성 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Backend 폴더 구조 생성
RUN mkdir -p /app/Backend

# 소스 코드 복사
COPY . /app/Backend/

# 데이터 디렉토리 생성
RUN mkdir -p /app/Backend/data

# 포트 노출 (Railway는 $PORT 환경변수 사용)
EXPOSE 8000

# 환경 변수
ENV PYTHONUNBUFFERED=1
ENV ENV=production
ENV PYTHONPATH=/app

# 서버 실행 (Railway는 PORT 환경변수 제공)
CMD uvicorn Backend.main:app --host 0.0.0.0 --port ${PORT:-8000}

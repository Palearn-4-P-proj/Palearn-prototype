FROM python:3.11-slim

WORKDIR /app

# 시스템 의존성 설치
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 소스 코드 복사
COPY . .

# Python 의존성 설치
RUN pip install --no-cache-dir -r requirements.txt

# 데이터 디렉토리 생성
RUN mkdir -p /app/data

# 포트 노출
EXPOSE 8000

# 환경 변수
ENV PYTHONUNBUFFERED=1
ENV ENV=production

# 서버 실행 (8000 포트 고정)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

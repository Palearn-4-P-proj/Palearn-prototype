# Palearn 배포 가이드

## 방법 1: Railway 무료 배포 (가장 쉬움)

### 1단계: 백엔드 배포

1. [Railway](https://railway.app) 가입 (GitHub 연동)

2. "New Project" → "Deploy from GitHub repo" 선택

3. 이 저장소 선택

4. 설정:
   - Root Directory: `Backend`
   - 환경 변수 추가:
     ```
     OPENAI_API_KEY=sk-your-openai-key
     JWT_SECRET_KEY=your-secret-key-here
     ENV=production
     ALLOWED_ORIGINS=*
     ```

5. Deploy 클릭 → 배포 완료 후 URL 확인 (예: `https://palearn-backend.up.railway.app`)

### 2단계: Flutter 웹 빌드 및 배포

```bash
# 웹 빌드 (API_URL을 Railway 백엔드 URL로 설정)
flutter build web --release --dart-define=API_URL=https://palearn-backend.up.railway.app

# build/web 폴더가 생성됨
```

### 3단계: 프론트엔드 배포 (Vercel/Netlify)

**Vercel 사용:**
1. [Vercel](https://vercel.com) 가입
2. `build/web` 폴더를 드래그앤드롭으로 업로드
3. 배포 완료!

**또는 Netlify 사용:**
1. [Netlify](https://netlify.com) 가입
2. `build/web` 폴더를 드래그앤드롭
3. 배포 완료!

---

## 방법 2: Docker Compose (자체 서버)

서버가 있다면 Docker로 한번에 배포:

```bash
# .env 파일 생성
cat > .env << EOF
OPENAI_API_KEY=sk-your-openai-key
JWT_SECRET_KEY=your-secret-key-here
EOF

# 실행
docker-compose up -d --build

# 확인
# 백엔드: http://localhost:8000
# 프론트엔드: http://localhost:80
```

---

## 방법 3: 로컬 테스트

### 백엔드 실행
```bash
cd Backend
pip install -r requirements.txt
uvicorn Backend.main:app --reload --port 8000
```

### Flutter 웹 실행
```bash
flutter run -d chrome
```

---

## 환경 변수 설명

| 변수 | 설명 | 예시 |
|------|------|------|
| `OPENAI_API_KEY` | OpenAI API 키 | `sk-...` |
| `JWT_SECRET_KEY` | JWT 토큰 서명 키 | 랜덤 문자열 |
| `ENV` | 환경 (development/production) | `production` |
| `ALLOWED_ORIGINS` | CORS 허용 도메인 | `*` 또는 특정 도메인 |
| `API_URL` | Flutter 빌드 시 백엔드 URL | `https://api.example.com` |

---

## 빠른 시작 명령어

```bash
# 1. 백엔드 로컬 실행
cd Backend && pip install -r requirements.txt && uvicorn Backend.main:app --reload

# 2. 다른 터미널에서 Flutter 웹 실행
flutter run -d chrome --dart-define=API_URL=http://localhost:8000
```

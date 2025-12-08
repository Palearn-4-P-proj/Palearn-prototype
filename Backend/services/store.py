# Backend/services/store.py
"""SQLite 기반 영속성 데이터 저장소 + bcrypt 비밀번호 해싱"""

from typing import Dict, List, Optional
from datetime import datetime, timedelta
import uuid
import hashlib
import sqlite3
import json
import os
import bcrypt
from jose import jwt

# JWT 설정
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "palearn-secret-key-change-in-production-2024")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 24

# 데이터베이스 경로
DB_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "palearn.db")


class PlansList(list):
    """append 시 자동으로 DB에 저장하는 특수 리스트"""
    def __init__(self, store, user_id, initial_data=None):
        super().__init__(initial_data or [])
        self._store = store
        self._user_id = user_id

    def append(self, plan):
        """계획 추가 시 DB에도 저장"""
        super().append(plan)
        # DB에 저장
        self._store.save_plan(
            self._user_id,
            plan.get('plan_name', '학습 계획'),
            plan.get('total_duration', ''),
            plan.get('daily_schedule', [])
        )


class PlansProxy:
    """plans 딕셔너리처럼 동작하는 프록시 클래스"""
    def __init__(self, store):
        self._store = store
        self._cache = {}

    def get(self, user_id: str, default=None):
        """딕셔너리의 get처럼 동작"""
        plans = self._store.get_plans(user_id)
        return plans if plans else (default if default is not None else [])

    def __getitem__(self, user_id: str):
        """plans[user_id] 접근"""
        if user_id not in self._cache:
            plans = self._store.get_plans(user_id)
            self._cache[user_id] = PlansList(self._store, user_id, plans)
        return self._cache[user_id]

    def __setitem__(self, user_id: str, value):
        """plans[user_id] = value 설정"""
        self._cache[user_id] = PlansList(self._store, user_id, value)

    def setdefault(self, user_id: str, default=None):
        """딕셔너리의 setdefault처럼 동작"""
        if user_id not in self._cache:
            plans = self._store.get_plans(user_id)
            self._cache[user_id] = PlansList(self._store, user_id, plans if plans else (default if default is not None else []))
        return self._cache[user_id]


class DataStore:
    def __init__(self):
        self._ensure_db_dir()
        self._init_db()
        # plans 프록시 - 기존 코드와 호환성 유지
        self.plans = PlansProxy(self)
        # 기타 메모리 캐시
        self.quiz_answers = {}
        self.notifications_cache = {}

    def _ensure_db_dir(self):
        """데이터베이스 디렉토리 생성"""
        db_dir = os.path.dirname(DB_PATH)
        if not os.path.exists(db_dir):
            os.makedirs(db_dir)

    def _get_connection(self):
        """SQLite 연결 반환"""
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self):
        """데이터베이스 테이블 초기화"""
        conn = self._get_connection()
        cursor = conn.cursor()

        # Users 테이블
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                user_id TEXT PRIMARY KEY,
                username TEXT NOT NULL,
                email TEXT UNIQUE NOT NULL,
                password TEXT NOT NULL,
                name TEXT NOT NULL,
                birth TEXT,
                photo_url TEXT,
                friend_code TEXT UNIQUE NOT NULL,
                created_at TEXT NOT NULL
            )
        ''')

        # Friendships 테이블
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS friendships (
                user_id TEXT NOT NULL,
                friend_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                PRIMARY KEY (user_id, friend_id),
                FOREIGN KEY (user_id) REFERENCES users(user_id),
                FOREIGN KEY (friend_id) REFERENCES users(user_id)
            )
        ''')

        # Plans 테이블
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS plans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                plan_name TEXT NOT NULL,
                total_duration TEXT,
                daily_schedule TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(user_id)
            )
        ''')

        # Notifications 테이블
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                message TEXT NOT NULL,
                is_read INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(user_id)
            )
        ''')

        # Quiz Answers 테이블
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS quiz_answers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                quiz_data TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(user_id)
            )
        ''')

        # Tokens 테이블 (블랙리스트용)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS token_blacklist (
                token TEXT PRIMARY KEY,
                blacklisted_at TEXT NOT NULL
            )
        ''')

        conn.commit()
        conn.close()

    # ==================== 비밀번호 해싱 (bcrypt) ====================

    def _hash_password(self, password: str) -> str:
        """bcrypt로 비밀번호 해싱"""
        salt = bcrypt.gensalt()
        return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

    def _verify_password(self, password: str, hashed: str) -> bool:
        """bcrypt로 비밀번호 검증"""
        try:
            return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))
        except Exception:
            return False

    # ==================== JWT 토큰 관리 ====================

    def _create_access_token(self, user_id: str) -> str:
        """JWT 액세스 토큰 생성"""
        expire = datetime.utcnow() + timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
        to_encode = {
            "sub": user_id,
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "access"
        }
        return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

    def verify_token(self, token: str) -> Optional[str]:
        """JWT 토큰 검증 후 user_id 반환"""
        try:
            # 블랙리스트 확인
            conn = self._get_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT token FROM token_blacklist WHERE token = ?", (token,))
            if cursor.fetchone():
                conn.close()
                return None
            conn.close()

            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            return payload.get("sub")
        except Exception:
            return None

    def blacklist_token(self, token: str):
        """토큰을 블랙리스트에 추가"""
        conn = self._get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "INSERT OR IGNORE INTO token_blacklist (token, blacklisted_at) VALUES (?, ?)",
                (token, datetime.now().isoformat())
            )
            conn.commit()
        finally:
            conn.close()

    # ==================== 사용자 관리 ====================

    def create_user(self, username: str, email: str, password: str, name: str, birth: str, photo_url: str = None) -> Optional[Dict]:
        """사용자 생성 (bcrypt 해싱)"""
        conn = self._get_connection()
        cursor = conn.cursor()

        # 이메일 중복 확인
        cursor.execute("SELECT user_id FROM users WHERE email = ?", (email,))
        if cursor.fetchone():
            conn.close()
            return None

        user_id = str(uuid.uuid4())
        friend_code = hashlib.md5(user_id.encode()).hexdigest()[:8].upper()
        password_hash = self._hash_password(password)
        created_at = datetime.now().isoformat()

        cursor.execute('''
            INSERT INTO users (user_id, username, email, password, name, birth, photo_url, friend_code, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, username, email, password_hash, name, birth, photo_url, friend_code, created_at))

        conn.commit()
        conn.close()

        return {
            'user_id': user_id,
            'username': username,
            'email': email,
            'name': name,
            'birth': birth,
            'photo_url': photo_url,
            'friend_code': friend_code,
            'created_at': created_at
        }

    def login(self, email: str, password: str) -> Optional[Dict]:
        """로그인 (bcrypt 검증 + JWT 발급)"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
        row = cursor.fetchone()
        conn.close()

        if not row:
            return None

        if not self._verify_password(password, row['password']):
            return None

        token = self._create_access_token(row['user_id'])

        return {
            'token': token,
            'user_id': row['user_id'],
            'name': row['name']
        }

    def get_user_by_token(self, token: str) -> Optional[Dict]:
        """토큰으로 사용자 조회"""
        user_id = self.verify_token(token)
        if not user_id:
            return None
        return self.get_user_by_id(user_id)

    def get_user_by_id(self, user_id: str) -> Optional[Dict]:
        """ID로 사용자 조회"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM users WHERE user_id = ?", (user_id,))
        row = cursor.fetchone()
        conn.close()

        if not row:
            return None

        return dict(row)

    def get_user_id_by_token(self, token: str) -> Optional[str]:
        """토큰에서 user_id 추출"""
        return self.verify_token(token)

    def logout(self, token: str) -> bool:
        """로그아웃 (토큰 블랙리스트)"""
        self.blacklist_token(token)
        return True

    def update_user(self, user_id: str, **kwargs) -> bool:
        """사용자 정보 업데이트"""
        conn = self._get_connection()
        cursor = conn.cursor()

        updates = []
        values = []

        for key, value in kwargs.items():
            if value is not None and key in ['email', 'name', 'birth', 'photo_url']:
                updates.append(f"{key} = ?")
                values.append(value)
            elif key == 'password' and value:
                updates.append("password = ?")
                values.append(self._hash_password(value))

        if not updates:
            conn.close()
            return False

        values.append(user_id)
        cursor.execute(f"UPDATE users SET {', '.join(updates)} WHERE user_id = ?", values)
        conn.commit()
        conn.close()
        return True

    def get_user_by_friend_code(self, code: str) -> Optional[Dict]:
        """친구 코드로 사용자 조회"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM users WHERE friend_code = ?", (code.upper(),))
        row = cursor.fetchone()
        conn.close()

        return dict(row) if row else None

    # ==================== 친구 관리 ====================

    def get_friends(self, user_id: str) -> List[Dict]:
        """친구 목록 조회"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute('''
            SELECT u.* FROM users u
            JOIN friendships f ON u.user_id = f.friend_id
            WHERE f.user_id = ?
        ''', (user_id,))

        rows = cursor.fetchall()
        conn.close()

        return [dict(row) for row in rows]

    def add_friend(self, user_id: str, friend_id: str) -> bool:
        """친구 추가 (양방향)"""
        if user_id == friend_id:
            return False

        conn = self._get_connection()
        cursor = conn.cursor()

        try:
            created_at = datetime.now().isoformat()
            # 양방향 추가
            cursor.execute(
                "INSERT OR IGNORE INTO friendships (user_id, friend_id, created_at) VALUES (?, ?, ?)",
                (user_id, friend_id, created_at)
            )
            cursor.execute(
                "INSERT OR IGNORE INTO friendships (user_id, friend_id, created_at) VALUES (?, ?, ?)",
                (friend_id, user_id, created_at)
            )
            conn.commit()
            return True
        except Exception:
            return False
        finally:
            conn.close()

    def remove_friend(self, user_id: str, friend_id: str) -> bool:
        """친구 삭제 (양방향)"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute("DELETE FROM friendships WHERE user_id = ? AND friend_id = ?", (user_id, friend_id))
        cursor.execute("DELETE FROM friendships WHERE user_id = ? AND friend_id = ?", (friend_id, user_id))

        conn.commit()
        conn.close()
        return True

    # ==================== 학습 계획 관리 ====================

    def get_plans(self, user_id: str) -> List[Dict]:
        """사용자의 모든 학습 계획 조회"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM plans WHERE user_id = ? ORDER BY created_at DESC", (user_id,))
        rows = cursor.fetchall()
        conn.close()

        result = []
        for row in rows:
            plan = dict(row)
            if plan.get('daily_schedule'):
                plan['daily_schedule'] = json.loads(plan['daily_schedule'])
            result.append(plan)

        return result

    def save_plan(self, user_id: str, plan_name: str, total_duration: str, daily_schedule: List[Dict]) -> bool:
        """학습 계획 저장"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute('''
            INSERT INTO plans (user_id, plan_name, total_duration, daily_schedule, created_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (user_id, plan_name, total_duration, json.dumps(daily_schedule, ensure_ascii=False), datetime.now().isoformat()))

        conn.commit()
        conn.close()
        return True

    def update_task(self, user_id: str, date: str, task_id: str, completed: bool) -> bool:
        """태스크 완료 상태 업데이트"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT id, daily_schedule FROM plans WHERE user_id = ?", (user_id,))
        rows = cursor.fetchall()

        for row in rows:
            schedule = json.loads(row['daily_schedule']) if row['daily_schedule'] else []
            modified = False

            for day in schedule:
                if day.get('date') == date:
                    for task in day.get('tasks', []):
                        if task.get('id') == task_id:
                            task['completed'] = completed
                            modified = True
                            break
                if modified:
                    break

            if modified:
                cursor.execute(
                    "UPDATE plans SET daily_schedule = ? WHERE id = ?",
                    (json.dumps(schedule, ensure_ascii=False), row['id'])
                )
                conn.commit()
                conn.close()
                return True

        conn.close()
        return False

    # ==================== 알림 관리 ====================

    def get_notifications(self, user_id: str) -> Dict[str, List[str]]:
        """알림 조회 (new/old 분리)"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT message, is_read FROM notifications WHERE user_id = ? ORDER BY created_at DESC",
            (user_id,)
        )
        rows = cursor.fetchall()
        conn.close()

        result = {'new': [], 'old': []}
        for row in rows:
            if row['is_read']:
                result['old'].append(row['message'])
            else:
                result['new'].append(row['message'])

        return result

    def add_notification(self, user_id: str, message: str):
        """알림 추가"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "INSERT INTO notifications (user_id, message, created_at) VALUES (?, ?, ?)",
            (user_id, message, datetime.now().isoformat())
        )

        conn.commit()
        conn.close()

    def mark_notifications_read(self, user_id: str):
        """모든 알림 읽음 처리"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute("UPDATE notifications SET is_read = 1 WHERE user_id = ?", (user_id,))

        conn.commit()
        conn.close()

    # ==================== 퀴즈 관리 ====================

    def save_quiz_answers(self, user_id: str, quiz_data: List[Dict]):
        """퀴즈 답안 저장"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "INSERT INTO quiz_answers (user_id, quiz_data, created_at) VALUES (?, ?, ?)",
            (user_id, json.dumps(quiz_data, ensure_ascii=False), datetime.now().isoformat())
        )

        conn.commit()
        conn.close()

    def get_quiz_answers(self, user_id: str) -> List[Dict]:
        """최근 퀴즈 답안 조회"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT quiz_data FROM quiz_answers WHERE user_id = ? ORDER BY created_at DESC LIMIT 1",
            (user_id,)
        )
        row = cursor.fetchone()
        conn.close()

        if row and row['quiz_data']:
            return json.loads(row['quiz_data'])
        return []

    # ==================== 샘플 데이터 ====================

    def init_sample_data(self):
        """샘플 친구 및 학습 계획 데이터 초기화"""
        conn = self._get_connection()
        cursor = conn.cursor()

        # 샘플 친구가 이미 있는지 확인
        cursor.execute("SELECT user_id FROM users WHERE email = ?", ("sample@palearn.com",))
        if cursor.fetchone():
            conn.close()
            return  # 이미 존재하면 스킵

        # 샘플 친구 생성
        sample_users = [
            {
                'user_id': 'sample-friend-001',
                'username': 'kimcoding',
                'email': 'sample@palearn.com',
                'password': self._hash_password('Sample123!'),
                'name': '김코딩',
                'birth': '1998-03-15',
                'photo_url': 'https://i.pravatar.cc/150?img=1',
                'friend_code': 'SAMPLE01',
            },
            {
                'user_id': 'sample-friend-002',
                'username': 'leepython',
                'email': 'sample2@palearn.com',
                'password': self._hash_password('Sample123!'),
                'name': '이파이썬',
                'birth': '1999-07-22',
                'photo_url': 'https://i.pravatar.cc/150?img=2',
                'friend_code': 'SAMPLE02',
            },
            {
                'user_id': 'sample-friend-003',
                'username': 'parkflutter',
                'email': 'sample3@palearn.com',
                'password': self._hash_password('Sample123!'),
                'name': '박플러터',
                'birth': '2000-11-08',
                'photo_url': 'https://i.pravatar.cc/150?img=3',
                'friend_code': 'SAMPLE03',
            },
        ]

        for user in sample_users:
            cursor.execute('''
                INSERT OR IGNORE INTO users (user_id, username, email, password, name, birth, photo_url, friend_code, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                user['user_id'], user['username'], user['email'], user['password'],
                user['name'], user['birth'], user['photo_url'], user['friend_code'],
                datetime.now().isoformat()
            ))

        # 샘플 학습 계획 생성
        from datetime import timedelta
        today = datetime.now().date()

        sample_plans = [
            {
                'user_id': 'sample-friend-001',
                'plan_name': 'Python 마스터 과정',
                'total_duration': '4주',
                'daily_schedule': [
                    {
                        'date': (today - timedelta(days=1)).isoformat(),
                        'tasks': [
                            {'id': 'task-s1-1', 'title': 'Python 기초 문법 복습', 'duration': '1시간', 'completed': True},
                            {'id': 'task-s1-2', 'title': '리스트와 딕셔너리 실습', 'duration': '1시간', 'completed': True},
                        ]
                    },
                    {
                        'date': today.isoformat(),
                        'tasks': [
                            {'id': 'task-s1-3', 'title': '클래스와 객체 학습', 'duration': '1시간 30분', 'completed': True},
                            {'id': 'task-s1-4', 'title': '상속과 다형성 실습', 'duration': '1시간', 'completed': False},
                            {'id': 'task-s1-5', 'title': '예외 처리 학습', 'duration': '30분', 'completed': False},
                        ]
                    },
                    {
                        'date': (today + timedelta(days=1)).isoformat(),
                        'tasks': [
                            {'id': 'task-s1-6', 'title': '파일 입출력', 'duration': '1시간', 'completed': False},
                            {'id': 'task-s1-7', 'title': '모듈과 패키지', 'duration': '1시간', 'completed': False},
                        ]
                    },
                ]
            },
            {
                'user_id': 'sample-friend-002',
                'plan_name': '딥러닝 입문',
                'total_duration': '6주',
                'daily_schedule': [
                    {
                        'date': (today - timedelta(days=1)).isoformat(),
                        'tasks': [
                            {'id': 'task-s2-1', 'title': '신경망 기초 이론', 'duration': '2시간', 'completed': True},
                        ]
                    },
                    {
                        'date': today.isoformat(),
                        'tasks': [
                            {'id': 'task-s2-2', 'title': 'PyTorch 설치 및 환경 설정', 'duration': '30분', 'completed': True},
                            {'id': 'task-s2-3', 'title': '텐서 연산 기초', 'duration': '1시간', 'completed': True},
                            {'id': 'task-s2-4', 'title': 'Autograd 이해하기', 'duration': '1시간', 'completed': False},
                        ]
                    },
                    {
                        'date': (today + timedelta(days=1)).isoformat(),
                        'tasks': [
                            {'id': 'task-s2-5', 'title': 'CNN 기초', 'duration': '2시간', 'completed': False},
                        ]
                    },
                ]
            },
            {
                'user_id': 'sample-friend-003',
                'plan_name': 'Flutter 앱 개발',
                'total_duration': '3주',
                'daily_schedule': [
                    {
                        'date': (today - timedelta(days=1)).isoformat(),
                        'tasks': [
                            {'id': 'task-s3-1', 'title': 'Dart 문법 기초', 'duration': '1시간', 'completed': True},
                            {'id': 'task-s3-2', 'title': 'Flutter 위젯 개념', 'duration': '1시간', 'completed': False},
                        ]
                    },
                    {
                        'date': today.isoformat(),
                        'tasks': [
                            {'id': 'task-s3-3', 'title': 'StatefulWidget 실습', 'duration': '1시간 30분', 'completed': False},
                            {'id': 'task-s3-4', 'title': '레이아웃 위젯 학습', 'duration': '1시간', 'completed': False},
                        ]
                    },
                    {
                        'date': (today + timedelta(days=1)).isoformat(),
                        'tasks': [
                            {'id': 'task-s3-5', 'title': '네비게이션 구현', 'duration': '1시간', 'completed': False},
                            {'id': 'task-s3-6', 'title': 'HTTP 통신 실습', 'duration': '1시간 30분', 'completed': False},
                        ]
                    },
                ]
            },
        ]

        for plan in sample_plans:
            cursor.execute('''
                INSERT INTO plans (user_id, plan_name, total_duration, daily_schedule, created_at)
                VALUES (?, ?, ?, ?, ?)
            ''', (
                plan['user_id'], plan['plan_name'], plan['total_duration'],
                json.dumps(plan['daily_schedule'], ensure_ascii=False),
                datetime.now().isoformat()
            ))

        conn.commit()
        conn.close()
        print("📚 샘플 친구 데이터 초기화 완료!")

    def get_sample_friends(self) -> List[Dict]:
        """샘플 친구 목록 반환"""
        conn = self._get_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT user_id, name, photo_url, friend_code FROM users
            WHERE user_id LIKE 'sample-friend-%'
        """)
        rows = cursor.fetchall()
        conn.close()

        result = []
        for row in rows:
            # 오늘의 진행률 계산
            plans = self.get_plans(row['user_id'])
            today_rate = 0
            if plans:
                today_str = datetime.now().date().isoformat()
                for plan in plans:
                    for day in plan.get('daily_schedule', []):
                        if day['date'] == today_str:
                            tasks = day['tasks']
                            if tasks:
                                completed = sum(1 for t in tasks if t.get('completed', False))
                                today_rate = int(completed / len(tasks) * 100)
                            break

            result.append({
                'id': row['user_id'],
                'name': row['name'],
                'avatarUrl': row['photo_url'],
                'todayRate': today_rate,
                'friendCode': row['friend_code'],
            })

        return result

    def get_friend_plans_by_date(self, friend_id: str, date_str: str) -> List[Dict]:
        """친구의 특정 날짜 계획 반환"""
        plans = self.get_plans(friend_id)

        for plan in plans:
            for day in plan.get('daily_schedule', []):
                if day['date'] == date_str:
                    return [
                        {
                            'id': task['id'],
                            'title': task['title'],
                            'duration': task.get('duration', ''),
                            'done': task.get('completed', False)
                        }
                        for task in day['tasks']
                    ]

        return []


# 싱글톤 인스턴스
store = DataStore()
# 샘플 데이터 초기화
store.init_sample_data()

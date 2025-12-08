// lib/data/api_service.dart
// API 서비스 - 보안 강화 + 에러 처리 개선

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quiz_repository.dart';

/// API 설정
class ApiConfig {
  // 환경에 따른 BASE URL 설정
  // 빌드 시 --dart-define=API_URL=https://your-api.com 으로 설정
  static const String _apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );

  static String get baseUrl => _apiUrl;

  static const Duration timeout = Duration(seconds: 90);  // GPT 검색이 오래 걸릴 수 있음
  static const Duration longTimeout = Duration(seconds: 120);  // 추천 API용 더 긴 타임아웃
}

/// 보안 토큰 저장소
class SecureTokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  static Future<void> saveUserName(String name) async {
    await _storage.write(key: _userNameKey, value: name);
  }

  static Future<String?> getUserName() async {
    return await _storage.read(key: _userNameKey);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

/// 캐시 관리 (오프라인 지원 강화)
class CacheManager {
  static Future<void> saveCache(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
    await prefs.setInt('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<dynamic> getCache(String key, {Duration maxAge = const Duration(minutes: 5)}) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('${key}_timestamp');

    if (timestamp == null) return null;

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > maxAge.inMilliseconds) return null;

    final data = prefs.getString(key);
    return data != null ? jsonDecode(data) : null;
  }

  /// 오프라인 전용: 만료 무시하고 캐시 반환
  static Future<dynamic> getOfflineCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    return data != null ? jsonDecode(data) : null;
  }

  /// 캐시 존재 여부 확인
  static Future<bool> hasCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }

  /// 캐시 나이 확인 (밀리초)
  static Future<int?> getCacheAge(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('${key}_timestamp');
    if (timestamp == null) return null;
    return DateTime.now().millisecondsSinceEpoch - timestamp;
  }

  static Future<void> clearCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove('${key}_timestamp');
  }

  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    // 토큰 관련 키는 유지
    final keysToKeep = ['auth_token', 'user_id', 'user_name', 'isDarkMode'];
    final allKeys = prefs.getKeys();

    for (final key in allKeys) {
      if (!keysToKeep.contains(key)) {
        await prefs.remove(key);
      }
    }
  }
}

/// API 예외 클래스
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorType;

  ApiException(this.message, {this.statusCode, this.errorType});

  @override
  String toString() => message;

  bool get isNetworkError => errorType == 'network';
  bool get isAuthError => statusCode == 401;
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isValidationError => statusCode == 400;
}

/// HTTP 클라이언트 래퍼
class ApiClient {
  static Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};

    if (withAuth) {
      final token = await SecureTokenStorage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<dynamic> get(String endpoint, {bool withAuth = true, bool useCache = false, Duration cacheMaxAge = const Duration(minutes: 5), bool offlineFallback = true, bool useLongTimeout = false}) async {
    // 캐시 확인
    if (useCache) {
      final cached = await CacheManager.getCache(endpoint, maxAge: cacheMaxAge);
      if (cached != null) return cached;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _getHeaders(withAuth: withAuth),
      ).timeout(useLongTimeout ? ApiConfig.longTimeout : ApiConfig.timeout);

      return _handleResponse(response, endpoint, useCache: useCache);
    } on SocketException {
      // 오프라인 폴백: 캐시된 데이터 반환
      if (offlineFallback) {
        final offlineData = await CacheManager.getOfflineCache(endpoint);
        if (offlineData != null) return offlineData;
      }
      throw ApiException('인터넷 연결을 확인해주세요.', errorType: 'network');
    } on http.ClientException {
      // 오프라인 폴백
      if (offlineFallback) {
        final offlineData = await CacheManager.getOfflineCache(endpoint);
        if (offlineData != null) return offlineData;
      }
      throw ApiException('서버에 연결할 수 없습니다.', errorType: 'network');
    } catch (e, stackTrace) {
      if (e is ApiException) rethrow;
      // 상세 에러 로깅
      print('[API ERROR] GET $endpoint');
      print('[API ERROR] Type: ${e.runtimeType}');
      print('[API ERROR] Message: $e');
      print('[API ERROR] StackTrace: $stackTrace');
      // 타임아웃 등 기타 에러에서도 오프라인 폴백
      if (offlineFallback) {
        final offlineData = await CacheManager.getOfflineCache(endpoint);
        if (offlineData != null) return offlineData;
      }
      throw ApiException('요청 중 오류가 발생했습니다. (${e.runtimeType}: $e)');
    }
  }

  static Future<dynamic> post(String endpoint, {Map<String, dynamic>? body, bool withAuth = true}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _getHeaders(withAuth: withAuth),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(ApiConfig.timeout);

      return _handleResponse(response, endpoint);
    } on SocketException {
      throw ApiException('인터넷 연결을 확인해주세요.', errorType: 'network');
    } on http.ClientException {
      throw ApiException('서버에 연결할 수 없습니다.', errorType: 'network');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('요청 중 오류가 발생했습니다.');
    }
  }

  static dynamic _handleResponse(http.Response response, String endpoint, {bool useCache = false}) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // 성공 시 캐시 저장
      if (useCache) {
        CacheManager.saveCache(endpoint, body);
      }
      return body;
    }

    // 에러 처리
    final detail = body['detail'] ?? '요청 처리 중 오류가 발생했습니다.';

    throw ApiException(
      detail,
      statusCode: response.statusCode,
      errorType: body['error_type'],
    );
  }
}

// ==================== 인증 API ====================

class AuthService {
  /// 회원가입
  static Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required String password,
    required String name,
    required String birth,
    String? photoUrl,
  }) async {
    final result = await ApiClient.post(
      '/auth/signup',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'name': name,
        'birth': birth,
        'photo_url': photoUrl,
      },
      withAuth: false,
    );

    return result;
  }

  /// 로그인
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final result = await ApiClient.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      withAuth: false,
    );

    // 토큰 저장
    if (result['token'] != null) {
      await SecureTokenStorage.saveToken(result['token']);
      await SecureTokenStorage.saveUserId(result['userId'] ?? '');
      await SecureTokenStorage.saveUserName(result['displayName'] ?? '');
    }

    return result;
  }

  /// 로그아웃
  static Future<void> logout() async {
    try {
      await ApiClient.post('/auth/logout');
    } finally {
      await SecureTokenStorage.clearAll();
      await CacheManager.clearAllCache();
    }
  }

  /// 로그인 상태 확인
  static Future<bool> isLoggedIn() async {
    return await SecureTokenStorage.isLoggedIn();
  }

  /// 현재 사용자 정보
  static Future<Map<String, dynamic>> getCurrentUser() async {
    return await ApiClient.get('/auth/me');
  }
}

// ==================== 프로필 API ====================

class ProfileService {
  /// 내 프로필 조회
  static Future<Map<String, dynamic>> getProfile() async {
    return await ApiClient.get('/profile/me', useCache: true);
  }

  /// 프로필 업데이트
  static Future<bool> updateProfile({
    required String userId,
    String? email,
    String? name,
    String? birth,
    String? password,
  }) async {
    await ApiClient.post(
      '/profile/update',
      body: {
        'user_id': userId,
        'email': email,
        'name': name,
        'birth': birth,
        'password': password,
      },
    );

    // 캐시 무효화
    await CacheManager.clearCache('/profile/me');

    return true;
  }
}

// ==================== 홈 API ====================

class HomeService {
  /// 홈 헤더 정보 조회
  static Future<Map<String, dynamic>> getHeader() async {
    // 캐시 비활성화 - 항상 최신 데이터 조회
    return await ApiClient.get('/home/header', useCache: false);
  }

  /// 계획 목록 조회 (daily/weekly/monthly)
  static Future<List<String>> getPlans({String scope = 'daily'}) async {
    final data = await ApiClient.get('/plans?scope=$scope');
    return (data as List).map((e) => e.toString()).toList();
  }

  /// 복습 항목 조회
  static Future<List<Map<String, dynamic>>> getReviewPlans() async {
    final data = await ApiClient.get('/plans/review');
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }
}

// ==================== 퀴즈 API ====================

class QuizService implements QuizRepository {
  /// 퀴즈 문제 조회
  @override
  Future<List<QuizItem>> fetchQuizItems({
    String skill = 'general',
    String level = '초급',
    int limit = 10,
  }) async {
    final data = await ApiClient.get('/quiz/items?skill=$skill&level=$level&limit=$limit');
    return (data as List).map((e) => QuizItem.fromMap(e)).toList();
  }

  /// 퀴즈 채점
  @override
  Future<QuizResult> grade({
    required List<QuizItem> items,
    required List<String?> userAnswers,
  }) async {
    final answers = <Map<String, dynamic>>[];
    for (int i = 0; i < items.length; i++) {
      answers.add({
        'id': items[i].id,
        'userAnswer': userAnswers[i] ?? '',
      });
    }

    final data = await ApiClient.post('/quiz/grade', body: {'answers': answers});

    return QuizResult(
      total: data['total'],
      correct: data['correct'],
      detail: (data['detail'] as List).map((e) => e as bool).toList(),
    );
  }
}

// ==================== 강좌 추천 API ====================

class RecommendService {
  /// AI 검색 상태 조회 (로딩 화면용)
  static Future<Map<String, dynamic>> getSearchStatus() async {
    try {
      return await ApiClient.get('/recommend/search_status');
    } catch (e) {
      return {'model': null, 'status': 'idle'};
    }
  }

  /// 추천 강좌 조회 (GPT 검색으로 오래 걸릴 수 있음)
  static Future<List<Map<String, dynamic>>> getCourses({
    required String skill,
    required String level,
  }) async {
    final data = await ApiClient.get(
      '/recommend/courses?skill=$skill&level=$level',
      useLongTimeout: true,  // GPT 검색이 오래 걸릴 수 있으므로 긴 타임아웃 사용
    );
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  /// 강좌 선택
  static Future<bool> selectCourse({
    required String userId,
    required String courseId,
  }) async {
    await ApiClient.post(
      '/recommend/select',
      body: {
        'user_id': userId,
        'course_id': courseId,
      },
    );
    return true;
  }

  /// 추천 적용 (계획 생성)
  static Future<Map<String, dynamic>> applyRecommendation({
    required Map<String, dynamic> selectedCourse,
    required String quizLevel,
    required String skill,
    required double hourPerDay,
    required String startDate,
    required List<String> restDays,
    Map<String, dynamic>? quizDetails,
  }) async {
    return await ApiClient.post(
      '/plan/apply_recommendation',
      body: {
        'selected_course': selectedCourse,
        'quiz_level': quizLevel,
        'skill': skill,
        'hourPerDay': hourPerDay,
        'startDate': startDate,
        'restDays': restDays,
        'quiz_details': quizDetails,
      },
    );
  }
}

// ==================== 학습 계획 API ====================

class PlanService {
  /// 계획 생성
  static Future<Map<String, dynamic>> generatePlan({
    required String skill,
    required double hourPerDay,
    required String startDate,
    required List<String> restDays,
    required String selfLevel,
  }) async {
    final result = await ApiClient.post(
      '/plans/generate',
      body: {
        'skill': skill,
        'hourPerDay': hourPerDay,
        'startDate': startDate,
        'restDays': restDays,
        'selfLevel': selfLevel,
      },
    );

    // 캐시 무효화
    await CacheManager.clearCache('/plans/all');

    return result;
  }

  /// 특정 날짜의 상세 계획 조회
  static Future<Map<String, dynamic>> getPlansByDate({
    required String date,
  }) async {
    return await ApiClient.get('/plans/date/$date', useCache: true);
  }

  /// 태스크 상태 업데이트
  static Future<bool> updateTask({
    required String date,
    required String taskId,
    required bool completed,
  }) async {
    await ApiClient.post('/plans/task/update?date=$date&task_id=$taskId&completed=$completed');

    // 캐시 무효화 (모든 관련 캐시)
    await CacheManager.clearCache('/plans/date/$date');
    await CacheManager.clearCache('/plans/all');
    await CacheManager.clearCache('/home/header');
    await CacheManager.clearCache('/stats/summary');
    await CacheManager.clearCache('/stats/weekly');
    await CacheManager.clearCache('/stats/achievements');

    return true;
  }

  /// 내 모든 학습 계획 목록 조회
  static Future<List<Map<String, dynamic>>> getMyPlans() async {
    // 캐시 비활성화 - 항상 최신 데이터 조회
    final data = await ApiClient.get('/plans/all', useCache: false);
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  /// 특정 주제에 대한 연관 자료 조회
  static Future<List<Map<String, dynamic>>> getRelatedMaterials({
    required String topic,
  }) async {
    final data = await ApiClient.get('/plans/related_materials?topic=${Uri.encodeComponent(topic)}');

    if (data is List) {
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else if (data['materials'] is List) {
      return (data['materials'] as List).map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  /// 어제 복습 자료 조회 (팝업용)
  static Future<Map<String, dynamic>> getYesterdayReview() async {
    try {
      return await ApiClient.get('/plans/yesterday_review');
    } catch (e) {
      return {'has_review': false, 'materials': [], 'yesterday_topic': ''};
    }
  }
}

// ==================== 친구 API ====================

class FriendsService {
  /// 친구 목록 조회
  static Future<List<Map<String, dynamic>>> getFriends() async {
    final data = await ApiClient.get('/friends', useCache: true, cacheMaxAge: const Duration(minutes: 2));
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  /// 친구 추가
  static Future<Map<String, dynamic>> addFriend({required String code}) async {
    final result = await ApiClient.post('/friends/add', body: {'code': code});

    // 캐시 무효화
    await CacheManager.clearCache('/friends');

    return result;
  }

  /// 친구 계획 조회
  static Future<List<Map<String, dynamic>>> getFriendPlans({
    required String friendId,
    String? date,
  }) async {
    String endpoint = '/friends/$friendId/plans';
    if (date != null) {
      endpoint += '?date=$date';
    }

    final data = await ApiClient.get(endpoint);
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }

  /// 친구 계획 체크 (응원)
  static Future<bool> checkFriendPlan({
    required String friendId,
    required String planId,
    required bool done,
  }) async {
    await ApiClient.post(
      '/friends/$friendId/plans/check',
      body: {
        'planId': planId,
        'done': done,
      },
    );
    return true;
  }
}

// ==================== 알림 API ====================

class NotificationService {
  /// 알림 조회
  static Future<Map<String, dynamic>> getNotifications() async {
    return await ApiClient.get('/notifications');
  }

  /// 알림 읽음 처리
  static Future<bool> markAsRead() async {
    await ApiClient.post('/notifications/read');
    return true;
  }
}

// ==================== 복습 자료 API ====================

class ReviewService {
  /// 어제 복습 자료 조회
  static Future<List<Map<String, dynamic>>> getYesterdayMaterials({
    String? userId,
  }) async {
    String endpoint = '/review/yesterday';
    if (userId != null) {
      endpoint += '?user_id=$userId';
    }

    final data = await ApiClient.get(endpoint);
    return (data as List).map((e) => e as Map<String, dynamic>).toList();
  }
}

// ==================== 학습 통계 API ====================

class StatsService {
  /// 학습 통계 요약 조회
  static Future<Map<String, dynamic>> getSummary() async {
    // 캐시 비활성화 - 항상 최신 데이터 조회
    return await ApiClient.get('/stats/summary', useCache: false);
  }

  /// 주간 통계 조회
  static Future<Map<String, dynamic>> getWeeklyStats() async {
    // 캐시 비활성화 - 항상 최신 데이터 조회
    return await ApiClient.get('/stats/weekly', useCache: false);
  }

  /// 업적 조회
  static Future<Map<String, dynamic>> getAchievements() async {
    // 캐시 비활성화 - 항상 최신 데이터 조회
    return await ApiClient.get('/stats/achievements', useCache: false);
  }
}

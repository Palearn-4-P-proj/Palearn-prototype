// lib/services/achievement_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 업적 모델
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int requiredCount;
  final String type; // 'task', 'streak', 'plan', 'social', 'time'

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.requiredCount,
    required this.type,
  });
}

/// 전체 업적 목록 정의
class Achievements {
  // Task 관련 업적
  static const firstTask = Achievement(
    id: 'first_task',
    title: '첫 걸음',
    description: '첫 번째 학습을 완료했습니다!',
    icon: Icons.emoji_events,
    color: Color(0xFFFFD700),
    requiredCount: 1,
    type: 'task',
  );

  static const tenTasks = Achievement(
    id: 'ten_tasks',
    title: '열정적인 학습자',
    description: '10개의 학습을 완료했습니다!',
    icon: Icons.local_fire_department,
    color: Color(0xFFFF6B35),
    requiredCount: 10,
    type: 'task',
  );

  static const fiftyTasks = Achievement(
    id: 'fifty_tasks',
    title: '학습 마스터',
    description: '50개의 학습을 완료했습니다!',
    icon: Icons.workspace_premium,
    color: Color(0xFF9C27B0),
    requiredCount: 50,
    type: 'task',
  );

  static const hundredTasks = Achievement(
    id: 'hundred_tasks',
    title: '전설의 학습자',
    description: '100개의 학습을 완료했습니다!',
    icon: Icons.military_tech,
    color: Color(0xFFE91E63),
    requiredCount: 100,
    type: 'task',
  );

  // Streak 관련 업적
  static const threeDayStreak = Achievement(
    id: 'three_day_streak',
    title: '3일 연속 학습',
    description: '3일 연속으로 학습을 완료했습니다!',
    icon: Icons.whatshot,
    color: Color(0xFFFF5722),
    requiredCount: 3,
    type: 'streak',
  );

  static const sevenDayStreak = Achievement(
    id: 'seven_day_streak',
    title: '일주일 연속 학습',
    description: '7일 연속으로 학습을 완료했습니다!',
    icon: Icons.local_fire_department,
    color: Color(0xFFFF9800),
    requiredCount: 7,
    type: 'streak',
  );

  static const thirtyDayStreak = Achievement(
    id: 'thirty_day_streak',
    title: '한 달 연속 학습',
    description: '30일 연속으로 학습을 완료했습니다!',
    icon: Icons.auto_awesome,
    color: Color(0xFFE040FB),
    requiredCount: 30,
    type: 'streak',
  );

  // Plan 관련 업적
  static const firstPlan = Achievement(
    id: 'first_plan',
    title: '계획 수립',
    description: '첫 번째 학습 계획을 만들었습니다!',
    icon: Icons.assignment_turned_in,
    color: Color(0xFF2196F3),
    requiredCount: 1,
    type: 'plan',
  );

  static const planComplete = Achievement(
    id: 'plan_complete',
    title: '계획 완수',
    description: '학습 계획을 100% 완료했습니다!',
    icon: Icons.verified,
    color: Color(0xFF4CAF50),
    requiredCount: 1,
    type: 'plan_complete',
  );

  static const threePlans = Achievement(
    id: 'three_plans',
    title: '다재다능',
    description: '3개의 학습 계획을 완료했습니다!',
    icon: Icons.emoji_objects,
    color: Color(0xFF00BCD4),
    requiredCount: 3,
    type: 'plan_complete',
  );

  // Social 관련 업적
  static const firstFriend = Achievement(
    id: 'first_friend',
    title: '첫 친구',
    description: '첫 번째 친구를 추가했습니다!',
    icon: Icons.people,
    color: Color(0xFF3F51B5),
    requiredCount: 1,
    type: 'social',
  );

  static const fiveFriends = Achievement(
    id: 'five_friends',
    title: '인싸 학습자',
    description: '5명의 친구를 추가했습니다!',
    icon: Icons.groups,
    color: Color(0xFF673AB7),
    requiredCount: 5,
    type: 'social',
  );

  // Time 관련 업적
  static const earlyBird = Achievement(
    id: 'early_bird',
    title: '얼리버드',
    description: '오전 6시 이전에 학습을 완료했습니다!',
    icon: Icons.wb_sunny,
    color: Color(0xFFFFC107),
    requiredCount: 1,
    type: 'time',
  );

  static const nightOwl = Achievement(
    id: 'night_owl',
    title: '올빼미 학습자',
    description: '자정 이후에 학습을 완료했습니다!',
    icon: Icons.nightlight_round,
    color: Color(0xFF5C6BC0),
    requiredCount: 1,
    type: 'time',
  );

  static const weekendWarrior = Achievement(
    id: 'weekend_warrior',
    title: '주말 전사',
    description: '주말에도 학습을 완료했습니다!',
    icon: Icons.weekend,
    color: Color(0xFF26A69A),
    requiredCount: 1,
    type: 'time',
  );

  // 전체 업적 리스트
  static List<Achievement> all = [
    firstTask,
    tenTasks,
    fiftyTasks,
    hundredTasks,
    threeDayStreak,
    sevenDayStreak,
    thirtyDayStreak,
    firstPlan,
    planComplete,
    threePlans,
    firstFriend,
    fiveFriends,
    earlyBird,
    nightOwl,
    weekendWarrior,
  ];
}

/// 업적 서비스 - 업적 달성 관리
class AchievementService {
  static const String _prefix = 'achievement_';
  static const String _completedTasksKey = 'completed_tasks_count';
  static const String _currentStreakKey = 'current_streak';
  static const String _completedPlansKey = 'completed_plans_count';
  static const String _friendsCountKey = 'friends_count';

  // 업적 달성 여부 확인
  static Future<bool> isAchievementUnlocked(String achievementId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$achievementId') ?? false;
  }

  // 업적 달성 처리
  static Future<void> unlockAchievement(String achievementId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$achievementId', true);
  }

  // 완료된 모든 업적 가져오기
  static Future<List<Achievement>> getUnlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Achievement> unlocked = [];

    for (final achievement in Achievements.all) {
      if (prefs.getBool('$_prefix${achievement.id}') ?? false) {
        unlocked.add(achievement);
      }
    }

    return unlocked;
  }

  // 잠긴 업적 가져오기
  static Future<List<Achievement>> getLockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Achievement> locked = [];

    for (final achievement in Achievements.all) {
      if (!(prefs.getBool('$_prefix${achievement.id}') ?? false)) {
        locked.add(achievement);
      }
    }

    return locked;
  }

  // 태스크 완료 시 호출 - 새로운 업적 반환
  static Future<Achievement?> onTaskCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    int count = (prefs.getInt(_completedTasksKey) ?? 0) + 1;
    await prefs.setInt(_completedTasksKey, count);

    // 시간 기반 업적 체크
    final now = DateTime.now();
    Achievement? timeAchievement;

    // 얼리버드 (6시 이전)
    if (now.hour < 6) {
      if (!(await isAchievementUnlocked(Achievements.earlyBird.id))) {
        await unlockAchievement(Achievements.earlyBird.id);
        timeAchievement = Achievements.earlyBird;
      }
    }

    // 올빼미 (자정 이후, 5시 이전)
    if (now.hour >= 0 && now.hour < 5) {
      if (!(await isAchievementUnlocked(Achievements.nightOwl.id))) {
        await unlockAchievement(Achievements.nightOwl.id);
        timeAchievement = Achievements.nightOwl;
      }
    }

    // 주말 전사
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      if (!(await isAchievementUnlocked(Achievements.weekendWarrior.id))) {
        await unlockAchievement(Achievements.weekendWarrior.id);
        timeAchievement = Achievements.weekendWarrior;
      }
    }

    // 태스크 개수 기반 업적 체크
    if (count >= 100 && !(await isAchievementUnlocked(Achievements.hundredTasks.id))) {
      await unlockAchievement(Achievements.hundredTasks.id);
      return Achievements.hundredTasks;
    }
    if (count >= 50 && !(await isAchievementUnlocked(Achievements.fiftyTasks.id))) {
      await unlockAchievement(Achievements.fiftyTasks.id);
      return Achievements.fiftyTasks;
    }
    if (count >= 10 && !(await isAchievementUnlocked(Achievements.tenTasks.id))) {
      await unlockAchievement(Achievements.tenTasks.id);
      return Achievements.tenTasks;
    }
    if (count >= 1 && !(await isAchievementUnlocked(Achievements.firstTask.id))) {
      await unlockAchievement(Achievements.firstTask.id);
      return Achievements.firstTask;
    }

    return timeAchievement;
  }

  // 연속 학습 업데이트
  static Future<Achievement?> updateStreak(int streakDays) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentStreakKey, streakDays);

    if (streakDays >= 30 && !(await isAchievementUnlocked(Achievements.thirtyDayStreak.id))) {
      await unlockAchievement(Achievements.thirtyDayStreak.id);
      return Achievements.thirtyDayStreak;
    }
    if (streakDays >= 7 && !(await isAchievementUnlocked(Achievements.sevenDayStreak.id))) {
      await unlockAchievement(Achievements.sevenDayStreak.id);
      return Achievements.sevenDayStreak;
    }
    if (streakDays >= 3 && !(await isAchievementUnlocked(Achievements.threeDayStreak.id))) {
      await unlockAchievement(Achievements.threeDayStreak.id);
      return Achievements.threeDayStreak;
    }

    return null;
  }

  // 계획 생성 시 호출
  static Future<Achievement?> onPlanCreated() async {
    if (!(await isAchievementUnlocked(Achievements.firstPlan.id))) {
      await unlockAchievement(Achievements.firstPlan.id);
      return Achievements.firstPlan;
    }
    return null;
  }

  // 계획 완료 시 호출
  static Future<Achievement?> onPlanCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    int count = (prefs.getInt(_completedPlansKey) ?? 0) + 1;
    await prefs.setInt(_completedPlansKey, count);

    if (count >= 3 && !(await isAchievementUnlocked(Achievements.threePlans.id))) {
      await unlockAchievement(Achievements.threePlans.id);
      return Achievements.threePlans;
    }
    if (count >= 1 && !(await isAchievementUnlocked(Achievements.planComplete.id))) {
      await unlockAchievement(Achievements.planComplete.id);
      return Achievements.planComplete;
    }

    return null;
  }

  // 친구 추가 시 호출
  static Future<Achievement?> onFriendAdded(int totalFriends) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_friendsCountKey, totalFriends);

    if (totalFriends >= 5 && !(await isAchievementUnlocked(Achievements.fiveFriends.id))) {
      await unlockAchievement(Achievements.fiveFriends.id);
      return Achievements.fiveFriends;
    }
    if (totalFriends >= 1 && !(await isAchievementUnlocked(Achievements.firstFriend.id))) {
      await unlockAchievement(Achievements.firstFriend.id);
      return Achievements.firstFriend;
    }

    return null;
  }

  // 통계 데이터 가져오기
  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'completedTasks': prefs.getInt(_completedTasksKey) ?? 0,
      'currentStreak': prefs.getInt(_currentStreakKey) ?? 0,
      'completedPlans': prefs.getInt(_completedPlansKey) ?? 0,
      'friendsCount': prefs.getInt(_friendsCountKey) ?? 0,
    };
  }
}

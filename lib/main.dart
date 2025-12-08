import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── 테마 설정 ─────────────────────────────────────────────────
import 'core/theme.dart';

// ── 기본 앱 화면들 ─────────────────────────────────────────────
import 'screens/splash_a.dart';
import 'screens/launch_b_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';

// ── 계획 생성 플로우 ───────────────────────────────────────────
// ✨ 충돌 방지 위해 alias 추가
import 'screens/loading_plan_screen.dart' as plan;
import 'screens/create_plan_screen.dart';

// ── 퀴즈/추천 플로우 ──────────────────────────────────────────
import 'screens/quiz_screen.dart';
import 'screens/quiz_result_screen.dart';
import 'screens/recommend_courses_screen.dart';
import 'screens/recommend_loading_screen.dart';

// ── 친구 플로우 ──────────────────────────────────────────────
import 'screens/friends_screen.dart';
import 'screens/friend_detail_screen.dart';

// ── 프로필 플로우 ────────────────────────────────────────────
import 'screens/profile_screen.dart';
import 'screens/profile_edit_screen.dart';

// ── 알림 화면 ────────────────────────────────────────────────
import 'screens/notifications_screen.dart';

// ── 계획 상세 화면 ────────────────────────────────────────────
import 'screens/plan_detail_screen.dart';

// ── 복습 화면 ────────────────────────────────────────────────
import 'screens/review_screen.dart';

// ── 통계 화면 ────────────────────────────────────────────────
import 'screens/stats_screen.dart';

// ── 검색 화면 ────────────────────────────────────────────────
import 'screens/search_screen.dart';

// ── 설정 화면 ────────────────────────────────────────────────
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 상태바 스타일 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 저장된 테마 모드 불러오기
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(AppRoot(initialDarkMode: isDarkMode));
}

/// 테마 모드 전역 관리를 위한 InheritedWidget
class ThemeProvider extends InheritedWidget {
  final ThemeMode themeMode;
  final VoidCallback toggleTheme;

  const ThemeProvider({
    super.key,
    required this.themeMode,
    required this.toggleTheme,
    required super.child,
  });

  static ThemeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return themeMode != oldWidget.themeMode;
  }
}

class AppRoot extends StatefulWidget {
  final bool initialDarkMode;

  const AppRoot({super.key, this.initialDarkMode = false});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void _toggleTheme() async {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });

    // 테마 설정 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);

    // 상태바 스타일 업데이트
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _themeMode == ThemeMode.dark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      themeMode: _themeMode,
      toggleTheme: _toggleTheme,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Palearn',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: _themeMode,
        home: const SplashAScreen(),
        routes: {
          // ── 기본 플로우 ──
          '/launchB': (_) => const LaunchBScreen(),
          '/login': (_) => LoginScreen(),
          '/signup': (_) => const SignUpScreen(),
          '/home': (_) => const HomeScreen(),

          // ── 계획 생성 플로우 ──
          '/create_plan': (_) => const CreatePlanScreen(),
          '/plan_loading': (_) => plan.LoadingPlanScreen(
            skill: '딥러닝',
            hour: '1시간',
            start: DateTime(2025, 1, 1),
            restDays: const [],
            level: '초급(처음 배워요)',
          ),

          // ── 퀴즈/추천 플로우 ──
          '/quiz': (_) => const QuizScreen(),
          '/quiz_result': (_) => const QuizResultScreen(
            level: '중급',
            rate: 0.6,
            details: [true, false, true, true, false, true, false, true, true, true],
          ),
          '/recommend_courses': (_) => const RecommendCoursesScreen(),
          '/recommend_loading': (_) => const RecommendLoadingScreen(),

          // ── 친구 플로우 ──
          '/friends': (_) => const FriendsScreen(),
          '/friend_detail': (_) => const FriendDetailScreen(),

          // ── 프로필 플로우 ──
          '/profile': (_) => const ProfileScreen(),
          '/profile_edit': (_) => const ProfileEditScreen(),

          // ── 알림 플로우 ──
          '/notifications': (_) => const NotificationScreen(),

          // ── 계획 상세 ──
          '/plan_detail': (_) => const PlanDetailScreen(),

          // ── 복습 화면 ──
          '/review': (_) => const ReviewScreen(),

          // ── 통계 화면 ──
          '/stats': (_) => const StatsScreen(),

          // ── 검색 화면 ──
          '/search': (_) => const SearchScreen(),

          // ── 설정 화면 ──
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}

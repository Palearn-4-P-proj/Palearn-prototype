import 'package:flutter/material.dart';
import '../data/api_service.dart';

const _blue = Color(0xFF7DB2FF);

class SplashAScreen extends StatefulWidget {
  const SplashAScreen({super.key});
  @override
  State<SplashAScreen> createState() => _SplashAScreenState();
}

class _SplashAScreenState extends State<SplashAScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // 로그인 상태 확인
    final isLoggedIn = await AuthService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 로고 아이콘
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 56,
                color: _blue,
              ),
            ),
            const SizedBox(height: 24),
            // 앱 이름
            const Text(
              'Palearn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI 맞춤 학습 플랫폼',
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            // 로딩 인디케이터
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

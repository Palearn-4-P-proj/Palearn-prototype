import 'package:flutter/material.dart';
import '../generated/login_signup_widgets.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              child: LoginWidget(

                // ===================================================================
                // ① [회원가입 화면으로 이동] — 백엔드 통신 ❌
                // UI 화면 이동만 수행 → 서버 통신 필요 없음
                // ===================================================================
                onTapSignUpText: () =>
                    Navigator.pushReplacementNamed(context, '/signup'),

                // ===================================================================
                // ② [로그인 버튼 눌렀을 때] — 백엔드 통신 ⭕ (POST 필요)
                //
                // LoginWidget 내부에서 사용자가 입력한:
                //   - id(또는 email)
                //   - password
                // 를 가져와서 서버에 인증 요청해야 함.
                //
                // FastAPI 예시:
                // POST /auth/login
                // body:
                // {
                //   "userId": "xxxx",
                //   "password": "yyyy"
                // }
                //
                // 응답:
                // {
                //   "token": "JWT or session token",
                //   "displayName": "은진",
                //   "userId": "123",
                // }
                //
                // 성공하면:
                //   - 토큰 SecureStorage 저장
                //   - HomeScreen으로 이동
                //
                // 실패하면:
                //   - 에러 메시지 표시
                // ===================================================================

                onTapLogin: () async {
                  // TODO: 백엔드 인증 API 호출 필요
                  //
                  // 예)
                  // final success = await AuthAPI.login(
                  //   id: inputId,
                  //   password: inputPw,
                  // );
                  //
                  // if (success) {
                  //   Navigator.pushReplacementNamed(context, '/home');
                  // } else {
                  //   showDialog(... 에러 메시지 ...);
                  // }

                  // 현재는 임시로 성공했다고 가정하고 Home으로 이동
                  Navigator.pushReplacementNamed(context, '/home');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
